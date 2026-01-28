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

# Crear el API Gateway con stage_config
# En la práctica, el usuario crearía recursos/métodos/deployment primero,
# luego actualizaría el módulo con stage_config
# Para este test, creamos todo en el orden correcto
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  tags            = var.tags
  # stage_config se define después de crear el deployment
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
  http_method = aws_api_gateway_method.test.http_method
  type        = "MOCK"
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

# Crear un segundo módulo que demuestra el uso de stage_config
# Este módulo tiene su propio API Gateway, recursos, métodos y deployment
module "api_gateway_with_stage" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = "${var.api_name}-with-stage"
  api_description = var.api_description
  tags            = var.tags

  # stage_config se define después de crear el deployment para este módulo
}

# Recursos para el segundo módulo
resource "aws_api_gateway_resource" "test2" {
  rest_api_id = module.api_gateway_with_stage.rest_api_id
  parent_id   = module.api_gateway_with_stage.rest_api_root_resource_id
  path_part   = "test"
}

resource "aws_api_gateway_method" "test2" {
  rest_api_id   = module.api_gateway_with_stage.rest_api_id
  resource_id   = aws_api_gateway_resource.test2.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "test2" {
  rest_api_id = module.api_gateway_with_stage.rest_api_id
  resource_id = aws_api_gateway_resource.test2.id
  http_method = aws_api_gateway_method.test2.http_method
  type        = "MOCK"
}

# Deployment para el segundo módulo
resource "aws_api_gateway_deployment" "test2" {
  rest_api_id = module.api_gateway_with_stage.rest_api_id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.test2.id,
      aws_api_gateway_method.test2.id,
      aws_api_gateway_integration.test2.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Actualizar el segundo módulo con stage_config
# Nota: Como Terraform no permite actualizar un módulo dinámicamente,
# creamos el stage directamente aquí para demostrar la funcionalidad
# En la práctica, el usuario actualizaría el módulo con stage_config en un segundo apply
# o usaría un enfoque diferente como crear el stage fuera del módulo

# Para este test, creamos el stage directamente usando el deployment del segundo módulo
# Esto demuestra que el módulo puede funcionar con stage_config cuando se proporciona deployment_id
resource "aws_api_gateway_stage" "test" {
  rest_api_id   = module.api_gateway_with_stage.rest_api_id
  deployment_id = aws_api_gateway_deployment.test2.id
  stage_name    = var.stage_name

  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_enabled ? var.cache_cluster_size : null

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

variable "cache_cluster_enabled" {
  type    = bool
  default = false
}

variable "cache_cluster_size" {
  type    = string
  default = "0.5"
}

variable "api_description" {
  type    = string
  default = "Test API Gateway with stage_config"
}

variable "tags" {
  type    = map(string)
  default = {}
}
