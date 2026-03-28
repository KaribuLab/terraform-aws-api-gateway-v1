variable "aws_region" {
  description = "AWS region donde se crearán los recursos."
  type        = string
  default     = "us-east-1"
}

variable "api_name" {
  description = "Nombre del API Gateway."
  type        = string
  default     = "multi-stage-api-example"
}
