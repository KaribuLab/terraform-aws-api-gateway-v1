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

# Crear el API Gateway con configuración mínima (sin integraciones)
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  stage_name      = "test"
  tags            = var.tags
}

variable "aws_region" {
  type = string
}

variable "api_name" {
  type = string
}

variable "api_description" {
  type    = string
  default = "Basic API Gateway test"
}

variable "tags" {
  type    = map(string)
  default = {}
}
