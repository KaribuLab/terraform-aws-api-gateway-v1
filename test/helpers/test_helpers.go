package helpers

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

const (
	RepositoryTag  = "github.com/KaribuLab/terraform-aws-api-gateway-v1"
	TerratestTag   = "true"
	ManagedByTag   = "terratest"
	EnvironmentTag = "test"
)

// GetCommonTags retorna los tags estándar para todos los recursos de prueba
func GetCommonTags() map[string]string {
	return map[string]string{
		"terratest":   TerratestTag,
		"repository":  RepositoryTag,
		"managed_by":  ManagedByTag,
		"environment": EnvironmentTag,
	}
}

// GetAWSRegion obtiene la región de AWS desde variables de entorno o usa una por defecto
func GetAWSRegion() string {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = os.Getenv("AWS_DEFAULT_REGION")
	}
	if region == "" {
		region = "us-east-1"
	}
	return region
}

// GenerateTestName genera un nombre único para recursos de prueba
func GenerateTestName(baseName string) string {
	uniqueID := strings.ToLower(random.UniqueId())
	return fmt.Sprintf("%s-%s", baseName, uniqueID)
}

// TerraformOptionsWithDefaults crea opciones de Terraform con valores por defecto
func TerraformOptionsWithDefaults(terraformDir string, region string) *terraform.Options {
	return &terraform.Options{
		TerraformDir: terraformDir,
		NoColor:      false,
		Vars: map[string]interface{}{
			"aws_region": region,
		},
	}
}

// TerraformOptionsWithVars crea opciones de Terraform con variables adicionales
func TerraformOptionsWithVars(terraformDir string, region string, vars map[string]interface{}) *terraform.Options {
	options := TerraformOptionsWithDefaults(terraformDir, region)
	for k, v := range vars {
		options.Vars[k] = v
	}
	return options
}

// ValidateTags valida que los tags están presentes en un recurso
func ValidateTags(t *testing.T, tags map[string]*string, expectedTags map[string]string) {
	for key, expectedValue := range expectedTags {
		actualValue, exists := tags[key]
		require.True(t, exists, "Tag '%s' should exist", key)
		require.NotNil(t, actualValue, "Tag '%s' should not be nil", key)
		require.Equal(t, expectedValue, *actualValue, "Tag '%s' should equal '%s'", key, expectedValue)
	}
}

// WaitForAPIGatewayDeployment espera a que un deployment esté listo
func WaitForAPIGatewayDeployment(t *testing.T, region string, apiID string, maxRetries int) {
	for i := 0; i < maxRetries; i++ {
		// Simple wait - en producción podrías verificar el estado del deployment
		time.Sleep(5 * time.Second)
		if i == maxRetries-1 {
			t.Fatalf("API Gateway deployment not ready after %d retries", maxRetries)
		}
	}
}
