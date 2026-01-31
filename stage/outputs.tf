output "deployment_id" {
  description = "ID del deployment creado"
  value       = aws_api_gateway_deployment.this.id
}

output "stage_exists" {
  description = "Indica si el stage ya existía (no fue creado por este módulo)"
  value       = local.stage_exists
}

output "stage_id" {
  description = "ID del stage (solo disponible si fue creado por este módulo)"
  value       = local.stage_exists ? null : try(aws_api_gateway_stage.this[0].id, null)
}

output "stage_name" {
  description = "Nombre del stage"
  value       = var.stage_name
}

output "stage_arn" {
  description = "ARN del stage (solo disponible si fue creado por este módulo)"
  value       = local.stage_exists ? null : try(aws_api_gateway_stage.this[0].arn, null)
}

output "invoke_url" {
  description = "URL de invocación del stage (solo disponible si fue creado por este módulo)"
  value       = local.stage_exists ? null : try(aws_api_gateway_stage.this[0].invoke_url, null)
}

output "execution_arn" {
  description = "ARN de ejecución del stage para permisos Lambda (solo disponible si fue creado por este módulo)"
  value       = local.stage_exists ? null : try(aws_api_gateway_stage.this[0].execution_arn, null)
}

# ============================================================================
# Outputs de API Key
# ============================================================================

output "api_key_id" {
  description = "ID de la API Key (creada o proporcionada)"
  value       = local.api_key_id
}

output "api_key_value" {
  description = "Valor de la API Key (solo si fue creada por este módulo)"
  value       = local.create_api_key ? aws_api_gateway_api_key.this[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID del Usage Plan"
  value       = local.create_usage_plan ? aws_api_gateway_usage_plan.this[0].id : null
}
