output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "stage_name" {
  value = var.stage_name
}

output "initial_deployment_id" {
  value = aws_api_gateway_deployment.initial.id
}

output "module_deployment_id" {
  value = module.stage_test.deployment_id
}

output "stage_exists" {
  value = module.stage_test.stage_exists
}
