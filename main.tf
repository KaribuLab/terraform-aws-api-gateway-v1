terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "<= 6.7.0"
    }
  }
}

# ============================================================================
# Data sources
# ============================================================================

data "aws_caller_identity" "current" {}

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

  # Construir URI de integración Lambda (directo o con stage variable)
  # Cuando se usa lambda_alias_variable, la URI incluye ${stageVariables.<var>} que API Gateway resuelve en runtime
  integration_uris = {
    for i in var.lambda_integrations :
    "${i.path}:${i.method}" => (
      i.lambda_alias_variable != null
      ? "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${i.lambda_function_arn}:${"$"}{stageVariables.${i.lambda_alias_variable}}/invocations"
      : i.lambda_invoke_arn
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
              uri                 = local.integration_uris["${i.path}:${i.method}"]
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
          summary  = "CORS preflight"
          security = []
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

  endpoint_configuration {
    types = [upper(var.endpoint_type)]
  }

  tags = var.tags
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
# Stage Module (Deployment, Stage, Method Settings, WAF, API Key, Usage Plan)
# ============================================================================

locals {
  openapi_spec_sha = sha1(jsonencode({
    openapi_spec    = local.openapi_spec
    endpoint_type   = upper(var.endpoint_type)
    waf_web_acl_arn = var.waf_web_acl_arn
  }))

  api_key_config = var.enable_api_key ? {
    name        = var.api_key_name
    description = var.api_key_description
    usage_plan  = var.usage_plan_config
  } : null
}

module "stage" {
  count  = var.create_stage ? 1 : 0
  source = "./modules/stage"

  rest_api_id            = aws_api_gateway_rest_api.this.id
  rest_api_execution_arn = aws_api_gateway_rest_api.this.execution_arn
  tags                   = var.tags
  endpoint_type          = var.endpoint_type
  openapi_spec_sha       = local.openapi_spec_sha

  # Stage settings
  stage_name            = var.stage_name
  stage_description     = var.stage_description
  stage_variables       = var.stage_variables
  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_size
  xray_tracing_enabled  = var.xray_tracing_enabled
  access_log_settings   = var.access_log_settings

  # Method settings
  method_settings = var.method_settings

  # WAF
  waf_web_acl_arn = var.waf_web_acl_arn

  # API Key and Usage Plan
  api_key_config = local.api_key_config

  # Lambda integrations with aliases (for permissions)
  lambda_integrations = [
    for i in var.lambda_integrations : {
      lambda_function_arn   = i.lambda_function_arn
      lambda_alias_variable = i.lambda_alias_variable
    }
    if i.lambda_alias_variable != null
  ]
}
