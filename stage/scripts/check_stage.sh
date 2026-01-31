#!/bin/bash
set -e

# Lee parámetros JSON de stdin (formato requerido por external data source)
eval "$(jq -r '@sh "REST_API_ID=\(.rest_api_id) STAGE_NAME=\(.stage_name) REGION=\(.region)"')"

# Verificar si el stage existe
if aws apigateway get-stage \
    --rest-api-id "$REST_API_ID" \
    --stage-name "$STAGE_NAME" \
    --region "$REGION" >/dev/null 2>&1; then
  echo '{"exists": "true"}'
else
  echo '{"exists": "false"}'
fi
