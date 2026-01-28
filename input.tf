# Variables principales
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

# ============================================================================
# Variables de Stage
# ============================================================================

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
# Variables de autenticación - API Key
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

# ============================================================================
# Variables de autenticación - Lambda Authorizer
# ============================================================================

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
