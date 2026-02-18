# ============================================================================
# Variables principales del API Gateway
# ============================================================================

variable "aws_region" {
  description = "AWS region donde se creará el API Gateway."
  type        = string
}

variable "api_name" {
  description = "Nombre del API Gateway."
  type        = string
}

variable "api_description" {
  description = "Descripción del API Gateway."
  type        = string
  default     = "API Gateway managed by Terraform"
}

variable "tags" {
  description = "Tags a aplicar a todos los recursos."
  type        = map(string)
  default     = {}
}

# ============================================================================
# Integraciones Lambda
# ============================================================================

variable "lambda_integrations" {
  description = <<-EOT
    Lista de integraciones Lambda para el API Gateway.
    Cada integración define un endpoint (path + método HTTP) conectado a una función Lambda vía AWS_PROXY.

    Campos:
    - path: Ruta completa del endpoint (ej: "/users", "/profile/{id}", "/profile/{id}/orders")
    - method: Método HTTP (GET, POST, PUT, DELETE, PATCH, HEAD, ANY)
    - lambda_invoke_arn: ARN de invocación de la función Lambda
    - lambda_function_arn: ARN de la función Lambda (para permisos de invocación)
    - authorization_type: Tipo de autorización (NONE, CUSTOM). Default: NONE
    - authorizer_key: Clave del authorizer en var.authorizers (requerido si authorization_type = CUSTOM)
    - api_key_required: Si requiere API Key. Default: false
    - enable_cors: Habilitar CORS automático. Default: false
    - cors_allow_origin: Valor de Access-Control-Allow-Origin. Default: "'*'"
    - cors_allow_headers: Headers permitidos en CORS. Default: estándar
    - cors_allow_methods: Métodos permitidos en CORS (se genera automáticamente si no se especifica)
  EOT
  type = list(object({
    path                = string
    method              = string
    lambda_invoke_arn   = string
    lambda_function_arn = string
    authorization_type  = optional(string, "NONE")
    authorizer_key      = optional(string, null)
    api_key_required    = optional(bool, false)
    enable_cors         = optional(bool, false)
    cors_allow_origin   = optional(string, "'*'")
    cors_allow_headers  = optional(string, "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'")
    cors_allow_methods  = optional(string, null)
  }))
  default = []

  validation {
    condition = alltrue([
      for i in var.lambda_integrations :
      contains(["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "ANY"], i.method)
    ])
    error_message = "El método HTTP debe ser uno de: GET, POST, PUT, DELETE, PATCH, HEAD, ANY."
  }

  validation {
    condition = alltrue([
      for i in var.lambda_integrations :
      contains(["NONE", "CUSTOM"], i.authorization_type)
    ])
    error_message = "authorization_type debe ser NONE o CUSTOM."
  }

  validation {
    condition = alltrue([
      for i in var.lambda_integrations :
      i.authorization_type != "CUSTOM" || i.authorizer_key != null
    ])
    error_message = "Cuando authorization_type es CUSTOM, authorizer_key es requerido."
  }
}

# ============================================================================
# Authorizers (Lambda Authorizers)
# ============================================================================

variable "authorizers" {
  description = <<-EOT
    Mapa de Lambda Authorizers para el API Gateway.
    La clave del mapa se usa como referencia en lambda_integrations[].authorizer_key.
  EOT
  type = map(object({
    lambda_arn                     = string
    lambda_invoke_arn              = string
    type                           = optional(string, "TOKEN")
    identity_source                = optional(string, "method.request.header.Authorization")
    authorizer_result_ttl          = optional(number, 300)
    identity_validation_expression = optional(string, null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, auth in var.authorizers :
      contains(["TOKEN", "REQUEST"], auth.type)
    ])
    error_message = "El tipo de authorizer debe ser TOKEN o REQUEST."
  }
}

# ============================================================================
# Stage y Deployment
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
# API Key y Usage Plan (opcional)
# ============================================================================

variable "enable_api_key" {
  description = "Habilitar creación de API Key."
  type        = bool
  default     = false
}

variable "api_key_name" {
  description = "Nombre de la API Key."
  type        = string
  default     = null
}

variable "api_key_description" {
  description = "Descripción de la API Key."
  type        = string
  default     = "API Key managed by Terraform"
}

variable "usage_plan_config" {
  description = "Configuración del Usage Plan (requerido si enable_api_key es true)."
  type = object({
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
  })
  default = null
}
