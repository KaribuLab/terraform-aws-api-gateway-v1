# Variables requeridas del API Gateway principal
variable "rest_api_id" {
  description = "ID del REST API de API Gateway"
  type        = string
}

variable "parent_resource_id" {
  description = "ID del recurso padre (típicamente root_resource_id, o puede ser otro recurso para jerarquías anidadas)"
  type        = string
}

variable "path_part" {
  description = "Parte del path para este recurso (ej: 'users', '{id}', 'orders')"
  type        = string
}
