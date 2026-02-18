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

# ============================================================================
# Funciones Lambda de ejemplo
# ============================================================================

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
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "get_users" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.api_name}-get-users"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_function" "create_user" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.api_name}-create-user"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_function" "get_user" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.api_name}-get-user"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_function" "authorizer" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.api_name}-authorizer"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# ============================================================================
# API Gateway con todas las funcionalidades
# ============================================================================

module "api_gateway" {
  source = "../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = "Complete API Gateway example with all features"
  stage_name      = var.stage_name

  authorizers = {
    jwt_auth = {
      lambda_arn            = aws_lambda_function.authorizer.arn
      lambda_invoke_arn     = aws_lambda_function.authorizer.invoke_arn
      type                  = "TOKEN"
      identity_source       = "method.request.header.Authorization"
      authorizer_result_ttl = 300
    }
  }

  lambda_integrations = [
    {
      path                = "/users"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.get_users.invoke_arn
      lambda_function_arn = aws_lambda_function.get_users.arn
      enable_cors         = true
    },
    {
      path                = "/users"
      method              = "POST"
      lambda_invoke_arn   = aws_lambda_function.create_user.invoke_arn
      lambda_function_arn = aws_lambda_function.create_user.arn
      authorization_type  = "CUSTOM"
      authorizer_key      = "jwt_auth"
      enable_cors         = true
    },
    {
      path                = "/users/{id}"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.get_user.invoke_arn
      lambda_function_arn = aws_lambda_function.get_user.arn
      api_key_required    = true
      enable_cors         = true
    }
  ]

  enable_api_key = true
  api_key_name   = "${var.api_name}-key"

  usage_plan_config = {
    name        = "${var.api_name}-plan"
    description = "Usage plan for ${var.api_name}"
    throttle_settings = {
      burst_limit = 100
      rate_limit  = 50
    }
    quota_settings = {
      limit  = 10000
      period = "DAY"
    }
  }

  cache_cluster_enabled = var.enable_cache
  cache_cluster_size    = "0.5"

  xray_tracing_enabled = true

  method_settings = {
    "users/GET" = {
      metrics_enabled        = true
      logging_level          = "INFO"
      caching_enabled        = var.enable_cache
      cache_ttl_in_seconds   = 300
      throttling_burst_limit = 200
      throttling_rate_limit  = 100
    }
  }

  tags = {
    Environment = var.stage_name
    ManagedBy   = "terraform"
    Project     = var.api_name
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "api_gateway_id" {
  description = "ID del API Gateway"
  value       = module.api_gateway.rest_api_id
}

output "api_gateway_url" {
  description = "URL de invocación del API Gateway"
  value       = module.api_gateway.stage_invoke_url
}

output "api_key_value" {
  description = "Valor de la API Key (sensible)"
  value       = module.api_gateway.api_key_value
  sensitive   = true
}
