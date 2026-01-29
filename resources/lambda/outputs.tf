output "resource_id" {
  description = "ID del recurso de API Gateway creado"
  value       = aws_api_gateway_resource.this.id
}

output "resource_path" {
  description = "Path completo del recurso"
  value       = aws_api_gateway_resource.this.path
}

output "method_id" {
  description = "ID del método HTTP"
  value       = aws_api_gateway_method.this.id
}

output "integration_id" {
  description = "ID de la integración"
  value       = aws_api_gateway_integration.this.id
}

output "invoke_url_path" {
  description = "Path para invocar el endpoint (usar con invoke_url del stage)"
  value       = aws_api_gateway_resource.this.path
}
