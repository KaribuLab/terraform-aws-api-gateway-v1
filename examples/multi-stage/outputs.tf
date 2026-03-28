# ============================================================================
# API Gateway REST API
# ============================================================================

output "rest_api_id" {
  description = "ID del API Gateway REST API."
  value       = module.api_gateway.rest_api_id
}

# ============================================================================
# Stage "dev"
# ============================================================================

output "dev_stage_name" {
  description = "Nombre del stage de desarrollo."
  value       = module.stage_dev.stage_name
}

output "dev_stage_invoke_url" {
  description = "URL de invocacion del stage de desarrollo."
  value       = module.stage_dev.stage_invoke_url
}

# ============================================================================
# Stage "staging"
# ============================================================================

output "staging_stage_name" {
  description = "Nombre del stage de staging."
  value       = module.stage_staging.stage_name
}

output "staging_stage_invoke_url" {
  description = "URL de invocacion del stage de staging."
  value       = module.stage_staging.stage_invoke_url
}
