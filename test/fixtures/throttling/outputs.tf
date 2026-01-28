output "rest_api_id" {
  value = module.api_gateway.rest_api_id
}

output "stage_name" {
  value = aws_api_gateway_stage.test.stage_name
}

output "invoke_url" {
  value = aws_api_gateway_stage.test.invoke_url
}
