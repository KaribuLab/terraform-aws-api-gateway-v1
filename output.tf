# ============================================================================
# Outputs del API Gateway
# ============================================================================

output "rest_api_id" {
  description = "ID del API Gateway REST API."
  value       = aws_api_gateway_rest_api.this.id
}

output "rest_api_root_resource_id" {
  description = "ID del recurso raíz del API Gateway."
  value       = aws_api_gateway_rest_api.this.root_resource_id
}

output "rest_api_execution_arn" {
  description = "ARN de ejecución del API Gateway (útil para permisos Lambda)."
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "openapi_spec_sha" {
  description = "Hash SHA1 del spec OpenAPI. Útil como trigger de redeploy en submódulos stage externos."
  value       = local.openapi_spec_sha
}

# ============================================================================
# Outputs del Stage y Deployment (via module stage)
# ============================================================================

output "deployment_id" {
  description = "ID del deployment creado (solo si create_stage es true)."
  value       = var.create_stage ? module.stage[0].deployment_id : null
}

output "stage_name" {
  description = "Nombre del stage (solo si create_stage es true)."
  value       = var.create_stage ? module.stage[0].stage_name : null
}

output "stage_arn" {
  description = "ARN del stage (solo si create_stage es true)."
  value       = var.create_stage ? module.stage[0].stage_arn : null
}

output "stage_invoke_url" {
  description = "URL de invocación del stage (solo si create_stage es true)."
  value       = var.create_stage ? module.stage[0].stage_invoke_url : null
}

output "stage_execution_arn" {
  description = "ARN de ejecución del stage (solo si create_stage es true)."
  value       = var.create_stage ? module.stage[0].stage_execution_arn : null
}

# ============================================================================
# Outputs de API Key y Usage Plan (via module stage)
# ============================================================================

output "api_key_id" {
  description = "ID de la API Key (solo si enable_api_key es true y create_stage es true)."
  value       = var.create_stage && var.enable_api_key ? module.stage[0].api_key_id : null
}

output "api_key_value" {
  description = "Valor de la API Key (solo si enable_api_key es true y create_stage es true)."
  value       = var.create_stage && var.enable_api_key ? module.stage[0].api_key_value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID del Usage Plan (solo si enable_api_key, usage_plan_config y create_stage están configurados)."
  value       = var.create_stage && var.enable_api_key && var.usage_plan_config != null ? module.stage[0].usage_plan_id : null
}

output "waf_web_acl_association_id" {
  description = "ID de la asociación WAFv2 con el stage (solo si waf_web_acl_arn está configurado y create_stage es true)."
  value       = var.create_stage && var.waf_web_acl_arn != null ? module.stage[0].waf_web_acl_association_id : null
}
