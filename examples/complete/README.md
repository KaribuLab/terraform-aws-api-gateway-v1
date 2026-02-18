# Ejemplo Completo

Este ejemplo demuestra todas las funcionalidades del módulo:

- Múltiples integraciones Lambda
- Lambda Authorizer para autenticación
- API Key con Usage Plan
- CORS habilitado
- Cache y throttling configurados
- X-Ray tracing
- Method settings personalizados

## Uso

```bash
# El ejemplo incluye un archivo lambda_function.py de ejemplo
# Terraform creará automáticamente el ZIP

# Inicializar y aplicar
terraform init
terraform apply -var="api_name=my-complete-api"
```

## Outputs

- `api_gateway_url`: URL base del API Gateway
- `api_key_value`: API Key para acceder a endpoints protegidos
- `authorizer_id`: ID del Lambda Authorizer

## Endpoints Creados

- `GET /users` - Público, con CORS
- `POST /users` - Requiere autenticación JWT, con CORS
- `GET /users/{id}` - Requiere API Key, con CORS

## Nota

Este ejemplo usa una función Lambda simple de prueba. En producción, reemplaza `lambda_function.py` con tu código real.
