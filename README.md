# Terraform AWS API Gateway v1 Module

Módulo de Terraform para crear y gestionar API Gateway REST API v1 en AWS con integraciones Lambda declarativas. Soporta múltiples stages con diferentes versiones de Lambda por entorno.

## Características

- **Interfaz declarativa**: Define todos tus endpoints Lambda en una sola variable
- **OpenAPI interno**: El módulo genera internamente un spec OpenAPI 3.0 para la creación de la API, eliminando ciclos de dependencia
- **Deployment y Stage integrados**: No necesitas gestionar deployments manualmente
- **Multi-stage**: Soporte para múltiples stages (dev, qa, prod) con diferentes aliases de Lambda
- **Lambda Authorizers**: Soporte completo para authorizers personalizados
- **CORS automático**: Habilita CORS por endpoint con configuración simple
- **API Key y Usage Plans**: Autenticación opcional con límites de uso por stage
- **Method Settings**: Configuración de cache, throttling y logs por método
- **WAFv2 opcional**: Asociación declarativa de un Web ACL al stage del API (puede ser el mismo WAF para todos los stages)
- **Stage Variables**: Soporte para variables de stage que permiten invocar diferentes aliases de Lambda por entorno

## Requisitos

- Terraform >= 1.0
- AWS Provider >= 5.0
- Credenciales AWS configuradas
- Permisos IAM necesarios para crear recursos de API Gateway, Lambda y WAF (si se usa)

## Uso Básico (Todo en Uno)

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
    }
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Uso Avanzado: API y Stages Separados (Terragrunt)

Para despliegues independientes por entorno (dev, qa, prod) con diferentes aliases de Lambda:

### Estructura de Carpetas

```text
live/
  terragrunt.hcl              # backend, provider, inputs comunes
  apigateway/
    terragrunt.hcl            # Solo el API REST (sin stage)
  stages/
    dev/
      terragrunt.hcl          # Stage dev con alias lambda "dev"
    qa/
      terragrunt.hcl          # Stage qa con alias lambda "qa"
    prod/
      terragrunt.hcl          # Stage prod con alias lambda "prod"
```

### 1. API Gateway (sin stage)

**`live/apigateway/terragrunt.hcl`:**

```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/KaribuLab/terraform-aws-api-gateway-v1.git//.?ref=x.y.z"
}

inputs = {
  aws_region  = "us-east-1"
  api_name    = "my-api"
  create_stage = false  # Solo crea el API REST, no el stage

  # Usa lambda_alias_variable para invocar diferentes aliases por stage
  lambda_integrations = [
    {
      path                  = "/users"
      method                = "GET"
      lambda_function_arn   = "arn:aws:lambda:us-east-1:123456789012:function:get-users"
      lambda_alias_variable = "lambda_alias"  # Usa stage variable
    },
    {
      path                  = "/users"
      method                = "POST"
      lambda_function_arn   = "arn:aws:lambda:us-east-1:123456789012:function:create-user"
      lambda_alias_variable = "lambda_alias"
      enable_cors           = true
    }
  ]

  tags = {
    Environment = "shared"
  }
}
```

### 2. Stage Dev

**`live/stages/dev/terragrunt.hcl`:**

```hcl
include "root" {
  path = find_in_parent_folders()
}

dependency "apigateway" {
  config_path = "../../apigateway"
}

terraform {
  source = "git::https://github.com/KaribuLab/terraform-aws-api-gateway-v1.git//modules/stage?ref=x.y.z"
}

inputs = {
  rest_api_id        = dependency.apigateway.outputs.rest_api_id
  openapi_spec_sha   = dependency.apigateway.outputs.openapi_spec_sha
  rest_api_execution_arn = dependency.apigateway.outputs.rest_api_execution_arn

  stage_name         = "dev"
  stage_variables = {
    lambda_alias = "dev"  # El alias que usarán las integraciones
  }

  # WAF opcional - puede ser el mismo para todos los stages
  waf_web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/my-web-acl/..."

  tags = {
    Environment = "dev"
  }
}

# Opcional: skip para run-all selectivo
# skip = !get_env("RUN_DEV_STAGE", false)
```

### 3. Stage QA

**`live/stages/qa/terragrunt.hcl`:**

```hcl
include "root" {
  path = find_in_parent_folders()
}

dependency "apigateway" {
  config_path = "../../apigateway"
}

terraform {
  source = "git::https://github.com/KaribuLab/terraform-aws-api-gateway-v1.git//modules/stage?ref=x.y.z"
}

inputs = {
  rest_api_id        = dependency.apigateway.outputs.rest_api_id
  openapi_spec_sha   = dependency.apigateway.outputs.openapi_spec_sha
  rest_api_execution_arn = dependency.apigateway.outputs.rest_api_execution_arn

  stage_name         = "qa"
  stage_variables = {
    lambda_alias = "qa"  # El alias que usarán las integraciones
  }

  waf_web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/my-web-acl/..."

  tags = {
    Environment = "qa"
  }
}
```

### 4. Stage Prod

**`live/stages/prod/terragrunt.hcl`:**

```hcl
include "root" {
  path = find_in_parent_folders()
}

dependency "apigateway" {
  config_path = "../../apigateway"
}

terraform {
  source = "git::https://github.com/KaribuLab/terraform-aws-api-gateway-v1.git//modules/stage?ref=x.y.z"
}

inputs = {
  rest_api_id        = dependency.apigateway.outputs.rest_api_id
  openapi_spec_sha   = dependency.apigateway.outputs.openapi_spec_sha
  rest_api_execution_arn = dependency.apigateway.outputs.rest_api_execution_arn

  stage_name         = "prod"
  stage_variables = {
    lambda_alias = "prod"  # El alias que usarán las integraciones
  }

  waf_web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/my-web-acl/..."

  # API Key y Usage Plan para producción
  api_key_config = {
    name        = "prod-api-key"
    description = "API Key para producción"
    usage_plan = {
      name        = "prod-usage-plan"
      description = "Plan de uso para producción"
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

  tags = {
    Environment = "prod"
  }
}
```

### Aplicar los Cambios

```bash
# Aplicar solo el API Gateway
cd live/apigateway && terragrunt apply

# Aplicar cada stage individualmente
cd live/stages/dev && terragrunt apply
cd live/stages/qa && terragrunt apply
cd live/stages/prod && terragrunt apply

# O aplicar todos los stages con run-all (respetando los skip si están configurados)
cd live && terragrunt run-all apply
```

## Ejemplos Adicionales

### Con Lambda Authorizer

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-secure-api"
  stage_name = "prod"

  authorizers = {
    jwt_auth = {
      lambda_arn        = aws_lambda_function.authorizer.arn
      lambda_invoke_arn = aws_lambda_function.authorizer.invoke_arn
      type              = "TOKEN"
      identity_source   = "method.request.header.Authorization"
    }
  }

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

### Con API Key y Usage Plan (por stage)

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
      lambda_invoke_arn   = aws_lambda_function.get_items.invoke_arn
      lambda_function_arn = aws_lambda_function.get_items.arn
      api_key_required    = true
    }
  ]

  enable_api_key      = true
  usage_plan_config = {
    name = "standard-plan"
    quota_settings = {
      limit  = 1000
      period = "DAY"
    }
    throttle_settings = {
      burst_limit = 100
      rate_limit  = 50
    }
  }
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

  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

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
| `stage_name` | `string` | - | Nombre del stage (requerido si `create_stage = true`) |
| `tags` | `map(string)` | `{}` | Tags para todos los recursos |
| `endpoint_type` | `string` | `"REGIONAL"` | Tipo de endpoint (REGIONAL, EDGE, PRIVATE) |
| `waf_web_acl_arn` | `string` | `null` | ARN del Web ACL WAFv2 para asociar al stage (opcional, requiere `endpoint_type = "REGIONAL"`) |
| `create_stage` | `bool` | `true` | Si es `false`, solo crea el API REST sin stage (útil para separar en múltiples states) |

### Lambda Integrations

| Campo | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `path` | `string` | - | Ruta del endpoint (ej: `/users`, `/profile/{id}`) |
| `method` | `string` | - | Método HTTP (GET, POST, PUT, DELETE, etc.) |
| `lambda_invoke_arn` | `string` | `null` | ARN de invocación de Lambda (requerido si no se usa `lambda_alias_variable`) |
| `lambda_function_arn` | `string` | - | ARN de la función Lambda (para permisos de invocación) |
| `lambda_alias_variable` | `string` | `null` | Nombre de la variable de stage que contiene el alias (ej: `"lambda_alias"`). Si se especifica, la URI usará stageVariables para invocar el alias correspondiente |
| `authorization_type` | `string` | `"NONE"` | Tipo de autorización (NONE, CUSTOM) |
| `authorizer_key` | `string` | `null` | Clave del authorizer (requerido si `authorization_type = "CUSTOM"`) |
| `api_key_required` | `bool` | `false` | Si requiere API Key |
| `enable_cors` | `bool` | `false` | Habilitar CORS |
| `cors_allow_origin` | `string` | `"'*'"` | Valor de Access-Control-Allow-Origin |
| `cors_allow_headers` | `string` | headers estándar | Headers permitidos en CORS |
| `cors_allow_methods` | `string` | auto-generado | Métodos permitidos en CORS |

**Nota:** Debe especificar exactamente uno de `lambda_invoke_arn` o `lambda_alias_variable`, pero no ambos.

### Authorizers

| Campo | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `lambda_arn` | `string` | - | ARN de la función Lambda authorizer |
| `lambda_invoke_arn` | `string` | - | ARN de invocación de la función Lambda authorizer |
| `type` | `string` | `"TOKEN"` | Tipo de authorizer (TOKEN o REQUEST) |
| `identity_source` | `string` | `"method.request.header.Authorization"` | Fuente de identidad |
| `authorizer_result_ttl` | `number` | `300` | TTL del resultado en segundos |
| `identity_validation_expression` | `string` | `null` | Expresión regex de validación |

### Stage Configuration

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `stage_description` | `string` | `"Stage managed by Terraform"` | Descripción del stage |
| `stage_variables` | `map(string)` | `{}` | Variables del stage (ej: `{ lambda_alias = "dev" }`) |
| `cache_cluster_enabled` | `bool` | `false` | Habilitar cache cluster |
| `cache_cluster_size` | `string` | `"0.5"` | Tamaño del cache (GB) |
| `xray_tracing_enabled` | `bool` | `false` | Habilitar X-Ray tracing |
| `method_settings` | `map(object)` | `{}` | Configuración por método |

### API Key y Usage Plan

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `enable_api_key` | `bool` | `false` | Habilitar API Key |
| `api_key_name` | `string` | `null` | Nombre de la API Key |
| `api_key_description` | `string` | `"API Key managed by Terraform"` | Descripción de la API Key |
| `usage_plan_config` | `object` | `null` | Configuración del Usage Plan (requerido si `enable_api_key = true`) |

### WAF

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `waf_web_acl_arn` | `string` | `null` | ARN del Web ACL de WAFv2 para asociarlo al stage |

> Nota: la asociación de WAFv2 en API Gateway REST API v1 se realiza sobre el stage y requiere `endpoint_type = "REGIONAL"`. Puedes usar el **mismo Web ACL** para múltiples stages (una asociación por stage).

## Outputs

| Output | Descripción |
|--------|-------------|
| `rest_api_id` | ID del API Gateway |
| `rest_api_root_resource_id` | ID del recurso raíz |
| `rest_api_execution_arn` | ARN de ejecución |
| `openapi_spec_sha` | Hash SHA del spec OpenAPI (útil para trigger de redeploy en submódulos stage) |
| `deployment_id` | ID del deployment (solo si `create_stage = true`) |
| `stage_name` | Nombre del stage (solo si `create_stage = true`) |
| `stage_arn` | ARN del stage (solo si `create_stage = true`) |
| `stage_invoke_url` | URL de invocación (solo si `create_stage = true`) |
| `stage_execution_arn` | ARN de ejecución del stage (solo si `create_stage = true`) |
| `api_key_id` | ID de la API Key (si está habilitada) |
| `api_key_value` | Valor de la API Key (sensible) |
| `usage_plan_id` | ID del Usage Plan |
| `waf_web_acl_association_id` | ID de la asociación WAFv2 al stage (si está habilitada) |

## Submódulo Stage

El módulo incluye un submódulo `modules/stage` que permite crear stages independientes del API. Esto es útil cuando:

- Quieres desplegar múltiples stages (dev, qa, prod) en states separados
- Quieres que cada stage tenga su propio ciclo de vida de despliegue
- Necesitas aplicar stages individualmente sin afectar el API base

### Inputs del Submódulo Stage

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `rest_api_id` | `string` | - | ID del API Gateway REST API (requerido) |
| `rest_api_execution_arn` | `string` | - | ARN de ejecución del API |
| `stage_name` | `string` | - | Nombre del stage (requerido) |
| `openapi_spec_sha` | `string` | - | Hash del spec OpenAPI para trigger de redeploy |
| `stage_variables` | `map(string)` | `{}` | Variables del stage |
| `waf_web_acl_arn` | `string` | `null` | ARN del Web ACL para asociar |
| `api_key_config` | `object` | `null` | Configuración de API Key y Usage Plan |
| `method_settings` | `map(object)` | `{}` | Configuración por método |

### Ejemplo de Uso del Submódulo

```hcl
module "stage_dev" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1//modules/stage"

  rest_api_id            = aws_api_gateway_rest_api.my_api.id
  rest_api_execution_arn = aws_api_gateway_rest_api.my_api.execution_arn
  openapi_spec_sha       = sha1(jsonencode(local.openapi_spec))

  stage_name = "dev"
  stage_variables = {
    lambda_alias = "dev"
  }
}
```

## Arquitectura Interna

El módulo utiliza internamente la especificación OpenAPI 3.0 para definir la API. A partir de los inputs `lambda_integrations` y `authorizers`, genera un spec OpenAPI que incluye:

- Paths y métodos HTTP
- Integraciones `AWS_PROXY` con Lambda (con soporte para stage variables en la URI)
- Security schemes para authorizers y API Keys
- Métodos OPTIONS para CORS con integración mock
- Endpoint configuration del API (REGIONAL/EDGE/PRIVATE)

Cuando se usa `lambda_alias_variable`, la URI de integración se construye con la sintaxis `${stageVariables.<nombre>}`, que API Gateway resuelve en tiempo de ejecución según el stage que recibe la solicitud. Esto permite que diferentes stages invoquen diferentes aliases de Lambda sin cambiar la definición del API.

La asociación de WAFv2 se realiza con un recurso dedicado (`aws_wafv2_web_acl_association`) y no forma parte del spec OpenAPI.

## Testing

Este módulo incluye una suite completa de tests con Terratest.

### Ejecutar Tests

```bash
make test

make test-basic
make test-lambda-integration
make test-authorizer

AWS_PROFILE=karibu make test
```

### Limpieza de Recursos

```bash
make cleanup
```

## License

MIT License - ver [LICENSE](LICENSE) para más detalles.
