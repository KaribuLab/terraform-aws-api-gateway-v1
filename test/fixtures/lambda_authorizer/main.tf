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
resource "aws_iam_role" "lambda_authorizer" {
  name = "${var.lambda_function_name}-role"

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

# Crear Lambda function
resource "aws_lambda_function" "authorizer" {
  filename         = "${path.module}/lambda_function.zip"
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_authorizer.arn
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

# Crear API Gateway con Lambda Authorizer
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  stage_name      = "test"
  tags            = var.tags

  # Definir authorizer
  authorizers = {
    test_auth = {
      lambda_arn            = aws_lambda_function.authorizer.arn
      type                  = "TOKEN"
      identity_source       = "method.request.header.Authorization"
      authorizer_result_ttl = 300
    }
  }

  # Endpoint protegido con authorizer
  lambda_integrations = [
    {
      path                = "/test"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.authorizer.invoke_arn
      lambda_function_arn = aws_lambda_function.authorizer.arn
      authorization_type  = "CUSTOM"
      authorizer_key      = "test_auth"
    }
  ]
}

variable "aws_region" {
  type = string
}

variable "api_name" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "authorizer_name" {
  type = string
}

variable "api_description" {
  type    = string
  default = "Test API Gateway with Lambda Authorizer"
}

variable "tags" {
  type    = map(string)
  default = {}
}
