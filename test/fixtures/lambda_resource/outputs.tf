output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "rest_api_root_resource_id" {
  value = module.api_gateway.rest_api_root_resource_id
}

# Outputs compatibles con el test
output "users_resource_id" {
  description = "ID del recurso /users"
  value       = module.api_gateway.resources["/users"]
}

output "users_resource_path" {
  description = "Path del recurso /users"
  value       = "/users"
}

output "users_get_resource_id" {
  description = "ID del recurso para GET /users"
  value       = module.api_gateway.resources["/users"]
}

output "users_get_method_id" {
  description = "ID del método GET /users"
  value       = module.api_gateway.methods["/users#GET"]
}

output "users_post_resource_id" {
  description = "ID del recurso para POST /users"
  value       = module.api_gateway.resources["/users"]
}

output "lambda_function_name" {
  value = aws_lambda_function.test.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.test.arn
}
