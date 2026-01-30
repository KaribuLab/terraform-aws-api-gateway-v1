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

# Crear el API Gateway principal
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  tags            = var.tags
}

# Crear IAM role para Lambda
resource "aws_iam_role" "lambda" {
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

# Crear función Lambda de prueba
resource "aws_lambda_function" "test" {
  filename         = "${path.module}/lambda_function.zip"
  function_name    = var.lambda_function_name
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

# Crear el recurso /users usando el submódulo parent
module "users_resource" {
  source = "../../../resources/parent"

  rest_api_id        = module.api_gateway.rest_api_id
  parent_resource_id = module.api_gateway.rest_api_root_resource_id
  path_part          = "users"
}

# GET /users - usar el recurso compartido
module "users_get" {
  source = "../../../resources/lambda"

  rest_api_id            = module.api_gateway.rest_api_id
  resource_id            = module.users_resource.resource_id
  create_resource        = false
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn

  http_method          = "GET"
  lambda_function_name = aws_lambda_function.test.function_name
  lambda_invoke_arn    = aws_lambda_function.test.invoke_arn

  # Sin authorizer (básico)
  authorization_type = "NONE"
}

# POST /users - usar el mismo recurso compartido
module "users_post" {
  source = "../../../resources/lambda"

  rest_api_id            = module.api_gateway.rest_api_id
  resource_id            = module.users_resource.resource_id
  create_resource        = false
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn

  http_method          = "POST"
  lambda_function_name = aws_lambda_function.test.function_name
  lambda_invoke_arn    = aws_lambda_function.test.invoke_arn

  # Con CORS habilitado
  enable_cors       = true
  cors_allow_origin = "'*'"
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

variable "api_description" {
  type    = string
  default = "Test API Gateway with Lambda Resource Module"
}

variable "tags" {
  type    = map(string)
  default = {}
}
