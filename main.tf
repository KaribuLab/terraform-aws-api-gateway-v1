terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "<= 6.7.0"
    }
  }
}

# ============================================================================
# Locals: Generar spec OpenAPI a partir de lambda_integrations y authorizers
# ============================================================================

locals {
  integrations_by_path = {
    for path in distinct([for i in var.lambda_integrations : i.path]) :
    path => [for i in var.lambda_integrations : i if i.path == path]
  }

  cors_paths = toset([
    for i in var.lambda_integrations : i.path if i.enable_cors
  ])

  # Construir security list por integración
  integration_security = {
    for i in var.lambda_integrations :
    "${i.path}:${i.method}" => (
      i.authorization_type == "CUSTOM" && i.api_key_required
      ? [{ (i.authorizer_key) = [], api_key = [] }]
      : i.authorization_type == "CUSTOM"
      ? [{ (i.authorizer_key) = [] }]
      : i.api_key_required
      ? [{ api_key = [] }]
      : []
    )
  }

  # CORS: calcular métodos permitidos por path
  cors_methods_by_path = {
    for path in local.cors_paths :
    path => join(",", concat(
      [for i in local.integrations_by_path[path] : i.method],
      ["OPTIONS"]
    ))
  }

  # Primera integración con CORS habilitado por path (para tomar defaults)
  cors_config_by_path = {
    for path in local.cors_paths :
    path => [for i in local.integrations_by_path[path] : i if i.enable_cors][0]
  }

  openapi_paths = {
    for path, integrations in local.integrations_by_path :
    path => merge(
      {
        for i in integrations :
        lower(i.method) => merge(
          {
            x-amazon-apigateway-integration = {
              type                = "aws_proxy"
              httpMethod          = "POST"
              uri                 = i.lambda_invoke_arn
              passthroughBehavior = "when_no_match"
            }
          },
          length(local.integration_security["${i.path}:${i.method}"]) > 0
          ? { security = local.integration_security["${i.path}:${i.method}"] }
          : {}
        )
      },
      contains(local.cors_paths, path) ? {
        options = {
          summary = "CORS preflight"
          responses = {
            "200" = {
              description = "CORS preflight response"
              headers = {
                Access-Control-Allow-Origin  = { schema = { type = "string" } }
                Access-Control-Allow-Methods = { schema = { type = "string" } }
                Access-Control-Allow-Headers = { schema = { type = "string" } }
              }
            }
          }
          x-amazon-apigateway-integration = {
            type = "mock"
            requestTemplates = {
              "application/json" = "{\"statusCode\": 200}"
            }
            responses = {
              default = {
                statusCode = "200"
                responseParameters = {
                  "method.response.header.Access-Control-Allow-Headers" = local.cors_config_by_path[path].cors_allow_headers
                  "method.response.header.Access-Control-Allow-Methods" = coalesce(
                    local.cors_config_by_path[path].cors_allow_methods,
                    "'${local.cors_methods_by_path[path]}'"
                  )
                  "method.response.header.Access-Control-Allow-Origin" = local.cors_config_by_path[path].cors_allow_origin
                }
              }
            }
          }
        }
      } : {}
    )
  }

  # Extraer nombre del header desde identity_source (ej: method.request.header.Authorization -> Authorization)
  security_schemes = {
    for key, auth in var.authorizers :
    key => {
      type                         = "apiKey"
      name                         = element(split(".", auth.identity_source), length(split(".", auth.identity_source)) - 1)
      in                           = "header"
      x-amazon-apigateway-authtype = "custom"
      x-amazon-apigateway-authorizer = merge(
        {
          type                         = auth.type == "TOKEN" ? "token" : "request"
          authorizerUri                = auth.lambda_invoke_arn
          authorizerResultTtlInSeconds = auth.authorizer_result_ttl
          identitySource               = auth.identity_source
        },
        auth.identity_validation_expression != null ? {
          identityValidationExpression = auth.identity_validation_expression
        } : {}
      )
    }
  }

  api_key_scheme = var.enable_api_key ? {
    api_key = {
      type = "apiKey"
      name = "x-api-key"
      in   = "header"
    }
  } : {}

  all_security_schemes = merge(local.security_schemes, local.api_key_scheme)

  openapi_spec = merge(
    {
      openapi = "3.0.1"
      info = {
        title   = var.api_name
        version = "1.0"
      }
      paths = local.openapi_paths
    },
    length(local.all_security_schemes) > 0 ? {
      components = {
        securitySchemes = local.all_security_schemes
      }
    } : {}
  )

  lambda_permission_keys = {
    for i in var.lambda_integrations :
    "${replace(trimprefix(i.path, "/"), "/", "-")}-${i.method}" => i
  }
}

# ============================================================================
# API Gateway REST API (con spec OpenAPI)
# ============================================================================

resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = var.api_description
  body        = jsonencode(local.openapi_spec)
  tags        = var.tags
}

# ============================================================================
# Permisos Lambda para integraciones
# ============================================================================

resource "aws_lambda_permission" "integration" {
  for_each = local.lambda_permission_keys

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# ============================================================================
# Permisos Lambda para authorizers
# ============================================================================

resource "aws_lambda_permission" "authorizer" {
  for_each = var.authorizers

  statement_id  = "AllowAPIGatewayInvokeAuthorizer-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/authorizers/*"
}

# ============================================================================
# Deployment
# ============================================================================

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode(local.openapi_spec))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Stage
# ============================================================================

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
  description   = var.stage_description

  variables = var.stage_variables

  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_enabled ? var.cache_cluster_size : null

  xray_tracing_enabled = var.xray_tracing_enabled

  dynamic "access_log_settings" {
    for_each = var.access_log_settings != null ? [1] : []
    content {
      destination_arn = var.access_log_settings.destination_arn
      format          = var.access_log_settings.format
    }
  }

  tags = var.tags
}

# ============================================================================
# Method Settings (cache, throttling, logs por método)
# ============================================================================

resource "aws_api_gateway_method_settings" "this" {
  for_each = var.method_settings

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = each.key

  settings {
    metrics_enabled        = each.value.metrics_enabled
    logging_level          = each.value.logging_level
    data_trace_enabled     = each.value.data_trace_enabled
    throttling_burst_limit = each.value.throttling_burst_limit
    throttling_rate_limit  = each.value.throttling_rate_limit
    caching_enabled        = each.value.caching_enabled
    cache_ttl_in_seconds   = each.value.cache_ttl_in_seconds
    cache_data_encrypted   = each.value.cache_data_encrypted
  }
}

# ============================================================================
# API Key y Usage Plan (opcional)
# ============================================================================

resource "aws_api_gateway_api_key" "this" {
  count = var.enable_api_key ? 1 : 0

  name        = var.api_key_name != null ? var.api_key_name : "${var.api_name}-key"
  description = var.api_key_description
  enabled     = true
  tags        = var.tags

  lifecycle {
    precondition {
      condition     = var.usage_plan_config != null
      error_message = "usage_plan_config es requerido cuando enable_api_key es true. La API Key debe estar asociada a un Usage Plan para funcionar correctamente."
    }
  }
}

resource "aws_api_gateway_usage_plan" "this" {
  count = var.enable_api_key && var.usage_plan_config != null ? 1 : 0

  name        = var.usage_plan_config.name
  description = var.usage_plan_config.description

  dynamic "quota_settings" {
    for_each = var.usage_plan_config.quota_settings != null ? [1] : []
    content {
      limit  = var.usage_plan_config.quota_settings.limit
      period = var.usage_plan_config.quota_settings.period
    }
  }

  dynamic "throttle_settings" {
    for_each = var.usage_plan_config.throttle_settings != null ? [1] : []
    content {
      burst_limit = var.usage_plan_config.throttle_settings.burst_limit
      rate_limit  = var.usage_plan_config.throttle_settings.rate_limit
    }
  }

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  tags = var.tags
}

resource "aws_api_gateway_usage_plan_key" "this" {
  count = var.enable_api_key && var.usage_plan_config != null ? 1 : 0

  key_id        = aws_api_gateway_api_key.this[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this[0].id
}
