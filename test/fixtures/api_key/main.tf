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

# Crear el API Gateway con API Key
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  stage_name      = "test"
  tags            = var.tags

  # Endpoint que requiere API Key
  lambda_integrations = [
    {
      path                = "/test"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.test.invoke_arn
      lambda_function_arn = aws_lambda_function.test.arn
      api_key_required    = true
    }
  ]

  # Habilitar API Key
  enable_api_key = true
  api_key_name   = var.api_key_name

  usage_plan_config = {
    name        = var.usage_plan_name
    description = "Usage plan for API Key test"
    throttle_settings = {
      burst_limit = 100
      rate_limit  = 50
    }
  }
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
