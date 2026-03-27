# ============================================================================
# Outputs del submódulo Stage
# ============================================================================

output "deployment_id" {
  description = "ID del deployment creado."
  value       = aws_api_gateway_deployment.this.id
}

output "stage_name" {
  description = "Nombre del stage."
  value       = aws_api_gateway_stage.this.stage_name
}

output "stage_arn" {
  description = "ARN del stage."
  value       = aws_api_gateway_stage.this.arn
}

output "stage_invoke_url" {
  description = "URL de invocación del stage."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "stage_execution_arn" {
  description = "ARN de ejecución del stage."
  value       = aws_api_gateway_stage.this.execution_arn
}

output "api_key_id" {
  description = "ID de la API Key (solo si api_key_config está configurado)."
  value       = local.enable_api_key ? aws_api_gateway_api_key.this[0].id : null
}

output "api_key_value" {
  description = "Valor de la API Key (solo si api_key_config está configurado)."
  value       = local.enable_api_key ? aws_api_gateway_api_key.this[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID del Usage Plan (solo si api_key_config y usage_plan están configurados)."
  value       = try(var.api_key_config.usage_plan, null) != null ? aws_api_gateway_usage_plan.this[0].id : null
}

output "waf_web_acl_association_id" {
  description = "ID de la asociación WAFv2 con el stage (solo si waf_web_acl_arn está configurado)."
  value       = var.waf_web_acl_arn != null ? aws_wafv2_web_acl_association.this[0].id : null
}
