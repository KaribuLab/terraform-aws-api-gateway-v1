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

# Crear el API Gateway primero
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  tags            = var.tags
}

# Crear recursos y métodos
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
  http_method  = aws_api_gateway_method.test.http_method
  type         = "MOCK"
}

# Crear deployment
resource "aws_api_gateway_deployment" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.test.id,
      aws_api_gateway_method.test.id,
      aws_api_gateway_integration.test.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Crear stage directamente
resource "aws_api_gateway_stage" "test" {
  rest_api_id   = module.api_gateway.rest_api_id
  deployment_id = aws_api_gateway_deployment.test.id
  stage_name    = var.stage_name
  
  tags = var.tags
}

# Configurar throttling por método
resource "aws_api_gateway_method_settings" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = aws_api_gateway_stage.test.stage_name
  method_path = "${aws_api_gateway_resource.test.path_part}/${aws_api_gateway_method.test.http_method}"
  
  settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

variable "aws_region" {
  type = string
}

variable "api_name" {
  type = string
}

variable "api_description" {
  type    = string
  default = "Test API Gateway with Throttling"
}

variable "stage_name" {
  type    = string
  default = "test"
}

variable "tags" {
  type    = map(string)
  default = {}
}
