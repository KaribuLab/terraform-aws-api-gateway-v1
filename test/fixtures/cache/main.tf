terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Crear IAM role para Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.api_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Crear función Lambda de prueba
resource "aws_lambda_function" "test" {
  filename         = "${path.module}/lambda_function.zip"
  function_name    = "${var.api_name}-test-function"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"

  tags = var.tags
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Crear el API Gateway con cache habilitado
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  stage_name      = "test"
  tags            = var.tags

  # Endpoint de prueba
  lambda_integrations = [
    {
      path                = "/test"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.test.invoke_arn
      lambda_function_arn = aws_lambda_function.test.arn
    }
  ]

  # Habilitar cache
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  # Configurar cache por método
  method_settings = {
    "test/GET" = {
      caching_enabled      = true
      cache_ttl_in_seconds = 300
    }
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
  default = "Test API Gateway with Cache"
}

variable "tags" {
  type    = map(string)
  default = {}
}
