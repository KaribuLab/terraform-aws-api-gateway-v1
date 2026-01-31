variable "rest_api_id" {
  description = "ID del REST API de API Gateway"
  type        = string
}

variable "aws_region" {
  description = "Región de AWS para la verificación del stage"
  type        = string
}

variable "auto_detect_existing_stage" {
  description = "Si es true, detecta automáticamente si el stage existe"
  type        = bool
  default     = true
}

variable "stage_name" {
  description = "Nombre del stage (ej: 'dev', 'staging', 'prod')"
  type        = string
}

variable "stage_description" {
  description = "Descripción del stage"
  type        = string
  default     = null
}

variable "deployment_description" {
  description = "Descripción del deployment"
  type        = string
  default     = "Managed by Terraform"
}

variable "deployment_triggers" {
  description = "Map de triggers para forzar nuevo deployment cuando cambien recursos"
  type        = map(string)
  default     = {}
}

variable "stage_variables" {
  description = "Variables del stage (key-value pairs)"
  type        = map(string)
  default     = {}
}

variable "cache_cluster_enabled" {
  description = "Habilitar cache cluster para el stage"
  type        = bool
  default     = false
}

variable "cache_cluster_size" {
  description = "Tamaño del cache cluster (0.5, 1.6, 6.1, 13.5, 28.4, 58.2, 118, 237 GB)"
  type        = string
  default     = "0.5"
}

variable "xray_tracing_enabled" {
  description = "Habilitar AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "access_log_settings" {
  description = "Configuración de access logs"
  type = object({
    destination_arn = string
    format          = string
  })
  default = null
}

variable "method_settings" {
  description = "Configuración de settings por método (cache, throttling, logs)"
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

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default     = {}
}

# ============================================================================
# Variables de API Key
# ============================================================================

variable "api_key_id" {
  description = "ID de una API Key existente para asociar al Usage Plan. Si se define, no se crea una nueva API Key."
  type        = string
  default     = null
}

variable "api_key_config" {
  description = "Configuración para crear una nueva API Key. Solo se usa si api_key_id es null."
  type = object({
    name        = string
    description = optional(string, "API Key managed by Terraform")
    enabled     = optional(bool, true)
  })
  default = null
}

variable "usage_plan_config" {
  description = "Configuración del Usage Plan. Requerido si api_key_id o api_key_config está definido."
  type = object({
    name        = optional(string, "stage-usage-plan")
    description = optional(string, "Usage plan managed by Terraform")
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
