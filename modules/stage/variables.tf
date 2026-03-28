# ============================================================================
# Variables del submódulo Stage
# ============================================================================

variable "rest_api_id" {
  description = "ID del API Gateway REST API."
  type        = string
}

variable "rest_api_execution_arn" {
  description = "ARN de ejecución del API Gateway REST API."
  type        = string
}

variable "tags" {
  description = "Tags a aplicar a todos los recursos."
  type        = map(string)
  default     = {}
}

variable "endpoint_type" {
  description = "Tipo de endpoint del API Gateway (REGIONAL, EDGE, PRIVATE). Requerido para validaciones WAF."
  type        = string
  default     = "REGIONAL"
}

variable "openapi_spec_sha" {
  description = "Hash del spec OpenAPI para trigger de redeploy. Se recomienda sha256(jsonencode(openapi_spec))."
  type        = string
}

# ============================================================================
# Variables del Stage
# ============================================================================

variable "stage_name" {
  description = "Nombre del stage (ej: 'dev', 'staging', 'prod')."
  type        = string
}

variable "stage_description" {
  description = "Descripción del stage."
  type        = string
  default     = "Stage managed by Terraform"
}

variable "stage_variables" {
  description = "Variables del stage (key-value pairs)."
  type        = map(string)
  default     = {}
}

variable "cache_cluster_enabled" {
  description = "Habilitar cache cluster para el stage."
  type        = bool
  default     = false
}

variable "cache_cluster_size" {
  description = "Tamaño del cache cluster (0.5, 1.6, 6.1, 13.5, 28.4, 58.2, 118, 237 GB)."
  type        = string
  default     = "0.5"
}

variable "xray_tracing_enabled" {
  description = "Habilitar AWS X-Ray tracing."
  type        = bool
  default     = false
}

variable "access_log_settings" {
  description = "Configuración de access logs para el stage."
  type = object({
    destination_arn = string
    format          = string
  })
  default = null
}

# ============================================================================
# Method Settings
# ============================================================================

variable "method_settings" {
  description = <<-EOT
    Configuración de settings por método (cache, throttling, logs).
    La clave es el path del método (ej: "users/GET", "*/*" para todos).
  EOT
  type = map(object({
    metrics_enabled        = optional(bool, false)
    logging_level          = optional(string, "OFF")
    data_trace_enabled     = optional(bool, false)
    throttling_burst_limit = optional(number, -1)
    throttling_rate_limit  = optional(number, -1)
    caching_enabled        = optional(bool, false)
    cache_ttl_in_seconds   = optional(number, 300)
    cache_data_encrypted   = optional(bool, false)
  }))
  default = {}
}

# ============================================================================
# WAF
# ============================================================================

variable "waf_web_acl_arn" {
  description = "ARN del Web ACL de AWS WAFv2 para asociarlo al stage (opcional). Requiere endpoint_type = REGIONAL."
  type        = string
  default     = null
}

# ============================================================================
# API Key y Usage Plan (opcional)
# ============================================================================

variable "api_key_config" {
  description = <<-EOT
    Configuración de API Key y Usage Plan para este stage (opcional).
    Si es null, no se crea API Key ni Usage Plan.
  EOT
  type = object({
    name        = optional(string, null)
    description = optional(string, "API Key managed by Terraform")
    usage_plan = optional(object({
      name        = optional(string, "api-usage-plan")
      description = optional(string, "Usage plan managed by Terraform")
      quota_settings = optional(object({
        limit  = number
        period = string
      }), null)
      throttle_settings = optional(object({
        burst_limit = number
        rate_limit  = number
      }), null)
    }), null)
  })
  default = null
}

# ============================================================================
# Permisos Lambda para aliases (opcional)
# ============================================================================

variable "lambda_integrations" {
  description = <<-EOT
    Lista de integraciones Lambda que usan alias via stage variables.
    Se usa para crear permisos de invocacion con el qualifier del alias.
    Cada integracion debe especificar el ARN de la funcion y el nombre de la
    stage variable que contiene el alias.

    Tipo `any` (lista): permite omitir `lambda_alias_variable` en JSON (TF_VAR_lambda_integrations,
    Terragrunt); las entradas sin alias no generan permiso en este modulo.
  EOT
  type    = any
  default = []

  validation {
    condition = alltrue([
      for i in var.lambda_integrations :
      try(i.lambda_function_arn, null) != null
    ]) || length(var.lambda_integrations) == 0
    error_message = "Cada elemento de lambda_integrations debe incluir lambda_function_arn cuando la lista no esta vacia."
  }
}
