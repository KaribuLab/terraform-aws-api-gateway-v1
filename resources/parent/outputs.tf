output "resource_id" {
  description = "ID del recurso de API Gateway creado"
  value       = aws_api_gateway_resource.this.id
}

output "resource_path" {
  description = "Path completo del recurso"
  value       = aws_api_gateway_resource.this.path
}

output "path_part" {
  description = "Parte del path del recurso"
  value       = aws_api_gateway_resource.this.path_part
}
