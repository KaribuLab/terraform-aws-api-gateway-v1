# Submódulo Stage para API Gateway

Este submódulo facilita la creación y gestión de stages y deployments de API Gateway, incluyendo configuración de cache, throttling, logging y X-Ray tracing.

## Características

- Creación de deployment y stage
- **Detección automática de stages existentes**: Si el stage ya existe en AWS, solo crea el deployment y actualiza el stage existente
- **Soporte para API Keys**: Crear API Keys y Usage Plans asociados al stage
- Configuración de cache cluster a nivel de stage
- Throttling y cache por método (usando `method_settings`)
- AWS X-Ray tracing
- Access logging configurable
- Variables de stage
- Soporte para múltiples deployments sobre el mismo stage

## Uso básico

```hcl
# Módulo principal crea el API
module "api_gateway" {
  source = "./terraform-aws-api-gateway-v1"
  
  api_name   = "my-api"
  aws_region = "us-east-1"
}

# Crear recursos, métodos, etc.
resource "aws_api_gateway_resource" "users" {
  rest_api_id = module.api_gateway.rest_api_id
  parent_id   = module.api_gateway.rest_api_root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_method" "users_get" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.users.id
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_get" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.users_get.http_method
  type        = "MOCK"
}

# Crear stage con deployment
module "stage_dev" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "dev"
  aws_region  = "us-east-1"
  
  # Triggers para crear nuevo deployment cuando cambien recursos
  deployment_triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.users.id,
      aws_api_gateway_method.users_get.id,
      aws_api_gateway_integration.users_get.id,
    ]))
  }
}
```

## Actualizar deployment (crear uno nuevo)

Cuando cambias recursos/métodos, simplemente actualiza los `deployment_triggers`:

```hcl
module "stage_dev" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "dev"
  
  deployment_triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.users.id,
      aws_api_gateway_resource.products.id,  # Nuevo recurso
      aws_api_gateway_method.users_get.id,
      aws_api_gateway_integration.users_get.id,
      # ... otros recursos
    ]))
  }
}
```

Terraform creará un nuevo deployment y actualizará el stage para apuntar a él automáticamente.

## Con cache y throttling

```hcl
module "stage_prod" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "prod"
  
  # Cache cluster a nivel de stage
  cache_cluster_enabled = true
  cache_cluster_size    = "1.6"
  
  # Throttling y cache por método
  method_settings = {
    "*/*" = {
      metrics_enabled        = true
      logging_level          = "INFO"
      caching_enabled        = true
      cache_ttl_in_seconds   = 300
      throttling_burst_limit = 5000
      throttling_rate_limit  = 10000
    }
    "users/GET" = {
      caching_enabled      = true
      cache_ttl_in_seconds = 600
      throttling_burst_limit = 100
      throttling_rate_limit  = 50
    }
  }
  
  deployment_triggers = {
    redeployment = sha1(jsonencode([
      # ... recursos
    ]))
  }
}
```

## Con X-Ray tracing y access logs

```hcl
module "stage_prod" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "prod"
  
  # X-Ray tracing
  xray_tracing_enabled = true
  
  # Access logs
  access_log_settings = {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      caller        = "$context.identity.caller"
      user          = "$context.identity.user"
      requestTime   = "$context.requestTime"
      httpMethod    = "$context.httpMethod"
      resourcePath  = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
  
  deployment_triggers = {
    redeployment = sha1(jsonencode([...]))
  }
}
```

## Variables de stage

```hcl
module "stage_dev" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "dev"
  
  # Variables del stage (disponibles en las integraciones)
  stage_variables = {
    lambda_function_name = "my-function-dev"
    api_version          = "v1"
  }
  
  deployment_triggers = {
    redeployment = sha1(jsonencode([...]))
  }
}
```

## Con API Key

### Crear nueva API Key

```hcl
module "stage_prod" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "prod"
  aws_region  = "us-east-1"
  
  # Crear API Key nueva
  api_key_config = {
    name        = "my-api-key"
    description = "API Key para producción"
  }
  
  # Configurar Usage Plan (requerido)
  usage_plan_config = {
    name = "prod-usage-plan"
    throttle_settings = {
      burst_limit = 100
      rate_limit  = 50
    }
  }
  
  deployment_triggers = {
    redeployment = sha1(jsonencode([...]))
  }
}

# Obtener el valor de la API Key
output "api_key" {
  value     = module.stage_prod.api_key_value
  sensitive = true
}
```

### Usar API Key existente

```hcl
module "stage_prod" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "prod"
  aws_region  = "us-east-1"
  
  # Usar API Key existente del módulo principal
  api_key_id = module.api_gateway.api_key_id
  
  # Configurar Usage Plan (requerido)
  usage_plan_config = {
    name = "prod-usage-plan"
    quota_settings = {
      limit  = 10000
      period = "DAY"
    }
    throttle_settings = {
      burst_limit = 200
      rate_limit  = 100
    }
  }
  
  deployment_triggers = {
    redeployment = sha1(jsonencode([...]))
  }
}
```

**Importante**: Para que la API Key funcione, también debes configurar `api_key_required = true` en tus métodos:

```hcl
resource "aws_api_gateway_method" "users_get" {
  rest_api_id   = module.api_gateway.rest_api_id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true  # Requerir API Key
}
```

## Múltiples stages

Puedes crear múltiples stages para el mismo API:

```hcl
# Stage de desarrollo
module "stage_dev" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "dev"
  # ...
}

# Stage de producción
module "stage_prod" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = "prod"
  cache_cluster_enabled = true
  cache_cluster_size    = "6.1"
  # ...
}
```

## Detección Automática de Stage Existente

**Por defecto**, el módulo detecta automáticamente si el stage ya existe en AWS (`auto_detect_existing_stage = true`):

- **Si el stage existe**: Solo crea el deployment y actualiza el stage existente para usar el nuevo deployment via AWS CLI
- **Si el stage NO existe**: Crea tanto el deployment como el stage via AWS CLI

Este comportamiento evita conflictos si el stage ya existe y hace que el módulo sea más robusto.

Para deshabilitar la detección automática y que Terraform gestione el stage directamente:

```hcl
module "stage_dev" {
  source = "./terraform-aws-api-gateway-v1/stage"
  
  rest_api_id              = module.api_gateway.rest_api_id
  stage_name               = "dev"
  aws_region               = "us-east-1"
  auto_detect_existing_stage = false  # Terraform gestiona el stage directamente
  
  deployment_triggers = {
    redeployment = sha1(jsonencode([...]))
  }
}
```

**Nota importante**: Cuando `auto_detect_existing_stage = true` (por defecto):
- El stage se crea/actualiza via AWS CLI (no está completamente gestionado por Terraform)
- Los `method_settings` no se aplicarán (solo funcionan si el stage es creado por Terraform con `auto_detect_existing_stage = false`)
- Los outputs relacionados con el stage (`stage_id`, `stage_arn`, `invoke_url`, `execution_arn`) pueden ser `null` o limitados

Si necesitas usar `method_settings` o necesitas que Terraform gestione completamente el stage, configura `auto_detect_existing_stage = false`.

## Variables

### Requeridas

- `rest_api_id`: ID del REST API de API Gateway
- `stage_name`: Nombre del stage (ej: 'dev', 'staging', 'prod')
- `aws_region`: Región de AWS para la verificación del stage

### Opcionales

- `auto_detect_existing_stage`: Detectar automáticamente si el stage existe (por defecto habilitado para evitar conflictos) - Default: `true`
- `stage_description`: Descripción del stage - Default: `null`
- `deployment_description`: Descripción del deployment - Default: `"Managed by Terraform"`
- `deployment_triggers`: Map de triggers para forzar nuevo deployment - Default: `{}`
- `stage_variables`: Variables del stage (key-value pairs) - Default: `{}`
- `cache_cluster_enabled`: Habilitar cache cluster - Default: `false`
- `cache_cluster_size`: Tamaño del cache (0.5, 1.6, 6.1, 13.5, 28.4, 58.2, 118, 237 GB) - Default: `"0.5"`
- `xray_tracing_enabled`: Habilitar AWS X-Ray tracing - Default: `false`
- `access_log_settings`: Configuración de access logs - Default: `null`
- `method_settings`: Configuración de settings por método (cache, throttling, logs) - Default: `{}`
- `api_key_id`: ID de una API Key existente para asociar al Usage Plan - Default: `null`
- `api_key_config`: Configuración para crear una nueva API Key - Default: `null`
- `usage_plan_config`: Configuración del Usage Plan (requerido si se usa API Key) - Default: `null`
- `tags`: Tags para los recursos - Default: `{}`

### method_settings

El formato de `method_settings` es un map donde:
- **Key**: Path del método (ej: `"*/*"` para todos, `"users/GET"` para específico)
- **Value**: Objeto con configuración:
  - `metrics_enabled`: Habilitar métricas CloudWatch - Default: `false`
  - `logging_level`: Nivel de logging (OFF, ERROR, INFO) - Default: `"OFF"`
  - `data_trace_enabled`: Habilitar data trace - Default: `false`
  - `throttling_burst_limit`: Límite de burst - Default: `-1` (sin límite)
  - `throttling_rate_limit`: Límite de rate - Default: `-1` (sin límite)
  - `caching_enabled`: Habilitar cache - Default: `false`
  - `cache_ttl_in_seconds`: TTL del cache en segundos - Default: `300`
  - `cache_data_encrypted`: Encriptar datos del cache - Default: `false`

## Outputs

- `deployment_id`: ID del deployment creado
- `stage_exists`: Indica si el stage ya existía (no fue creado por este módulo)
- `stage_id`: ID del stage (solo disponible si fue creado por este módulo, `null` si ya existía)
- `stage_name`: Nombre del stage
- `stage_arn`: ARN del stage (solo disponible si fue creado por este módulo, `null` si ya existía)
- `invoke_url`: URL de invocación del stage (solo disponible si fue creado por este módulo, `null` si ya existía)
- `execution_arn`: ARN de ejecución del stage para permisos Lambda (solo disponible si fue creado por este módulo, `null` si ya existía)
- `api_key_id`: ID de la API Key (creada o proporcionada)
- `api_key_value`: Valor de la API Key (solo si fue creada por este módulo, `null` si se usó una existente)
- `usage_plan_id`: ID del Usage Plan

## Requisitos Previos

Para usar la detección automática de stages existentes, necesitas:

- **AWS CLI** instalado y configurado con credenciales válidas
- **jq** instalado (para parsear JSON en los scripts)
- Permisos IAM: `apigateway:GetStage`, `apigateway:UpdateStage`

## Notas importantes

- **Detección automática**: Por defecto (`auto_detect_existing_stage = true`), el módulo detecta si el stage existe antes de crearlo. Si existe, solo crea el deployment y actualiza el stage existente via AWS CLI. Si no existe, crea el stage también via AWS CLI
- **Nuevos deployments**: Cuando cambias `deployment_triggers`, Terraform crea un nuevo deployment y actualiza el stage para apuntar a él
- **Deployments antiguos**: Los deployments anteriores no se eliminan automáticamente (mantiene historial)
- **Múltiples stages**: Puedes tener múltiples stages (dev, staging, prod) apuntando al mismo API
- **Throttling**: Se configura a nivel de stage usando `method_settings`, no a nivel de API. Solo funciona si el stage es creado por Terraform
- **Cache**: Puede estar habilitado a nivel de stage (cache cluster) y/o por método (usando `method_settings`)
- **Stage existente**: Si el stage ya existe y se detecta automáticamente, los `method_settings` no se aplicarán y algunos outputs serán `null`
- **API Keys**: El `usage_plan_config` es requerido si configuras `api_key_config` o `api_key_id`. El Usage Plan se asocia automáticamente al stage creado o existente
- **API Key requerida**: Para que la API Key funcione, debes configurar `api_key_required = true` en tus métodos de API Gateway
