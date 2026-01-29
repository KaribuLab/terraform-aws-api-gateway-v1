# Submódulo Lambda para API Gateway

Este submódulo facilita la integración de funciones Lambda con API Gateway.

## Características

- Creación de recurso y método en API Gateway
- Integración con Lambda (AWS_PROXY o AWS personalizado)
- Soporte para Lambda Authorizers
- Soporte para API Keys
- CORS automático (opcional)
- Validación de requests (opcional)
- Configuración de method y integration responses

## Uso básico

```hcl
module "users_get" {
  source = "./resources/lambda"
  
  rest_api_id           = module.api_gateway.rest_api_id
  parent_resource_id    = module.api_gateway.rest_api_root_resource_id
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn
  
  path_part           = "users"
  http_method         = "GET"
  lambda_function_name = aws_lambda_function.users_get.function_name
  lambda_invoke_arn   = aws_lambda_function.users_get.invoke_arn
}
```

## Uso con authorizer

```hcl
module "users_post" {
  source = "./resources/lambda"
  
  rest_api_id           = module.api_gateway.rest_api_id
  parent_resource_id    = module.api_gateway.rest_api_root_resource_id
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn
  
  path_part           = "users"
  http_method         = "POST"
  lambda_function_name = aws_lambda_function.users_post.function_name
  lambda_invoke_arn   = aws_lambda_function.users_post.invoke_arn
  
  # Con authorizer
  authorizer_id = module.api_gateway.authorizer_id
}
```

## Uso con CORS

```hcl
module "products_get" {
  source = "./resources/lambda"
  
  rest_api_id           = module.api_gateway.rest_api_id
  parent_resource_id    = module.api_gateway.rest_api_root_resource_id
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn
  
  path_part           = "products"
  http_method         = "GET"
  lambda_function_name = aws_lambda_function.products_get.function_name
  lambda_invoke_arn   = aws_lambda_function.products_get.invoke_arn
  
  # Habilitar CORS
  enable_cors       = true
  cors_allow_origin = "'https://example.com'"
}
```

## Variables

### Requeridas

- `rest_api_id`: ID del REST API de API Gateway
- `parent_resource_id`: ID del recurso padre (típicamente root_resource_id)
- `rest_api_execution_arn`: ARN de ejecución del REST API
- `path_part`: Parte del path para este recurso (ej: 'users', 'products')
- `http_method`: Método HTTP (GET, POST, PUT, DELETE, etc.)
- `lambda_function_name`: Nombre de la función Lambda
- `lambda_invoke_arn`: ARN de invocación de la función Lambda

### Opcionales

- `authorization_type`: Tipo de autorización (NONE, AWS_IAM, CUSTOM, COGNITO_USER_POOLS) - Default: "NONE"
- `authorizer_id`: ID del authorizer (si se usa CUSTOM) - Default: null
- `api_key_required`: Si se requiere API Key - Default: false
- `integration_type`: Tipo de integración (AWS_PROXY, AWS, HTTP, HTTP_PROXY, MOCK) - Default: "AWS_PROXY"
- `timeout_milliseconds`: Timeout de integración - Default: 29000
- `request_templates`: Plantillas de request para la integración - Default: {}
- `request_validator_id`: ID del request validator - Default: null
- `request_parameters`: Parámetros de request - Default: {}
- `request_models`: Modelos de request - Default: {}
- `method_responses`: Configuración de method responses - Default: {"200" = {...}}
- `integration_responses`: Configuración de integration responses - Default: {"200" = {...}}
- `enable_cors`: Habilitar soporte CORS - Default: false
- `cors_allow_origin`: Valor de Access-Control-Allow-Origin - Default: "'*'"

## Outputs

- `resource_id`: ID del recurso de API Gateway creado
- `resource_path`: Path completo del recurso
- `method_id`: ID del método HTTP
- `integration_id`: ID de la integración
- `invoke_url_path`: Path para invocar el endpoint
