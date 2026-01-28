output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "api_key_id" {
  value = module.api_gateway.api_key_id
}

output "api_key_value" {
  value     = module.api_gateway.api_key_value
  sensitive = true
}

output "usage_plan_id" {
  value = module.api_gateway.usage_plan_id
}
