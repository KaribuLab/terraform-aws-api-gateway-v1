# Crear deployment
# Usamos create_before_destroy = true para permitir actualizaciones sin downtime.
# El nuevo deployment se crea primero, luego el stage se actualiza para apuntar
# al nuevo deployment, y finalmente el deployment viejo se destruye.
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = var.rest_api_id
  description = var.deployment_description

  # Triggers para forzar nuevo deployment cuando cambien recursos
  triggers = var.deployment_triggers

  lifecycle {
    create_before_destroy = true
  }
}

# Crear o actualizar stage
resource "aws_api_gateway_stage" "this" {
  rest_api_id   = var.rest_api_id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
  description   = var.stage_description

  # Variables de stage
  variables = var.stage_variables

  # Cache configuration
  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_enabled ? var.cache_cluster_size : null

  # X-Ray tracing
  xray_tracing_enabled = var.xray_tracing_enabled

  # Access logging
  dynamic "access_log_settings" {
    for_each = var.access_log_settings != null ? [1] : []
    content {
      destination_arn = var.access_log_settings.destination_arn
      format          = var.access_log_settings.format
    }
  }

  tags = var.tags
}

# Method settings (cache, throttling por método)
resource "aws_api_gateway_method_settings" "this" {
  for_each = var.method_settings

  rest_api_id = var.rest_api_id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = each.key

  settings {
    metrics_enabled        = try(each.value.metrics_enabled, false)
    logging_level          = try(each.value.logging_level, "OFF")
    data_trace_enabled     = try(each.value.data_trace_enabled, false)
    throttling_burst_limit = try(each.value.throttling_burst_limit, -1)
    throttling_rate_limit  = try(each.value.throttling_rate_limit, -1)
    caching_enabled        = try(each.value.caching_enabled, false)
    cache_ttl_in_seconds   = try(each.value.cache_ttl_in_seconds, 300)
    cache_data_encrypted   = try(each.value.cache_data_encrypted, false)
  }
}
