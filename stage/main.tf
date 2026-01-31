# Detectar si el stage existe
data "external" "check_stage" {
  count   = var.auto_detect_existing_stage ? 1 : 0
  program = ["bash", "${path.module}/scripts/check_stage.sh"]
  query = {
    rest_api_id = var.rest_api_id
    stage_name  = var.stage_name
    region      = var.aws_region
  }
}

locals {
  stage_exists = var.auto_detect_existing_stage ? (
    try(data.external.check_stage[0].result.exists, "false") == "true"
  ) : false
  
  # Determinar si se debe crear API Key
  create_api_key = var.api_key_config != null && var.api_key_id == null
  
  # Determinar si se debe crear Usage Plan
  create_usage_plan = var.usage_plan_config != null && (var.api_key_id != null || var.api_key_config != null)
  
  # ID de la API Key a usar (creada o existente)
  api_key_id = local.create_api_key ? aws_api_gateway_api_key.this[0].id : var.api_key_id
}

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

# Crear stage solo si NO existe
resource "aws_api_gateway_stage" "this" {
  count = local.stage_exists ? 0 : 1

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

# Actualizar stage existente con nuevo deployment
resource "null_resource" "update_existing_stage" {
  count = local.stage_exists ? 1 : 0

  triggers = {
    deployment_id = aws_api_gateway_deployment.this.id
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/update_stage.sh ${var.rest_api_id} ${var.stage_name} ${aws_api_gateway_deployment.this.id} ${var.aws_region}"
  }
}

# Method settings (cache, throttling por método)
# Solo se crean si el stage fue creado por este módulo (no si ya existía)
resource "aws_api_gateway_method_settings" "this" {
  for_each = local.stage_exists ? {} : var.method_settings

  rest_api_id = var.rest_api_id
  stage_name  = aws_api_gateway_stage.this[0].stage_name
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

# ============================================================================
# API Key y Usage Plan
# ============================================================================

# Crear API Key si se configura
resource "aws_api_gateway_api_key" "this" {
  count = local.create_api_key ? 1 : 0

  name        = var.api_key_config.name
  description = var.api_key_config.description
  enabled     = var.api_key_config.enabled
  tags        = var.tags
}

# Crear Usage Plan
resource "aws_api_gateway_usage_plan" "this" {
  count = local.create_usage_plan ? 1 : 0

  name        = var.usage_plan_config.name
  description = var.usage_plan_config.description

  dynamic "quota_settings" {
    for_each = var.usage_plan_config.quota_settings != null ? [1] : []
    content {
      limit  = var.usage_plan_config.quota_settings.limit
      period = var.usage_plan_config.quota_settings.period
    }
  }

  dynamic "throttle_settings" {
    for_each = var.usage_plan_config.throttle_settings != null ? [1] : []
    content {
      burst_limit = var.usage_plan_config.throttle_settings.burst_limit
      rate_limit  = var.usage_plan_config.throttle_settings.rate_limit
    }
  }

  # Asociar el stage al Usage Plan
  api_stages {
    api_id = var.rest_api_id
    stage  = var.stage_name
  }

  tags = var.tags

  # Depende del stage (creado o actualizado)
  depends_on = [
    aws_api_gateway_stage.this,
    null_resource.update_existing_stage
  ]
}

# Asociar API Key al Usage Plan
resource "aws_api_gateway_usage_plan_key" "this" {
  count = local.create_usage_plan ? 1 : 0

  key_id        = local.api_key_id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this[0].id
}
