output "resource_id" {
  description = "ID del recurso de API Gateway"
  value       = local.resource_id
}

output "resource_path" {
  description = "Path completo del recurso (solo disponible si el recurso fue creado por este módulo)"
  value       = var.create_resource ? aws_api_gateway_resource.this[0].path : null
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
  description = "Path para invocar el endpoint (usar con invoke_url del stage). Solo disponible si el recurso fue creado por este módulo"
  value       = var.create_resource ? aws_api_gateway_resource.this[0].path : null
}
