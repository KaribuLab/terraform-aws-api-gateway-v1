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

module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  tags            = var.tags
  # stage_config = null (por defecto, no crea stage)

  # Configuración de API Key
  enable_api_key = true
  api_key_name   = var.api_key_name
  api_key_description = "Test API Key"

  usage_plan_config = {
    name        = var.usage_plan_name
    description = "Test Usage Plan"
    throttle_settings = {
      burst_limit = 100
      rate_limit  = 50
    }
  }
}

# Agregar un recurso y método de prueba
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

variable "aws_region" {
  type = string
}

variable "api_name" {
  type = string
}

variable "api_key_name" {
  type = string
}

variable "usage_plan_name" {
  type = string
}

variable "api_description" {
  type    = string
  default = "Test API Gateway with API Key"
}

variable "tags" {
  type    = map(string)
  default = {}
}
