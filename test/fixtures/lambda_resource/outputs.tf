output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "rest_api_root_resource_id" {
  value = module.api_gateway.rest_api_root_resource_id
}

output "stage_invoke_url" {
  value = module.api_gateway.stage_invoke_url
}

output "lambda_function_name" {
  value = aws_lambda_function.test.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.test.arn
}
