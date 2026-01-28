# Terraform AWS API Gateway v1 Module

Módulo de Terraform para crear y gestionar API Gateway REST API v1 en AWS con funcionalidades opcionales avanzadas.

## Características

- **Funcionalidad básica**: Creación de API Gateway REST API
- **Stage opcional**: El módulo puede crear el stage o dejarlo al usuario
- **Autenticación opcional**: 
  - API Key con Usage Plans (asociación automática si el módulo crea el stage)
  - Lambda Authorizer con permisos automáticos

## Requisitos

- Terraform >= 1.0
- AWS Provider >= 5.0
- Credenciales AWS configuradas
- Permisos IAM necesarios para crear recursos de API Gateway

## Dos Formas de Usar el Módulo

### Opción 1: El usuario crea el stage (más flexible)

```hcl
module "api_gateway" {
  source   = "github.com/KaribuLab/terraform-aws-api-gateway-v1"
  api_name = "my-api"
  # stage_config = null (por defecto)
}

# Usuario crea deployment y stage
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = module.api_gateway.rest_api_id
  # ... triggers ...
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = module.api_gateway.rest_api_id
  stage_name    = "prod"
}
```

### Opción 2: El módulo crea el stage (más simple)

```hcl
# Usuario crea deployment primero
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = module.api_gateway.rest_api_id
  # ... triggers ...
}

module "api_gateway" {
  source        = "github.com/KaribuLab/terraform-aws-api-gateway-v1"
  api_name      = "my-api"
  deployment_id = aws_api_gateway_deployment.this.id
  
  stage_config = {
    stage_name            = "prod"
    cache_cluster_enabled = true
    cache_cluster_size    = "0.5"
  }
  
  # Usage Plan se asocia automáticamente al stage
  enable_api_key = true
  usage_plan_config = {
    name = "prod-plan"
  }
}
```

## Ejemplos

### Con API Key

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-api"

  enable_api_key = true
  api_key_name   = "my-api-key"

  usage_plan_config = {
    name        = "my-usage-plan"
    description = "Usage plan for my API"
    throttle_settings = {
      burst_limit = 100
      rate_limit  = 50
    }
  }
}
```

### Con Lambda Authorizer

```hcl
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-api"

  authorizer_config = {
    name       = "my-authorizer"
    lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:my-authorizer"
    type       = "TOKEN"
  }
}
```


## Alcance del Módulo

Este módulo crea **solo el API Gateway REST API base** con opciones de autenticación (API Key y Lambda Authorizer). 

**No incluye**:
- Recursos y métodos (debes crearlos tú)
- Deployment y Stage (debes crearlos tú después de agregar tus métodos)
- Configuración de WAF, caché o throttling (se configuran a nivel de stage)

### Ejemplo de Uso Completo

```hcl
# 1. Crear el API Gateway base con autenticación
module "api_gateway" {
  source = "github.com/KaribuLab/terraform-aws-api-gateway-v1"

  aws_region = "us-east-1"
  api_name   = "my-api"
  
  # Opcional: API Key
  enable_api_key = true
  api_key_name   = "my-api-key"
  
  # Opcional: Lambda Authorizer
  authorizer_config = {
    name       = "my-authorizer"
    lambda_arn = aws_lambda_function.authorizer.arn
    type       = "TOKEN"
  }
}

# 2. Agregar tus recursos y métodos
resource "aws_api_gateway_resource" "example" {
  rest_api_id = module.api_gateway.rest_api_id
  parent_id   = module.api_gateway.rest_api_root_resource_id
  path_part   = "example"
}

resource "aws_api_gateway_method" "example" {
  rest_api_id   = module.api_gateway.rest_api_id
  resource_id   = aws_api_gateway_resource.example.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = module.api_gateway.authorizer_id
}

resource "aws_api_gateway_integration" "example" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.example.id
  http_method = aws_api_gateway_method.example.http_method
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.backend.invoke_arn
}

# 3. Crear deployment y stage
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = module.api_gateway.rest_api_id
  
  # Forzar nuevo deployment cuando cambien los métodos
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.example.id,
      aws_api_gateway_method.example.id,
      aws_api_gateway_integration.example.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = module.api_gateway.rest_api_id
  stage_name    = "prod"
  
  # Opcional: habilitar caché
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"
}

# 4. Opcional: Asociar Usage Plan al stage
resource "aws_api_gateway_usage_plan_api" "this" {
  usage_plan_id = module.api_gateway.usage_plan_id
  api_id        = module.api_gateway.rest_api_id
  stage_name    = aws_api_gateway_stage.prod.stage_name
}

# 5. Opcional: Configurar WAF
resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.example.arn
}

# 6. Opcional: Configurar throttling por método
resource "aws_api_gateway_method_settings" "example" {
  rest_api_id = module.api_gateway.rest_api_id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "${aws_api_gateway_resource.example.path_part}/${aws_api_gateway_method.example.http_method}"
  
  settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}
```

## Testing

Este módulo incluye una suite completa de tests con Terratest.

### Ejecutar Tests

#### Opción 1: Usando Makefile (recomendado)

```bash
# Ejecutar todos los tests con limpieza automática
make test

# Ejecutar tests específicos
make test-basic        # Solo test básico
make test-auth         # Tests de autenticación
make test-security     # Tests de WAF
make test-performance  # Tests de caché y throttling

# Solo limpieza de recursos huérfanos
make cleanup

# Instalar dependencias
make test-deps
```

#### Opción 2: Usando scripts directamente

```bash
# Ejecutar todos los tests con limpieza
./scripts/run_tests.sh

# Solo limpieza
./scripts/cleanup_orphaned_resources.sh
```

#### Usar un perfil específico de AWS

Para ejecutar los tests con un perfil específico de AWS (por ejemplo, `karibu`):

```bash
# Opción 1: Variable de entorno (recomendado)
export AWS_PROFILE=karibu
make test

# Opción 2: Inline con Makefile
AWS_PROFILE=karibu make test

# Opción 3: Con script directamente
AWS_PROFILE=karibu ./scripts/run_tests.sh

# Opción 4: Pasando como argumento al script
./scripts/run_tests.sh karibu
```

**Nota**: Terratest y AWS CLI respetan automáticamente la variable de entorno `AWS_PROFILE`, por lo que todos los comandos usarán el perfil especificado.

Los tests siempre muestran la salida completa de Terraform (`terraform init`, `terraform apply`, etc.) en la salida estándar para facilitar el diagnóstico en pipelines de CI/CD.

#### Opción 3: Ejecutar tests individuales

```bash
cd test
go test -v -timeout 30m -run TestBasicAPIGateway ./...
go test -v -timeout 30m -run TestAPIKey ./...
go test -v -timeout 30m -run TestLambdaAuthorizer ./...
go test -v -timeout 30m -run TestWAF ./...
go test -v -timeout 30m -run TestCache ./...
go test -v -timeout 30m -run TestThrottling ./...
```

### Limpieza de Recursos Huérfanos

Los scripts de limpieza eliminan automáticamente recursos de prueba que:

- Tienen el tag `terratest=true`
- Tienen el tag `repository=github.com/KaribuLab/terraform-aws-api-gateway-v1`
- Son más antiguos que 2 horas (para evitar eliminar tests en ejecución)

**Importante**: Los scripts NUNCA eliminarán recursos que no tengan ambos tags, garantizando que no se borren recursos de otros módulos o proyectos.

### Estructura de Tests

```
test/
├── basic_test.go                    # Test funcionalidad básica
├── api_key_test.go                  # Test API Key + Usage Plan
├── lambda_authorizer_test.go        # Test Lambda Authorizer
├── waf_test.go                      # Test integración WAF
├── cache_test.go                    # Test caché
├── throttling_test.go               # Test throttling
├── fixtures/                        # Configuraciones Terraform para tests
│   ├── basic/
│   ├── api_key/
│   ├── lambda_authorizer/
│   ├── waf/
│   ├── cache/
│   └── throttling/
└── helpers/
    └── test_helpers.go              # Funciones comunes
```

## Variables

Ver [main.tf](main.tf) para la lista completa de variables disponibles.

## Outputs

- `rest_api_id` - ID del API Gateway
- `rest_api_root_resource_id` - ID del recurso raíz
- `rest_api_execution_arn` - ARN de ejecución (útil para permisos Lambda)
- `stage_name` - Nombre del stage creado por el módulo (null si el usuario crea el stage externamente)
- `stage_arn` - ARN del stage creado por el módulo (null si el usuario crea el stage externamente)
- `invoke_url` - URL de invocación del stage (null si el usuario crea el stage externamente)
- `api_key_id` - ID de la API Key (si está habilitada)
- `api_key_value` - Valor de la API Key (si está habilitada, sensible)
- `usage_plan_id` - ID del Usage Plan (si está configurado)
- `authorizer_id` - ID del Lambda Authorizer (si está configurado)

## Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/amazing-feature`)
3. Commit tus cambios (`git commit -m 'feat: Add amazing feature'`)
4. Push a la rama (`git push origin feature/amazing-feature`)
5. Abre un Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo LICENSE para más detalles.
