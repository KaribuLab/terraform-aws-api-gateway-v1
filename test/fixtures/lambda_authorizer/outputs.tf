output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "authorizer_id" {
  value = module.api_gateway.authorizers["test_auth"]
}

output "lambda_function_arn" {
  value = aws_lambda_function.authorizer.arn
}
