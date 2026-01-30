# Submódulo Stage para API Gateway

Este submódulo facilita la creación y gestión de stages y deployments de API Gateway, incluyendo configuración de cache, throttling, logging y X-Ray tracing.

## Características

- Creación de deployment y stage
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

## Variables

### Requeridas

- `rest_api_id`: ID del REST API de API Gateway
- `stage_name`: Nombre del stage (ej: 'dev', 'staging', 'prod')

### Opcionales

- `stage_description`: Descripción del stage - Default: `null`
- `deployment_description`: Descripción del deployment - Default: `"Managed by Terraform"`
- `deployment_triggers`: Map de triggers para forzar nuevo deployment - Default: `{}`
- `stage_variables`: Variables del stage (key-value pairs) - Default: `{}`
- `cache_cluster_enabled`: Habilitar cache cluster - Default: `false`
- `cache_cluster_size`: Tamaño del cache (0.5, 1.6, 6.1, 13.5, 28.4, 58.2, 118, 237 GB) - Default: `"0.5"`
- `xray_tracing_enabled`: Habilitar AWS X-Ray tracing - Default: `false`
- `access_log_settings`: Configuración de access logs - Default: `null`
- `method_settings`: Configuración de settings por método (cache, throttling, logs) - Default: `{}`
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
- `deployment_invoke_url`: URL de invocación del deployment
- `stage_id`: ID del stage
- `stage_name`: Nombre del stage
- `stage_arn`: ARN del stage
- `invoke_url`: URL de invocación del stage
- `execution_arn`: ARN de ejecución del stage (para permisos Lambda)

## Notas importantes

- **Nuevos deployments**: Cuando cambias `deployment_triggers`, Terraform crea un nuevo deployment y actualiza el stage para apuntar a él
- **Deployments antiguos**: Los deployments anteriores no se eliminan automáticamente (mantiene historial)
- **Múltiples stages**: Puedes tener múltiples stages (dev, staging, prod) apuntando al mismo API
- **Throttling**: Se configura a nivel de stage usando `method_settings`, no a nivel de API
- **Cache**: Puede estar habilitado a nivel de stage (cache cluster) y/o por método (usando `method_settings`)
