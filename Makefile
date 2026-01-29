.PHONY: test test-basic test-auth test-security test-performance test-stage-config test-lambda-resource cleanup help

# Variables
TEST_DIR := test
SCRIPTS_DIR := scripts
CLEANUP_SCRIPT := $(SCRIPTS_DIR)/cleanup_orphaned_resources.sh
RUN_TESTS_SCRIPT := $(SCRIPTS_DIR)/run_tests.sh
AWS_PROFILE ?= $(shell echo $$AWS_PROFILE)

help: ## Mostrar esta ayuda
	@echo "Comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

test: ## Ejecutar todos los tests con limpieza pre y post
	@if [ -n "$(AWS_PROFILE)" ]; then \
		AWS_PROFILE=$(AWS_PROFILE) bash $(RUN_TESTS_SCRIPT); \
	else \
		bash $(RUN_TESTS_SCRIPT); \
	fi

test-basic: ## Ejecutar solo el test básico
	@echo "Ejecutando test básico..."
	cd $(TEST_DIR) && AWS_PROFILE=$(AWS_PROFILE) go test -v -count=1 -timeout 30m -run TestBasicAPIGateway ./...

test-auth: ## Ejecutar tests de autenticación (API Key y Lambda Authorizer)
	@echo "Ejecutando test de autenticación..."
	cd $(TEST_DIR) && AWS_PROFILE=$(AWS_PROFILE) go test -v -count=1 -timeout 30m -run "TestAPIKey|TestLambdaAuthorizer" ./...

test-security: ## Ejecutar tests de seguridad (WAF)
	@echo "Ejecutando test de seguridad..."
	cd $(TEST_DIR) && AWS_PROFILE=$(AWS_PROFILE) go test -v -count=1 -timeout 30m -run TestWAF ./...

test-performance: ## Ejecutar tests de performance (Caché y Throttling)
	@echo "Ejecutando tests de performance..."
	cd $(TEST_DIR) && AWS_PROFILE=$(AWS_PROFILE) go test -v -count=1 -timeout 30m -run "TestCache|TestThrottling" ./...

test-stage-config: ## Ejecutar test de stage_config
	@echo "Ejecutando test de stage_config..."
	cd $(TEST_DIR) && AWS_PROFILE=$(AWS_PROFILE) go test -v -count=1 -timeout 30m -run TestStageConfig ./...

test-lambda-resource: ## Ejecutar test del submódulo Lambda
	@echo "Ejecutando test del submódulo Lambda..."
	cd $(TEST_DIR) && AWS_PROFILE=$(AWS_PROFILE) go test -v -count=1 -timeout 30m -run TestLambdaResourceModule ./...

cleanup: ## Ejecutar solo la limpieza de recursos huérfanos (usa AWS_PROFILE si está configurado)
	@if [ -n "$(AWS_PROFILE)" ]; then \
		AWS_PROFILE=$(AWS_PROFILE) bash $(CLEANUP_SCRIPT); \
	else \
		bash $(CLEANUP_SCRIPT); \
	fi

test-deps: ## Instalar dependencias de Go para los tests
	@echo "Instalando dependencias..."
	@cd $(TEST_DIR) && go mod download && go mod tidy

test-format: ## Formatear código Go de los tests
	@echo "Formateando código..."
	@cd $(TEST_DIR) && go fmt ./...

test-vet: ## Ejecutar go vet en los tests
	@echo "Ejecutando go vet..."
	@cd $(TEST_DIR) && go vet ./...

test-lint: test-format test-vet ## Ejecutar todas las verificaciones de código
