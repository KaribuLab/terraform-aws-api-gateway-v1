#!/bin/bash
set -e

# Lee parámetros JSON de stdin (formato requerido por external data source)
eval "$(jq -r '@sh "REST_API_ID=\(.rest_api_id) STAGE_NAME=\(.stage_name) REGION=\(.region)"')"

# Logging para debugging (solo si DEBUG está habilitado)
if [ "${DEBUG:-false}" = "true" ]; then
  echo "DEBUG: REST_API_ID=$REST_API_ID" >&2
  echo "DEBUG: STAGE_NAME=$STAGE_NAME" >&2
  echo "DEBUG: REGION=$REGION" >&2
fi

# Verificar si el stage existe
# Capturamos tanto stdout como stderr para debugging
RESULT=$(aws apigateway get-stage \
    --rest-api-id "$REST_API_ID" \
    --stage-name "$STAGE_NAME" \
    --region "$REGION" 2>&1) && EXISTS="true" || EXISTS="false"

if [ "${DEBUG:-false}" = "true" ]; then
  echo "DEBUG: EXISTS=$EXISTS" >&2
  echo "DEBUG: RESULT=$RESULT" >&2
fi

echo "{\"exists\": \"$EXISTS\"}"
