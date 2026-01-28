output "rest_api_id" {
  description = "Identifier of the API Gateway."
  value       = aws_api_gateway_rest_api.this.id
}

output "rest_api_root_resource_id" {
  description = "Root resource ID for the API Gateway."
  value       = aws_api_gateway_rest_api.this.root_resource_id
}

output "rest_api_execution_arn" {
  description = "Execution ARN of the API Gateway (useful for Lambda permissions)."
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "stage_name" {
  description = "Nombre del stage creado por el módulo (null si el usuario crea el stage externamente)."
  value       = var.stage_config != null ? aws_api_gateway_stage.this[0].stage_name : null
}

output "stage_arn" {
  description = "ARN del stage creado por el módulo (null si el usuario crea el stage externamente)."
  value       = var.stage_config != null ? aws_api_gateway_stage.this[0].arn : null
}

output "invoke_url" {
  description = "URL de invocación del stage (null si el usuario crea el stage externamente)."
  value       = var.stage_config != null ? aws_api_gateway_stage.this[0].invoke_url : null
}

# ============================================================================
# Outputs opcionales para autenticación
# ============================================================================

output "api_key_id" {
  description = "ID de la API Key creada (solo si enable_api_key es true)."
  value       = var.enable_api_key ? aws_api_gateway_api_key.this[0].id : null
}

output "api_key_value" {
  description = "Valor de la API Key creada (solo si enable_api_key es true). Solo disponible después del primer apply."
  value       = var.enable_api_key ? aws_api_gateway_api_key.this[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID del Usage Plan creado (solo si enable_api_key y usage_plan_config están configurados)."
  value       = var.enable_api_key && var.usage_plan_config != null ? aws_api_gateway_usage_plan.this[0].id : null
}

output "authorizer_id" {
  description = "ID del Lambda Authorizer creado (solo si authorizer_config está definido)."
  value       = var.authorizer_config != null ? aws_api_gateway_authorizer.this[0].id : null
}

