output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "stage_arn" {
  value = module.api_gateway.stage_arn
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.test.arn
}
