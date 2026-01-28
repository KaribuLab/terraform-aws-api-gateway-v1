#!/bin/bash

# Script ejecutor de tests con limpieza pre y post

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup_orphaned_resources.sh"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Usar perfil de AWS si está especificado (por defecto o como argumento)
AWS_PROFILE="${AWS_PROFILE:-${1:-}}"
if [[ -n "$AWS_PROFILE" ]]; then
    export AWS_PROFILE
    log_info "Usando perfil AWS: $AWS_PROFILE"
fi

# Función para ejecutar limpieza
run_cleanup() {
    log_info "Ejecutando limpieza de recursos huérfanos..."
    if bash "$CLEANUP_SCRIPT"; then
        log_info "Limpieza completada exitosamente"
    else
        log_warn "Limpieza completada con advertencias (continuando...)"
    fi
}

# Función para ejecutar tests
run_tests() {
    log_info "Ejecutando tests de Terratest..."
    cd "$PROJECT_ROOT/test"
    
    # Ejecutar tests con salida en tiempo real
    # -v: verbose, -count=1: sin cache, -p=1: sin paralelismo para ver salida ordenada
    if go test -v -count=1 -p=1 -timeout 30m ./...; then
        log_info "Tests completados exitosamente"
        return 0
    else
        log_error "Tests fallaron"
        return 1
    fi
}

# Función principal
main() {
    local test_result=0
    
    # Limpieza pre-test
    log_info "=== Limpieza Pre-Test ==="
    run_cleanup
    
    # Ejecutar tests
    log_info "=== Ejecutando Tests ==="
    if ! run_tests; then
        test_result=1
    fi
    
    # Limpieza post-test (siempre ejecutar, incluso si fallan los tests)
    log_info "=== Limpieza Post-Test ==="
    run_cleanup
    
    # Retornar código de salida apropiado
    if [[ $test_result -eq 0 ]]; then
        log_info "=== Todos los tests pasaron ==="
        exit 0
    else
        log_error "=== Algunos tests fallaron ==="
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
