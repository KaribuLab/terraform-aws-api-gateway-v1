output "deployment_id" {
  description = "ID del deployment creado"
  value       = aws_api_gateway_deployment.this.id
}

output "stage_id" {
  description = "ID del stage"
  value       = aws_api_gateway_stage.this.id
}

output "stage_name" {
  description = "Nombre del stage"
  value       = aws_api_gateway_stage.this.stage_name
}

output "stage_arn" {
  description = "ARN del stage"
  value       = aws_api_gateway_stage.this.arn
}

output "invoke_url" {
  description = "URL de invocación del stage"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "execution_arn" {
  description = "ARN de ejecución del stage (para permisos Lambda)"
  value       = aws_api_gateway_stage.this.execution_arn
}
