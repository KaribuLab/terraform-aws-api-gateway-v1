#!/bin/bash
set -e

# Parámetros requeridos
REST_API_ID="${1:?Error: REST_API_ID es requerido}"
STAGE_NAME="${2:?Error: STAGE_NAME es requerido}"
DEPLOYMENT_ID="${3:?Error: DEPLOYMENT_ID es requerido}"
REGION="${4:?Error: REGION es requerido}"

echo "Verificando si el stage '$STAGE_NAME' existe..."

# Verificar si el stage existe
if aws apigateway get-stage \
    --rest-api-id "$REST_API_ID" \
    --stage-name "$STAGE_NAME" \
    --region "$REGION" >/dev/null 2>&1; then
  # Stage existe: actualizar el deployment
  echo "Stage '$STAGE_NAME' existe. Actualizando deployment a '$DEPLOYMENT_ID'..."
  
  aws apigateway update-stage \
    --rest-api-id "$REST_API_ID" \
    --stage-name "$STAGE_NAME" \
    --patch-operations "op=replace,path=/deploymentId,value=$DEPLOYMENT_ID" \
    --region "$REGION" \
    --output json
  
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 0 ]; then
    echo "Stage actualizado exitosamente."
  else
    echo "Error al actualizar el stage. Exit code: $EXIT_CODE" >&2
    exit $EXIT_CODE
  fi
else
  # Stage no existe: crearlo con el deployment
  echo "Stage '$STAGE_NAME' no existe. Creando stage con deployment '$DEPLOYMENT_ID'..."
  
  aws apigateway create-stage \
    --rest-api-id "$REST_API_ID" \
    --stage-name "$STAGE_NAME" \
    --deployment-id "$DEPLOYMENT_ID" \
    --region "$REGION" \
    --output json
  
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 0 ]; then
    echo "Stage creado exitosamente."
  else
    echo "Error al crear el stage. Exit code: $EXIT_CODE" >&2
    exit $EXIT_CODE
  fi
fi
