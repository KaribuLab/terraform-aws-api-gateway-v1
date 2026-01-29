output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "users_get_resource_id" {
  value = module.users_get.resource_id
}

output "users_get_resource_path" {
  value = module.users_get.resource_path
}

output "users_get_method_id" {
  value = module.users_get.method_id
}

output "users_post_resource_id" {
  value = module.users_post.resource_id
}

output "users_post_resource_path" {
  value = module.users_post.resource_path
}

output "lambda_function_name" {
  value = aws_lambda_function.test.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.test.arn
}
