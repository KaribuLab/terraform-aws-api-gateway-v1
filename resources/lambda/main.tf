# Crear recurso solo si create_resource es true
resource "aws_api_gateway_resource" "this" {
  count = var.create_resource ? 1 : 0

  rest_api_id = var.rest_api_id
  parent_id   = var.parent_resource_id
  path_part   = var.path_part
}

# Usar el resource_id proporcionado o el creado internamente
locals {
  resource_id = var.create_resource ? aws_api_gateway_resource.this[0].id : var.resource_id
}

# Método principal (GET, POST, etc.)
resource "aws_api_gateway_method" "this" {
  rest_api_id   = var.rest_api_id
  resource_id   = local.resource_id
  http_method   = var.http_method
  authorization = var.authorizer_id != null ? "CUSTOM" : var.authorization_type
  authorizer_id = var.authorizer_id

  api_key_required = var.api_key_required

  request_validator_id = var.request_validator_id
  request_parameters   = var.request_parameters
  request_models       = var.request_models
}

# Integración con Lambda
resource "aws_api_gateway_integration" "this" {
  rest_api_id = var.rest_api_id
  resource_id = local.resource_id
  http_method = aws_api_gateway_method.this.http_method

  integration_http_method = "POST"
  type                    = var.integration_type
  uri                     = var.lambda_invoke_arn

  request_templates    = var.request_templates
  timeout_milliseconds = var.timeout_milliseconds
}

# Permiso para que API Gateway invoque Lambda
resource "aws_lambda_permission" "this" {
  statement_id  = "AllowAPIGatewayInvoke-${var.path_part != null ? var.path_part : "resource"}-${var.http_method}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.rest_api_execution_arn}/*/*"
}

# Method responses (configurables)
resource "aws_api_gateway_method_response" "this" {
  for_each = var.method_responses

  rest_api_id = var.rest_api_id
  resource_id = local.resource_id
  http_method = aws_api_gateway_method.this.http_method
  status_code = each.key

  response_parameters = each.value.response_parameters
  response_models     = each.value.response_models
}

# Integration responses (configurables)
resource "aws_api_gateway_integration_response" "this" {
  for_each = var.integration_responses

  rest_api_id = var.rest_api_id
  resource_id = local.resource_id
  http_method = aws_api_gateway_method.this.http_method
  status_code = each.key

  response_parameters = each.value.response_parameters
  response_templates  = each.value.response_templates

  depends_on = [
    aws_api_gateway_integration.this,
    aws_api_gateway_method_response.this
  ]
}

# ============================================================================
# CORS Support (opcional)
# ============================================================================

resource "aws_api_gateway_method" "options" {
  count = var.enable_cors ? 1 : 0

  rest_api_id   = var.rest_api_id
  resource_id   = local.resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  count = var.enable_cors ? 1 : 0

  rest_api_id = var.rest_api_id
  resource_id = local.resource_id
  http_method = aws_api_gateway_method.options[0].http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  count = var.enable_cors ? 1 : 0

  rest_api_id = var.rest_api_id
  resource_id = local.resource_id
  http_method = aws_api_gateway_method.options[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  count = var.enable_cors ? 1 : 0

  rest_api_id = var.rest_api_id
  resource_id = local.resource_id
  http_method = aws_api_gateway_method.options[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'${var.http_method},OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_allow_origin
  }

  depends_on = [
    aws_api_gateway_integration.options,
    aws_api_gateway_method_response.options
  ]
}
