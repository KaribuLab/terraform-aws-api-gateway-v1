output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "deployment_id" {
  value = module.stage_test.deployment_id
}

output "stage_name" {
  value = module.stage_test.stage_name
}

output "stage_arn" {
  value = module.stage_test.stage_arn
}

output "invoke_url" {
  value = module.stage_test.invoke_url
}

output "execution_arn" {
  value = module.stage_test.execution_arn
}

output "api_key_id" {
  value = module.stage_test.api_key_id
}

output "api_key_value" {
  value     = module.stage_test.api_key_value
  sensitive = true
}

output "usage_plan_id" {
  value = module.stage_test.usage_plan_id
}
