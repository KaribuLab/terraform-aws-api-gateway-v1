# Terraform AWS API Gateway v1 Module

Módulo de Terraform para crear y gestionar API Gateway REST API v1 en AWS con integraciones Lambda declarativas.

## Características

- **Interfaz declarativa**: Define todos tus endpoints Lambda en una sola variable
- **Gestión automática de recursos**: Crea automáticamente la jerarquía de paths necesaria
- **Deployment y Stage integrados**: No necesitas gestionar deployments manualmente
- **Lambda Authorizers**: Soporte completo para authorizers personalizados
- **CORS automático**: Habilita CORS por endpoint con configuración simple
- **API Key y Usage Plans**: Autenticación opcional con límites de uso
- **Method Settings**: Configuración de cache, throttling y logs por método

## Requisitos

- Terraform >= 1.0
- AWS Provider >= 5.0
- Credenciales AWS configuradas
- Permisos IAM necesarios para crear recursos de API Gateway y Lambda

## Uso Básico

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-api"
  stage_name = "prod"

  lambda_integrations = [
    {
      path                = "/users"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.get_users.invoke_arn
      lambda_function_arn = aws_lambda_function.get_users.arn
    },
    {
      path                = "/users"
      method              = "POST"
      lambda_invoke_arn   = aws_lambda_function.create_user.invoke_arn
      lambda_function_arn = aws_lambda_function.create_user.arn
      enable_cors         = true
    },
    {
      path                = "/users/{id}"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.get_user.invoke_arn
      lambda_function_arn = aws_lambda_function.get_user.arn
      request_parameters  = {
        "method.request.path.id" = true
      }
    }
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Ejemplos Avanzados

### Con Lambda Authorizer

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-secure-api"
  stage_name = "prod"

  # Definir authorizers
  authorizers = {
    jwt_auth = {
      lambda_arn      = aws_lambda_function.authorizer.arn
      type            = "TOKEN"
      identity_source = "method.request.header.Authorization"
    }
  }

  # Usar authorizer en endpoints
  lambda_integrations = [
    {
      path                = "/profile"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.get_profile.invoke_arn
      lambda_function_arn = aws_lambda_function.get_profile.arn
      authorization_type  = "CUSTOM"
      authorizer_key      = "jwt_auth"
    }
  ]
}
```

### Con API Key y Usage Plan

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-api"
  stage_name = "prod"

  lambda_integrations = [
    {
      path                = "/data"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.get_data.invoke_arn
      lambda_function_arn = aws_lambda_function.get_data.arn
      api_key_required    = true
    }
  ]

  # Habilitar API Key
  enable_api_key = true
  api_key_name   = "my-api-key"

  usage_plan_config = {
    name        = "standard-plan"
    description = "Standard usage plan"
    throttle_settings = {
      burst_limit = 100
      rate_limit  = 50
    }
    quota_settings = {
      limit  = 10000
      period = "DAY"
    }
  }
}
```

### Con CORS y múltiples métodos

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-api"
  stage_name = "prod"

  lambda_integrations = [
    {
      path                = "/items"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.list_items.invoke_arn
      lambda_function_arn = aws_lambda_function.list_items.arn
      enable_cors         = true
      cors_allow_origin   = "'https://example.com'"
    },
    {
      path                = "/items"
      method              = "POST"
      lambda_invoke_arn   = aws_lambda_function.create_item.invoke_arn
      lambda_function_arn = aws_lambda_function.create_item.arn
      enable_cors         = true
      cors_allow_origin   = "'https://example.com'"
    },
    {
      path                = "/items/{id}"
      method              = "PUT"
      lambda_invoke_arn   = aws_lambda_function.update_item.invoke_arn
      lambda_function_arn = aws_lambda_function.update_item.arn
      enable_cors         = true
      cors_allow_origin   = "'https://example.com'"
    }
  ]
}
```

### Con Cache y Throttling

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-api"
  stage_name = "prod"

  lambda_integrations = [
    {
      path                = "/products"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.get_products.invoke_arn
      lambda_function_arn = aws_lambda_function.get_products.arn
    }
  ]

  # Habilitar cache a nivel de stage
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  # Configurar cache y throttling por método
  method_settings = {
    "products/GET" = {
      caching_enabled        = true
      cache_ttl_in_seconds   = 300
      throttling_burst_limit = 100
      throttling_rate_limit  = 50
      metrics_enabled        = true
      logging_level          = "INFO"
    }
  }
}
```

## Variables

### Variables Principales

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `aws_region` | `string` | - | Región de AWS (requerido) |
| `api_name` | `string` | - | Nombre del API Gateway (requerido) |
| `api_description` | `string` | `"API Gateway managed by Terraform"` | Descripción del API |
| `stage_name` | `string` | - | Nombre del stage (requerido) |
| `tags` | `map(string)` | `{}` | Tags para todos los recursos |

### Lambda Integrations

| Campo | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `path` | `string` | - | Ruta del endpoint (ej: `/users`, `/profile/{id}`) |
| `method` | `string` | - | Método HTTP (GET, POST, PUT, DELETE, etc.) |
| `lambda_invoke_arn` | `string` | - | ARN de invocación de Lambda |
| `lambda_function_arn` | `string` | - | ARN de la función Lambda |
| `authorization_type` | `string` | `"NONE"` | Tipo de autorización (NONE, AWS_IAM, CUSTOM) |
| `authorizer_key` | `string` | `null` | Clave del authorizer (requerido si `authorization_type = "CUSTOM"`) |
| `api_key_required` | `bool` | `false` | Si requiere API Key |
| `request_parameters` | `map(bool)` | `{}` | Parámetros de request |
| `enable_cors` | `bool` | `false` | Habilitar CORS |
| `cors_allow_origin` | `string` | `"'*'"` | Valor de Access-Control-Allow-Origin |

### Authorizers

| Campo | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `lambda_arn` | `string` | - | ARN de la función Lambda authorizer |
| `type` | `string` | `"TOKEN"` | Tipo de authorizer (TOKEN o REQUEST) |
| `identity_source` | `string` | `"method.request.header.Authorization"` | Fuente de identidad |
| `authorizer_result_ttl` | `number` | `300` | TTL del resultado en segundos |
| `identity_validation_expression` | `string` | `null` | Expresión regex de validación |

### Stage Configuration

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `stage_description` | `string` | `"Stage managed by Terraform"` | Descripción del stage |
| `stage_variables` | `map(string)` | `{}` | Variables del stage |
| `cache_cluster_enabled` | `bool` | `false` | Habilitar cache cluster |
| `cache_cluster_size` | `string` | `"0.5"` | Tamaño del cache (GB) |
| `xray_tracing_enabled` | `bool` | `false` | Habilitar X-Ray tracing |
| `method_settings` | `map(object)` | `{}` | Configuración por método |

### API Key y Usage Plan

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `enable_api_key` | `bool` | `false` | Habilitar API Key |
| `api_key_name` | `string` | `null` | Nombre de la API Key |
| `usage_plan_config` | `object` | `null` | Configuración del Usage Plan |

## Outputs

| Output | Descripción |
|--------|-------------|
| `rest_api_id` | ID del API Gateway |
| `rest_api_root_resource_id` | ID del recurso raíz |
| `rest_api_execution_arn` | ARN de ejecución |
| `deployment_id` | ID del deployment |
| `stage_name` | Nombre del stage |
| `stage_arn` | ARN del stage |
| `stage_invoke_url` | URL de invocación |
| `resources` | Mapa de recursos creados |
| `methods` | Mapa de métodos creados |
| `authorizers` | Mapa de authorizers creados |
| `api_key_id` | ID de la API Key (si está habilitada) |
| `api_key_value` | Valor de la API Key (sensible) |
| `usage_plan_id` | ID del Usage Plan |

## Migración desde Versiones Anteriores

Si estabas usando los submódulos `resources/lambda` o `stage`, ahora todo se maneja en el módulo principal:

### Antes (con submódulos)

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"
  # ...
}

module "users_resource" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1//resources/parent"
  # ...
}

module "users_get" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1//resources/lambda"
  # ...
}

module "stage" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1//stage"
  # ...
}
```

### Ahora (todo integrado)

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-api"
  stage_name = "prod"

  lambda_integrations = [
    {
      path                = "/users"
      method              = "GET"
      lambda_invoke_arn   = aws_lambda_function.get_users.invoke_arn
      lambda_function_arn = aws_lambda_function.get_users.arn
    }
  ]
}
```

## Testing

Este módulo incluye una suite completa de tests con Terratest.

### Ejecutar Tests

```bash
# Ejecutar todos los tests
make test

# Ejecutar tests específicos
make test-basic
make test-lambda-integration
make test-authorizer

# Con un perfil específico de AWS
AWS_PROFILE=karibu make test
```

### Limpieza de Recursos

```bash
make cleanup
```

## Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/amazing-feature`)
3. Commit tus cambios (`git commit -m 'feat: Add amazing feature'`)
4. Push a la rama (`git push origin feature/amazing-feature`)
5. Abre un Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo LICENSE para más detalles.
