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

# ============================================================================
# Outputs del Stage y Deployment
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

# ============================================================================
# Outputs de Recursos generados
# ============================================================================

output "resources" {
  description = "Mapa de recursos creados (path -> resource_id)."
  value = {
    for path, resource in aws_api_gateway_resource.this :
    path => resource.id
  }
}

output "methods" {
  description = "Mapa de métodos creados (path#method -> method_id)."
  value = {
    for key, method in aws_api_gateway_method.this :
    key => method.id
  }
}

# ============================================================================
# Outputs de Authorizers
# ============================================================================

output "authorizers" {
  description = "Mapa de authorizers creados (key -> authorizer_id)."
  value = {
    for key, authorizer in aws_api_gateway_authorizer.this :
    key => authorizer.id
  }
}

# ============================================================================
# Outputs de API Key y Usage Plan
# ============================================================================

output "api_key_id" {
  description = "ID de la API Key (solo si enable_api_key es true)."
  value       = var.enable_api_key ? aws_api_gateway_api_key.this[0].id : null
}

output "api_key_value" {
  description = "Valor de la API Key (solo si enable_api_key es true)."
  value       = var.enable_api_key ? aws_api_gateway_api_key.this[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID del Usage Plan (solo si enable_api_key y usage_plan_config están configurados)."
  value       = var.enable_api_key && var.usage_plan_config != null ? aws_api_gateway_usage_plan.this[0].id : null
}
