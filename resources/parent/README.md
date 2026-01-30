# Submódulo Parent para API Gateway

Este submódulo facilita la creación de recursos padre de API Gateway que pueden ser compartidos por múltiples métodos HTTP.

## Características

- Creación de recursos padre de API Gateway
- Soporte para jerarquías de recursos anidados
- Permite que múltiples métodos HTTP compartan el mismo recurso

## Uso básico

Crear un recurso padre que será usado por múltiples métodos:

```hcl
# Crear el recurso /users
module "users_resource" {
  source = "./resources/parent"
  
  rest_api_id        = module.api_gateway.rest_api_id
  parent_resource_id = module.api_gateway.rest_api_root_resource_id
  path_part          = "users"
}

# GET /users
module "users_get" {
  source = "./resources/lambda"
  
  rest_api_id            = module.api_gateway.rest_api_id
  resource_id            = module.users_resource.resource_id
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn
  
  http_method          = "GET"
  lambda_function_name = aws_lambda_function.get_users.function_name
  lambda_invoke_arn   = aws_lambda_function.get_users.invoke_arn
}

# POST /users
module "users_post" {
  source = "./resources/lambda"
  
  rest_api_id            = module.api_gateway.rest_api_id
  resource_id            = module.users_resource.resource_id
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn
  
  http_method          = "POST"
  lambda_function_name = aws_lambda_function.create_user.function_name
  lambda_invoke_arn   = aws_lambda_function.create_user.invoke_arn
}
```

## Uso con recursos anidados

Crear jerarquías de recursos:

```hcl
# Recurso padre /users
module "users_resource" {
  source = "./resources/parent"
  
  rest_api_id        = module.api_gateway.rest_api_id
  parent_resource_id = module.api_gateway.rest_api_root_resource_id
  path_part          = "users"
}

# Recurso hijo /users/{id}
module "user_id_resource" {
  source = "./resources/parent"
  
  rest_api_id        = module.api_gateway.rest_api_id
  parent_resource_id = module.users_resource.resource_id
  path_part          = "{id}"
}

# GET /users/{id}
module "user_get" {
  source = "./resources/lambda"
  
  rest_api_id            = module.api_gateway.rest_api_id
  resource_id            = module.user_id_resource.resource_id
  rest_api_execution_arn = module.api_gateway.rest_api_execution_arn
  
  http_method          = "GET"
  lambda_function_name = aws_lambda_function.get_user.function_name
  lambda_invoke_arn   = aws_lambda_function.get_user.invoke_arn
}
```

## Variables

### Requeridas

- `rest_api_id`: ID del REST API de API Gateway
- `parent_resource_id`: ID del recurso padre (típicamente root_resource_id, o puede ser otro recurso para jerarquías anidadas)
- `path_part`: Parte del path para este recurso (ej: 'users', '{id}', 'orders')

## Outputs

- `resource_id`: ID del recurso de API Gateway creado
- `resource_path`: Path completo del recurso
- `path_part`: Parte del path del recurso
