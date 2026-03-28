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
# Funciones Lambda de ejemplo con aliases
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

# Crear la funcion Lambda
resource "aws_lambda_function" "users" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.api_name}-users"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# Crear aliases para dev y staging
resource "aws_lambda_alias" "dev" {
  name             = "dev"
  description      = "Alias for dev environment"
  function_name    = aws_lambda_function.users.function_name
  function_version = "$LATEST"
}

resource "aws_lambda_alias" "staging" {
  name             = "staging"
  description      = "Alias for staging environment"
  function_name    = aws_lambda_function.users.function_name
  function_version = "$LATEST"
}

# ============================================================================
# API Gateway (modulo raiz sin stage)
# ============================================================================

module "api_gateway" {
  source = "../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = "Multi-stage API Gateway example with Lambda aliases"

  # No creamos stage aqui -- los stages se crean con el submodulo
  create_stage = false

  # Usamos lambda_alias_variable para que la URI sea dinamica
  lambda_integrations = [
    {
      path                  = "/users"
      method                = "GET"
      lambda_function_arn   = aws_lambda_function.users.arn
      lambda_alias_variable = "lambda_alias"
      enable_cors           = true
    }
  ]

  tags = {
    Environment = "multi-stage-demo"
    ManagedBy   = "terraform"
    Project     = var.api_name
  }
}

# ============================================================================
# Stage "dev" (submodulo stage)
# ============================================================================

module "stage_dev" {
  source = "../../modules/stage"

  rest_api_id            = module.api_gateway.rest_api_id
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn
  tags                   = { Environment = "dev", ManagedBy = "terraform" }
  endpoint_type          = "REGIONAL"
  openapi_spec_sha       = module.api_gateway.openapi_spec_sha

  stage_name        = "dev"
  stage_description = "Development stage"

  # La stage variable que contiene el alias
  stage_variables = {
    lambda_alias = "dev"
  }
}

# ============================================================================
# Stage "staging" (submodulo stage)
# ============================================================================

module "stage_staging" {
  source = "../../modules/stage"

  rest_api_id            = module.api_gateway.rest_api_id
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn
  tags                   = { Environment = "staging", ManagedBy = "terraform" }
  endpoint_type          = "REGIONAL"
  openapi_spec_sha       = module.api_gateway.openapi_spec_sha

  stage_name        = "staging"
  stage_description = "Staging stage"

  # La stage variable que contiene el alias
  stage_variables = {
    lambda_alias = "staging"
  }
}

# Permisos para invocar cada alias (equivalente a pasar lambda_integrations al submodulo stage).
# Se declaran aqui para evitar falsos positivos del language server en module.lambda_integrations.
resource "aws_lambda_permission" "apigw_invoke_alias_dev" {
  statement_id  = "AllowAPIGatewayInvoke-${module.stage_dev.stage_name}-users-alias"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.users.arn
  qualifier     = aws_lambda_alias.dev.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.rest_api_execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_alias_staging" {
  statement_id  = "AllowAPIGatewayInvoke-${module.stage_staging.stage_name}-users-alias"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.users.arn
  qualifier     = aws_lambda_alias.staging.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.rest_api_execution_arn}/*/*"
}
