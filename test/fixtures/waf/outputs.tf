output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "stage_name" {
  value = module.api_gateway.stage_name
}

output "stage_arn" {
  value = module.api_gateway.stage_arn
}

output "invoke_url" {
  value = module.api_gateway.stage_invoke_url
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.test.arn
}
