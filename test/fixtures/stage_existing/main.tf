terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Crear el API Gateway principal
module "api_gateway" {
  source = "../../.."

  aws_region      = var.aws_region
  api_name        = var.api_name
  api_description = var.api_description
  tags            = var.tags
}

# Crear recursos y métodos para el test
resource "aws_api_gateway_resource" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  parent_id   = module.api_gateway.rest_api_root_resource_id
  path_part   = "test"
}

resource "aws_api_gateway_method" "test" {
  rest_api_id   = module.api_gateway.rest_api_id
  resource_id   = aws_api_gateway_resource.test.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.test.id
  http_method = aws_api_gateway_method.test.http_method
  type        = "MOCK"
}

resource "aws_api_gateway_method_response" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.test.id
  http_method = aws_api_gateway_method.test.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "test" {
  rest_api_id = module.api_gateway.rest_api_id
  resource_id = aws_api_gateway_resource.test.id
  http_method = aws_api_gateway_method.test.http_method
  status_code = aws_api_gateway_method_response.test.status_code
}

# Crear un deployment inicial MANUALMENTE
resource "aws_api_gateway_deployment" "initial" {
  rest_api_id = module.api_gateway.rest_api_id
  depends_on  = [aws_api_gateway_integration.test]
}

# Crear el stage MANUALMENTE (fuera del módulo stage/)
resource "aws_api_gateway_stage" "existing" {
  rest_api_id   = module.api_gateway.rest_api_id
  stage_name    = var.stage_name
  deployment_id = aws_api_gateway_deployment.initial.id
  tags          = var.tags
}

# Restaurar el deployment inicial antes de destruir el módulo
# Esto evita el error "Active stages pointing to this deployment"
# Nota: Este null_resource se ejecuta durante destroy para restaurar el deployment inicial
# Obtiene el deployment_id inicial del stage directamente via AWS CLI para evitar ciclos
resource "null_resource" "restore_initial_deployment" {
  triggers = {
    rest_api_id = module.api_gateway.rest_api_id
    stage_name  = var.stage_name
    aws_region   = var.aws_region
  }

  # Restaurar el deployment inicial antes de destruir
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      REST_API_ID="${self.triggers.rest_api_id}"
      STAGE_NAME="${self.triggers.stage_name}"
      REGION="${self.triggers.aws_region}"
      
      # Obtener el deployment_id inicial del stage (almacenado en variables del stage o tags)
      # Por ahora, simplemente intentamos restaurar cualquier deployment anterior
      # que no sea el del módulo
      if aws apigateway get-stage \
          --rest-api-id "$REST_API_ID" \
          --stage-name "$STAGE_NAME" \
          --region "$REGION" >/dev/null 2>&1; then
        # Obtener todos los deployments y usar el más antiguo que no sea el actual
        CURRENT_DEPLOYMENT=$(aws apigateway get-stage \
          --rest-api-id "$REST_API_ID" \
          --stage-name "$STAGE_NAME" \
          --region "$REGION" \
          --query 'deploymentId' --output text)
        
        # Obtener el deployment inicial (el primero creado, asumiendo que es el más antiguo)
        INITIAL_DEPLOYMENT=$(aws apigateway get-deployments \
          --rest-api-id "$REST_API_ID" \
          --region "$REGION" \
          --query 'items | sort_by(@, &createdDate) | [0].id' --output text)
        
        # Si el deployment actual no es el inicial, restaurar el inicial
        if [ "$CURRENT_DEPLOYMENT" != "$INITIAL_DEPLOYMENT" ] && [ -n "$INITIAL_DEPLOYMENT" ]; then
          echo "Restaurando deployment inicial '$INITIAL_DEPLOYMENT' en stage '$STAGE_NAME'..."
          aws apigateway update-stage \
            --rest-api-id "$REST_API_ID" \
            --stage-name "$STAGE_NAME" \
            --patch-operations "op=replace,path=/deploymentId,value=$INITIAL_DEPLOYMENT" \
            --region "$REGION" >/dev/null 2>&1 || true
        fi
      fi
    EOT
  }
  
  # Depender del módulo para que se ejecute antes durante destroy
  depends_on = [module.stage_test]
}

# Ahora usar el módulo stage/ con auto_detect_existing_stage = true
module "stage_test" {
  source = "../../../stage"

  rest_api_id                = module.api_gateway.rest_api_id
  aws_region                 = var.aws_region
  stage_name                 = var.stage_name
  auto_detect_existing_stage = true # <-- Detectar stage existente

  deployment_triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.test.id,
      aws_api_gateway_method.test.id,
      aws_api_gateway_integration.test.id,
    ]))
  }

  tags = var.tags

  # Asegurar que el stage se cree antes de que el módulo intente detectarlo
  depends_on = [aws_api_gateway_stage.existing]
}

variable "aws_region" {
  type = string
}

variable "api_name" {
  type = string
}

variable "stage_name" {
  type = string
}

variable "api_description" {
  type    = string
  default = "Test API Gateway with Existing Stage"
}

variable "tags" {
  type    = map(string)
  default = {}
}
