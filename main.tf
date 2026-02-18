terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ============================================================================
# API Gateway REST API
# ============================================================================

resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = var.api_description
  tags        = var.tags
}

# ============================================================================
# Locals para normalización de paths y generación de recursos
# ============================================================================

locals {
  # Normalizar paths: eliminar "/" inicial y final, dividir en segmentos
  # Ejemplo: "/users/{id}/orders" -> ["users", "{id}", "orders"]
  path_segments = {
    for integration in var.lambda_integrations :
    integration.path => split("/", trim(integration.path, "/"))
  }

  # Generar todos los recursos necesarios (jerarquía completa de paths)
  # Para "/users/{id}/orders" necesitamos: /users, /users/{id}, /users/{id}/orders
  all_resources = flatten([
    for path, segments in local.path_segments : [
      for i in range(1, length(segments) + 1) : {
        path        = "/${join("/", slice(segments, 0, i))}"
        path_part   = segments[i - 1]
        parent_path = i == 1 ? "/" : "/${join("/", slice(segments, 0, i - 1))}"
      }
    ]
  ])

  # Deduplicar recursos (un path puede aparecer en múltiples integraciones)
  unique_resources = {
    for resource in local.all_resources :
    resource.path => resource
  }

  # Crear mapa de parent_id para cada recurso
  # El root "/" usa rest_api_root_resource_id, los demás usan el resource_id del padre
  resource_parent_map = {
    for path, resource in local.unique_resources :
    path => resource.parent_path == "/" ? aws_api_gateway_rest_api.this.root_resource_id : aws_api_gateway_resource.this[resource.parent_path].id
  }

  # Crear clave única para cada integración (path + método)
  integration_keys = {
    for integration in var.lambda_integrations :
    "${integration.path}#${integration.method}" => integration
  }

  # Crear mapa de CORS: agrupar por path los métodos que tienen CORS habilitado
  cors_paths = toset([
    for integration in var.lambda_integrations :
    integration.path if integration.enable_cors
  ])

  # Para cada path con CORS, obtener todos los métodos
  cors_methods_by_path = {
    for path in local.cors_paths :
    path => join(",", [
      for integration in var.lambda_integrations :
      integration.method if integration.path == path
    ])
  }
}

# ============================================================================
# Recursos de API Gateway (jerarquía de paths)
# ============================================================================

resource "aws_api_gateway_resource" "this" {
  for_each = local.unique_resources

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = local.resource_parent_map[each.key]
  path_part   = each.value.path_part
}

# ============================================================================
# Lambda Authorizers
# ============================================================================

resource "aws_api_gateway_authorizer" "this" {
  for_each = var.authorizers

  name                             = each.key
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  authorizer_uri                   = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${each.value.lambda_arn}/invocations"
  authorizer_credentials           = null
  authorizer_result_ttl_in_seconds = each.value.authorizer_result_ttl
  identity_source                  = each.value.identity_source
  type                             = each.value.type
  identity_validation_expression   = each.value.identity_validation_expression
}

# Permisos para que API Gateway invoque los Lambda Authorizers
resource "aws_lambda_permission" "authorizer" {
  for_each = var.authorizers

  statement_id  = "AllowAPIGatewayInvokeAuthorizer-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/authorizers/*"
}

# ============================================================================
# Métodos HTTP para integraciones Lambda
# ============================================================================

resource "aws_api_gateway_method" "this" {
  for_each = local.integration_keys

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this[each.value.path].id
  http_method   = each.value.method
  authorization = each.value.authorization_type

  # Si usa CUSTOM authorization, vincular el authorizer
  authorizer_id = each.value.authorization_type == "CUSTOM" && each.value.authorizer_key != null ? aws_api_gateway_authorizer.this[each.value.authorizer_key].id : null

  api_key_required   = each.value.api_key_required
  request_parameters = each.value.request_parameters
}

# ============================================================================
# Integraciones Lambda (AWS_PROXY)
# ============================================================================

resource "aws_api_gateway_integration" "this" {
  for_each = local.integration_keys

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this[each.value.path].id
  http_method = aws_api_gateway_method.this[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.lambda_invoke_arn
}

# ============================================================================
# Permisos Lambda para API Gateway
# ============================================================================

resource "aws_lambda_permission" "this" {
  for_each = local.integration_keys

  statement_id  = "AllowAPIGatewayInvoke-${replace(each.value.path, "/", "-")}-${each.value.method}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# ============================================================================
# CORS Support (método OPTIONS automático)
# ============================================================================

resource "aws_api_gateway_method" "cors_options" {
  for_each = local.cors_paths

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_options" {
  for_each = local.cors_paths

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this[each.key].id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cors_options" {
  for_each = local.cors_paths

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this[each.key].id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "cors_options" {
  for_each = local.cors_paths

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this[each.key].id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'${local.cors_methods_by_path[each.key]},OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin" = [
      for integration in var.lambda_integrations :
      integration.cors_allow_origin if integration.path == each.key && integration.enable_cors
    ][0]
  }

  depends_on = [
    aws_api_gateway_integration.cors_options,
    aws_api_gateway_method_response.cors_options
  ]
}

# ============================================================================
# Deployment
# ============================================================================

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  description = var.deployment_description

  # Triggers para forzar nuevo deployment cuando cambien recursos
  triggers = {
    redeployment = sha1(jsonencode([
      # Recursos
      [for k, v in aws_api_gateway_resource.this : v.id],
      # Métodos
      [for k, v in aws_api_gateway_method.this : v.id],
      # Integraciones
      [for k, v in aws_api_gateway_integration.this : v.id],
      # Authorizers
      [for k, v in aws_api_gateway_authorizer.this : v.id],
      # CORS
      [for k, v in aws_api_gateway_method.cors_options : v.id],
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.this,
    aws_api_gateway_integration.this,
    aws_api_gateway_method.cors_options,
    aws_api_gateway_integration.cors_options,
  ]
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
