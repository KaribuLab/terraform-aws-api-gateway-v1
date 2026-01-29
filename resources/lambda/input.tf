# Variables requeridas del API Gateway principal
variable "rest_api_id" {
  description = "ID del REST API de API Gateway"
  type        = string
}

variable "parent_resource_id" {
  description = "ID del recurso padre (típicamente root_resource_id)"
  type        = string
}

variable "rest_api_execution_arn" {
  description = "ARN de ejecución del REST API"
  type        = string
}

# Variables del recurso
variable "path_part" {
  description = "Parte del path para este recurso (ej: 'users', 'products')"
  type        = string
}

variable "http_method" {
  description = "Método HTTP (GET, POST, PUT, DELETE, etc.)"
  type        = string
}

# Variables de Lambda
variable "lambda_function_name" {
  description = "Nombre de la función Lambda"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "ARN de invocación de la función Lambda"
  type        = string
}

# Variables de autorización
variable "authorization_type" {
  description = "Tipo de autorización (NONE, AWS_IAM, CUSTOM, COGNITO_USER_POOLS)"
  type        = string
  default     = "NONE"
}

variable "authorizer_id" {
  description = "ID del authorizer (si se usa CUSTOM)"
  type        = string
  default     = null
}

variable "api_key_required" {
  description = "Si se requiere API Key para invocar el método"
  type        = bool
  default     = false
}

# Variables de integración
variable "integration_type" {
  description = "Tipo de integración (AWS_PROXY, AWS, HTTP, HTTP_PROXY, MOCK)"
  type        = string
  default     = "AWS_PROXY"
}

variable "timeout_milliseconds" {
  description = "Timeout de integración en milisegundos"
  type        = number
  default     = 29000
}

variable "request_templates" {
  description = "Plantillas de request para la integración"
  type        = map(string)
  default     = {}
}

# Variables de validación
variable "request_validator_id" {
  description = "ID del request validator"
  type        = string
  default     = null
}

variable "request_parameters" {
  description = "Parámetros de request"
  type        = map(bool)
  default     = {}
}

variable "request_models" {
  description = "Modelos de request"
  type        = map(string)
  default     = {}
}

# Variables de responses
variable "method_responses" {
  description = "Configuración de method responses"
  type = map(object({
    response_parameters = optional(map(bool), {})
    response_models     = optional(map(string), {})
  }))
  default = {
    "200" = {
      response_parameters = {}
      response_models     = {}
    }
  }
}

variable "integration_responses" {
  description = "Configuración de integration responses"
  type = map(object({
    response_parameters = optional(map(string), {})
    response_templates  = optional(map(string), {})
  }))
  default = {
    "200" = {
      response_parameters = {}
      response_templates  = {}
    }
  }
}

# Variables de CORS
variable "enable_cors" {
  description = "Habilitar soporte CORS (crea método OPTIONS automáticamente)"
  type        = bool
  default     = false
}

variable "cors_allow_origin" {
  description = "Valor de Access-Control-Allow-Origin para CORS"
  type        = string
  default     = "'*'"
}
