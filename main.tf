terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region where the API Gateway should be created."
  type        = string
}

variable "api_name" {
  description = "Human-friendly name for the API Gateway."
  type        = string
  default     = "managed-api-gateway"
}

variable "api_description" {
  description = "Short description describing the API Gateway."
  type        = string
  default     = "API Gateway managed by Terraform"
}

variable "tags" {
  description = "Tags to apply to the API Gateway resources."
  type        = map(string)
  default     = {}
}

variable "stage_config" {
  description = "Configuración opcional del stage. Si es null, el usuario debe crear el stage externamente."
  type = object({
    stage_name    = string
    description   = optional(string, "Stage managed by Terraform")
    variables     = optional(map(string), {})
    cache_cluster_enabled = optional(bool, false)
    cache_cluster_size    = optional(string, "0.5")
    xray_tracing_enabled  = optional(bool, false)
  })
  default = null
}

variable "deployment_id" {
  description = "ID del deployment a usar para el stage (requerido si stage_config está definido)."
  type        = string
  default     = null
}

# ============================================================================
# Variables opcionales para autenticación
# ============================================================================

variable "enable_api_key" {
  description = "Habilita la creación de API Key para autenticación."
  type        = bool
  default     = false
}

variable "api_key_name" {
  description = "Nombre de la API Key (requerido si enable_api_key es true)."
  type        = string
  default     = null
}

variable "api_key_description" {
  description = "Descripción de la API Key."
  type        = string
  default     = null
}

variable "usage_plan_config" {
  description = "Configuración del Usage Plan para la API Key. Solo se usa si enable_api_key es true."
  type = object({
    name        = optional(string, "api-usage-plan")
    description = optional(string, "Usage plan for API Gateway")
    quota_settings = optional(object({
      limit  = number
      period = string # DAY, WEEK, MONTH
    }), null)
    throttle_settings = optional(object({
      burst_limit = number
      rate_limit  = number
    }), null)
  })
  default = null
}

variable "authorizer_config" {
  description = "Configuración del Lambda Authorizer. Si se define, crea un Lambda Authorizer."
  type = object({
    name                  = string
    lambda_arn            = string
    type                  = optional(string, "TOKEN") # TOKEN o REQUEST
    identity_source       = optional(string, "method.request.header.Authorization")
    authorizer_result_ttl = optional(number, 300)
    identity_validation_expression = optional(string, null)
  })
  default = null
}


resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = var.api_description
  tags        = var.tags
}

# ============================================================================
# Stage opcional
# ============================================================================

resource "aws_api_gateway_stage" "this" {
  count = var.stage_config != null ? 1 : 0
  
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = var.deployment_id
  stage_name    = var.stage_config.stage_name
  description   = var.stage_config.description
  variables     = var.stage_config.variables
  
  cache_cluster_enabled = var.stage_config.cache_cluster_enabled
  cache_cluster_size    = var.stage_config.cache_cluster_enabled ? var.stage_config.cache_cluster_size : null
  
  xray_tracing_enabled = var.stage_config.xray_tracing_enabled
  
  tags = var.tags
}

# ============================================================================
# Recursos opcionales para autenticación - API Key
# ============================================================================

resource "aws_api_gateway_api_key" "this" {
  count       = var.enable_api_key ? 1 : 0
  name        = var.api_key_name != null ? var.api_key_name : "${var.api_name}-key"
  description = var.api_key_description
  enabled     = true
  tags        = var.tags
}

resource "aws_api_gateway_usage_plan" "this" {
  count       = var.enable_api_key && var.usage_plan_config != null ? 1 : 0
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

  # Si el módulo crea el stage, asociarlo automáticamente
  dynamic "api_stages" {
    for_each = var.stage_config != null ? [1] : []
    content {
      api_id = aws_api_gateway_rest_api.this.id
      stage  = aws_api_gateway_stage.this[0].stage_name
    }
  }

  tags = var.tags
}

resource "aws_api_gateway_usage_plan_key" "this" {
  count         = var.enable_api_key && var.usage_plan_config != null ? 1 : 0
  key_id        = aws_api_gateway_api_key.this[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this[0].id
}

# ============================================================================
# Recursos opcionales para autenticación - Lambda Authorizer
# ============================================================================

resource "aws_api_gateway_authorizer" "this" {
  count                             = var.authorizer_config != null ? 1 : 0
  name                              = var.authorizer_config.name
  rest_api_id                       = aws_api_gateway_rest_api.this.id
  authorizer_uri                    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.authorizer_config.lambda_arn}/invocations"
  authorizer_credentials            = null
  authorizer_result_ttl_in_seconds  = var.authorizer_config.authorizer_result_ttl
  identity_source                   = var.authorizer_config.identity_source
  type                              = var.authorizer_config.type
  identity_validation_expression    = var.authorizer_config.identity_validation_expression
}

# Permiso para que API Gateway invoque la función Lambda
resource "aws_lambda_permission" "api_gateway" {
  count         = var.authorizer_config != null ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer_config.lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/authorizers/*"
}

# Nota: WAF, caché y throttling requieren un stage.
# El usuario debe crear el deployment y stage, y luego puede usar:
# - aws_wafv2_web_acl_association para asociar WAF al stage
# - aws_api_gateway_method_settings para configurar caché y throttling por método
