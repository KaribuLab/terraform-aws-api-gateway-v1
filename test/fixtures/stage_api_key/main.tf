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
  rest_api_id      = module.api_gateway.rest_api_id
  resource_id      = aws_api_gateway_resource.test.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true # Requerir API Key
}

resource "aws_api_gateway_integration" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.test.id
  http_method = aws_api_gateway_method.test.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.test.id
  http_method = aws_api_gateway_method.test.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.test.id
  http_method = aws_api_gateway_method.test.http_method
  status_code = aws_api_gateway_method_response.test.status_code

  response_templates = {
    "application/json" = jsonencode({
      message = "Hello from API Gateway with API Key"
    })
  }
}

# Crear stage con API Key usando el submódulo
module "stage_test" {
  source = "../../../stage"

  rest_api_id = module.api_gateway.rest_api_id
  aws_region  = var.aws_region
  stage_name  = var.stage_name

  # Deshabilitar detección automática para test limpio
  auto_detect_existing_stage = false

  # Triggers para deployment
  deployment_triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.test.id,
      aws_api_gateway_method.test.id,
      aws_api_gateway_integration.test.id,
      aws_api_gateway_method_response.test.id,
      aws_api_gateway_integration_response.test.id,
    ]))
  }

  # Crear API Key
  api_key_config = {
    name        = var.api_key_name
    description = "API Key for stage module test"
  }

  # Usage Plan (requerido)
  usage_plan_config = {
    name        = var.usage_plan_name
    description = "Usage plan for stage module test"
    throttle_settings = {
      burst_limit = 100
      rate_limit  = 50
    }
  }

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
  default = "Test API Gateway with Stage Module API Key"
}

variable "api_key_name" {
  type = string
}

variable "usage_plan_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
