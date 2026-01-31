#!/bin/bash
set -e

# Parámetros requeridos
REST_API_ID="${1:?Error: REST_API_ID es requerido}"
STAGE_NAME="${2:?Error: STAGE_NAME es requerido}"
DEPLOYMENT_ID="${3:?Error: DEPLOYMENT_ID es requerido}"
REGION="${4:?Error: REGION es requerido}"

echo "Verificando si el stage '$STAGE_NAME' existe..."

# Verificar si el stage existe antes de actualizarlo
if ! aws apigateway get-stage \
    --rest-api-id "$REST_API_ID" \
    --stage-name "$STAGE_NAME" \
    --region "$REGION" >/dev/null 2>&1; then
  echo "Stage '$STAGE_NAME' no existe. Omitiendo actualización."
  exit 0
fi

echo "Actualizando stage '$STAGE_NAME' con deployment '$DEPLOYMENT_ID'..."

# Actualizar el deployment del stage
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
