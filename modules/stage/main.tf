terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "<= 6.7.0"
    }
  }
}

# ============================================================================
# Deployment
# ============================================================================

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = var.rest_api_id

  triggers = {
    redeployment = var.openapi_spec_sha
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Stage
# ============================================================================

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = var.rest_api_id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
  description   = var.stage_description

  variables = var.stage_variables

  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_enabled ? var.cache_cluster_size : null

  xray_tracing_enabled = var.xray_tracing_enabled

  dynamic "access_log_settings" {
    for_each = var.access_log_settings != null ? [1] : []
    content {
      destination_arn = var.access_log_settings.destination_arn
      format          = var.access_log_settings.format
    }
  }

  tags = var.tags
}

# ============================================================================
# WAFv2 association (opcional)
# ============================================================================

resource "aws_wafv2_web_acl_association" "this" {
  count = var.waf_web_acl_arn != null ? 1 : 0

  resource_arn = aws_api_gateway_stage.this.arn
  web_acl_arn  = var.waf_web_acl_arn

  lifecycle {
    precondition {
      condition     = upper(var.endpoint_type) == "REGIONAL"
      error_message = "waf_web_acl_arn solo es compatible cuando endpoint_type es REGIONAL."
    }
  }
}

# ============================================================================
# Method Settings (cache, throttling, logs por método)
# ============================================================================

resource "aws_api_gateway_method_settings" "this" {
  for_each = var.method_settings

  rest_api_id = var.rest_api_id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = each.key

  settings {
    metrics_enabled        = each.value.metrics_enabled
    logging_level          = each.value.logging_level
    data_trace_enabled     = each.value.data_trace_enabled
    throttling_burst_limit = each.value.throttling_burst_limit
    throttling_rate_limit  = each.value.throttling_rate_limit
    caching_enabled        = each.value.caching_enabled
    cache_ttl_in_seconds   = each.value.cache_ttl_in_seconds
    cache_data_encrypted   = each.value.cache_data_encrypted
  }
}

# ============================================================================
# API Key y Usage Plan (opcional)
# ============================================================================

locals {
  enable_api_key = var.api_key_config != null
}

resource "aws_api_gateway_api_key" "this" {
  count = local.enable_api_key ? 1 : 0

  name        = try(var.api_key_config.name, null) != null ? var.api_key_config.name : "${var.stage_name}-api-key"
  description = try(var.api_key_config.description, "API Key managed by Terraform")
  enabled     = true
  tags        = var.tags
}

resource "aws_api_gateway_usage_plan" "this" {
  count = try(var.api_key_config.usage_plan, null) != null ? 1 : 0

  name        = var.api_key_config.usage_plan.name
  description = var.api_key_config.usage_plan.description

  dynamic "quota_settings" {
    for_each = try(var.api_key_config.usage_plan.quota_settings, null) != null ? [1] : []
    content {
      limit  = var.api_key_config.usage_plan.quota_settings.limit
      period = var.api_key_config.usage_plan.quota_settings.period
    }
  }

  dynamic "throttle_settings" {
    for_each = try(var.api_key_config.usage_plan.throttle_settings, null) != null ? [1] : []
    content {
      burst_limit = var.api_key_config.usage_plan.throttle_settings.burst_limit
      rate_limit  = var.api_key_config.usage_plan.throttle_settings.rate_limit
    }
  }

  api_stages {
    api_id = var.rest_api_id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  tags = var.tags
}

resource "aws_api_gateway_usage_plan_key" "this" {
  count = try(var.api_key_config.usage_plan, null) != null ? 1 : 0

  key_id        = aws_api_gateway_api_key.this[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this[0].id
}
