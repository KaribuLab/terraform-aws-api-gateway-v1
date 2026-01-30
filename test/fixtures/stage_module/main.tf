terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Crear el API Gateway principal
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  tags            = var.tags
}

# Crear recursos y métodos para el test
resource "aws_api_gateway_resource" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  parent_id   = module.api_gateway.rest_api_root_resource_id
  path_part   = "test"
}

resource "aws_api_gateway_method" "test" {
  rest_api_id   = module.api_gateway.rest_api_id
  resource_id   = aws_api_gateway_resource.test.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.test.id
  http_method = aws_api_gateway_method.test.http_method
  type        = "MOCK"
}

# Crear stage usando el submódulo
module "stage_test" {
  source = "../../../stage"

  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = var.stage_name

  # Triggers para deployment
  deployment_triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.test.id,
      aws_api_gateway_method.test.id,
      aws_api_gateway_integration.test.id,
    ]))
  }

  # Cache y throttling
  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_size

  # Method settings con throttling
  method_settings = var.method_settings

  tags = var.tags
}

variable "aws_region" {
  type = string
}

variable "api_name" {
  type = string
}

variable "stage_name" {
  type    = string
  default = "test"
}

variable "api_description" {
  type    = string
  default = "Test API Gateway with Stage Module"
}

variable "cache_cluster_enabled" {
  type    = bool
  default = false
}

variable "cache_cluster_size" {
  type    = string
  default = "0.5"
}

variable "method_settings" {
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
  type    = map(string)
  default = {}
}
