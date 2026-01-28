output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "stage_name" {
  value = aws_api_gateway_stage.test.stage_name
}

output "stage_arn" {
  value = aws_api_gateway_stage.test.arn
}

output "invoke_url" {
  value = aws_api_gateway_stage.test.invoke_url
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.test.arn
}
