variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "api_name" {
  description = "Nombre del API Gateway"
  type        = string
}

variable "stage_name" {
  description = "Nombre del stage"
  type        = string
  default     = "dev"
}

variable "enable_cache" {
  description = "Habilitar cache cluster"
  type        = bool
  default     = false
}
