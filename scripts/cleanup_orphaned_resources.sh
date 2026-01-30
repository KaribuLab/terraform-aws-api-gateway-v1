#!/bin/bash

# Script para limpiar recursos huérfanos de Terratest
# Solo elimina recursos con tags específicos de este módulo

set -euo pipefail

# Configuración
REPOSITORY_TAG="github.com/KaribuLab/terraform-aws-api-gateway-v1"
TERRATEST_TAG="true"
MAX_AGE_HOURS=2
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

# Usar perfil de AWS si está especificado
if [[ -n "${AWS_PROFILE:-}" ]]; then
    export AWS_PROFILE
fi

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Función para verificar si un recurso tiene los tags correctos
has_correct_tags() {
    local tags_json="$1"
    local terratest=$(echo "$tags_json" | jq -r '.terratest // empty')
    local repository=$(echo "$tags_json" | jq -r '.repository // empty')
    
    [[ "$terratest" == "$TERRATEST_TAG" && "$repository" == "$REPOSITORY_TAG" ]]
}

# Función para obtener timestamp de creación (si está disponible)
get_resource_age_hours() {
    local created_date="$1"
    if [[ -z "$created_date" ]]; then
        echo "0"
        return
    fi
    
    local created_epoch=$(date -d "$created_date" +%s 2>/dev/null || echo "0")
    local now_epoch=$(date +%s)
    local age_seconds=$((now_epoch - created_epoch))
    local age_hours=$((age_seconds / 3600))
    echo "$age_hours"
}

log_info "Iniciando limpieza de recursos huérfanos..."
log_info "Repositorio: $REPOSITORY_TAG"
log_info "Región: $REGION"
log_info "Edad máxima: ${MAX_AGE_HOURS} horas"

# 1. Limpiar WAF Associations
log_info "Buscando WAF Web ACL Associations..."
waf_associations=$(aws wafv2 list_resources_for_web_acl \
    --web-acl-id "$(aws wafv2 list-web-acls --scope REGIONAL --region "$REGION" --query "WebACLs[?Tags[?Key=='repository' && Value=='$REPOSITORY_TAG']].Id" --output text | head -1)" \
    --resource-type API_GATEWAY \
    --scope REGIONAL \
    --region "$REGION" \
    --query "ResourceArns" \
    --output json 2>/dev/null || echo "[]")

if [[ "$waf_associations" != "[]" && "$waf_associations" != "null" ]]; then
    echo "$waf_associations" | jq -r '.[]' | while read -r arn; do
        log_info "Eliminando WAF association: $arn"
        aws wafv2 disassociate-web-acl \
            --resource-arn "$arn" \
            --region "$REGION" 2>/dev/null || log_warn "No se pudo eliminar association: $arn"
    done
fi

# 2. Limpiar API Gateways
log_info "Buscando API Gateways de prueba..."
apis=$(aws apigateway get-rest-apis --region "$REGION" --query "items[]" --output json 2>/dev/null || echo "[]")

if [[ "$apis" != "[]" && "$apis" != "null" ]]; then
    echo "$apis" | jq -r ".[] | select(.tags.terratest == \"$TERRATEST_TAG\" and .tags.repository == \"$REPOSITORY_TAG\") | .id" | while read -r api_id; do
        if [[ -n "$api_id" ]]; then
            # Obtener edad del recurso
            api_info=$(echo "$apis" | jq -r ".[] | select(.id == \"$api_id\")")
            created_date=$(echo "$api_info" | jq -r '.createdDate // empty')
            age_hours=$(get_resource_age_hours "$created_date")
            
            if [[ $age_hours -ge $MAX_AGE_HOURS ]]; then
                log_info "Eliminando API Gateway: $api_id (edad: ${age_hours}h)"
                
                # Eliminar stages primero
                stages=$(aws apigateway get-stages --rest-api-id "$api_id" --region "$REGION" --query "item[].stageName" --output text 2>/dev/null || echo "")
                for stage in $stages; do
                    log_info "  Eliminando stage: $stage"
                    aws apigateway delete-stage --rest-api-id "$api_id" --stage-name "$stage" --region "$REGION" 2>/dev/null || true
                done
                
                # Eliminar deployments
                deployments=$(aws apigateway get-deployments --rest-api-id "$api_id" --region "$REGION" --query "items[].id" --output text 2>/dev/null || echo "")
                for deployment_id in $deployments; do
                    log_info "  Eliminando deployment: $deployment_id"
                    aws apigateway delete-deployment --rest-api-id "$api_id" --deployment-id "$deployment_id" --region "$REGION" 2>/dev/null || true
                done
                
                # Eliminar API Gateway
                aws apigateway delete-rest-api --rest-api-id "$api_id" --region "$REGION" 2>/dev/null || log_warn "No se pudo eliminar API Gateway: $api_id"
            else
                log_info "Saltando API Gateway: $api_id (muy reciente: ${age_hours}h)"
            fi
        fi
    done
fi

# 3. Limpiar Usage Plans y API Keys
log_info "Buscando Usage Plans y API Keys..."
usage_plans=$(aws apigateway get-usage-plans --region "$REGION" --query "items[]" --output json 2>/dev/null || echo "[]")

if [[ "$usage_plans" != "[]" && "$usage_plans" != "null" ]]; then
    echo "$usage_plans" | jq -r ".[] | select(.tags.terratest == \"$TERRATEST_TAG\" and .tags.repository == \"$REPOSITORY_TAG\") | .id" | while read -r plan_id; do
        if [[ -n "$plan_id" ]]; then
            log_info "Eliminando Usage Plan: $plan_id"
            
            # Eliminar usage plan keys primero
            keys=$(aws apigateway get-usage-plan-keys --usage-plan-id "$plan_id" --region "$REGION" --query "items[].id" --output text 2>/dev/null || echo "")
            for key_id in $keys; do
                log_info "  Eliminando usage plan key: $key_id"
                aws apigateway delete-usage-plan-key --usage-plan-id "$plan_id" --key-id "$key_id" --region "$REGION" 2>/dev/null || true
            done
            
            # Eliminar usage plan
            aws apigateway delete-usage-plan --usage-plan-id "$plan_id" --region "$REGION" 2>/dev/null || log_warn "No se pudo eliminar Usage Plan: $plan_id"
        fi
    done
fi

# Limpiar API Keys huérfanas
api_keys=$(aws apigateway get-api-keys --include-values --region "$REGION" --query "items[]" --output json 2>/dev/null || echo "[]")
if [[ "$api_keys" != "[]" && "$api_keys" != "null" ]]; then
    echo "$api_keys" | jq -r ".[] | select(.tags.terratest == \"$TERRATEST_TAG\" and .tags.repository == \"$REPOSITORY_TAG\") | .id" | while read -r key_id; do
        if [[ -n "$key_id" ]]; then
            log_info "Eliminando API Key: $key_id"
            aws apigateway delete-api-key --api-key "$key_id" --region "$REGION" 2>/dev/null || log_warn "No se pudo eliminar API Key: $key_id"
        fi
    done
fi

# 4. Limpiar Lambda Functions
log_info "Buscando Lambda Functions de prueba..."
lambda_functions=$(aws lambda list-functions --region "$REGION" --query "Functions[]" --output json 2>/dev/null || echo "[]")

if [[ "$lambda_functions" != "[]" && "$lambda_functions" != "null" ]]; then
    echo "$lambda_functions" | jq -r ".[] | select(.Tags.terratest == \"$TERRATEST_TAG\" and .Tags.repository == \"$REPOSITORY_TAG\") | .FunctionName" | while read -r function_name; do
        if [[ -n "$function_name" ]]; then
            log_info "Eliminando Lambda Function: $function_name"
            aws lambda delete-function --function-name "$function_name" --region "$REGION" 2>/dev/null || log_warn "No se pudo eliminar Lambda: $function_name"
        fi
    done
fi

# 5. Limpiar WAF Web ACLs
log_info "Buscando WAF Web ACLs de prueba..."
waf_acls=$(aws wafv2 list-web-acls --scope REGIONAL --region "$REGION" --query "WebACLs[]" --output json 2>/dev/null || echo "[]")

if [[ "$waf_acls" != "[]" && "$waf_acls" != "null" ]]; then
    # Iterar sobre cada ACL y verificar sus tags
    echo "$waf_acls" | jq -r ".[].ARN" | while read -r acl_arn; do
        if [[ -n "$acl_arn" ]]; then
            # Obtener tags para este ACL
            acl_tags=$(aws wafv2 list-tags-for-resource --resource-arn "$acl_arn" --region "$REGION" --output json 2>/dev/null || echo '{"TagInfoForResource":{"TagList":[]}}')
            
            # Verificar si tiene los tags de terratest
            has_terratest=$(echo "$acl_tags" | jq -r '.TagInfoForResource.TagList[] | select(.Key == "terratest" and .Value == "'"$TERRATEST_TAG"'") | .Key' 2>/dev/null | head -1)
            has_repository=$(echo "$acl_tags" | jq -r '.TagInfoForResource.TagList[] | select(.Key == "repository" and .Value == "'"$REPOSITORY_TAG"'") | .Key' 2>/dev/null | head -1)
            
            if [[ -n "$has_terratest" && -n "$has_repository" ]]; then
                acl_id=$(echo "$waf_acls" | jq -r ".[] | select(.ARN == \"$acl_arn\") | .Id")
                acl_name=$(echo "$waf_acls" | jq -r ".[] | select(.ARN == \"$acl_arn\") | .Name")
                acl_lock_token=$(echo "$waf_acls" | jq -r ".[] | select(.ARN == \"$acl_arn\") | .LockToken")
                log_info "Eliminando WAF Web ACL: $acl_name ($acl_id)"
                aws wafv2 delete-web-acl --id "$acl_id" --name "$acl_name" --scope REGIONAL --lock-token "$acl_lock_token" --region "$REGION" 2>/dev/null || log_warn "No se pudo eliminar Web ACL: $acl_id"
            fi
        fi
    done
fi

log_info "Limpieza completada"
