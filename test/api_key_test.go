package test

import (
	"testing"

	"github.com/KaribuLab/terraform-aws-api-gateway-v1/test/helpers"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAPIKey(t *testing.T) {
	t.Parallel()

	region := helpers.GetAWSRegion()
	testName := helpers.GenerateTestName("test-api-gateway-apikey")
	commonTags := helpers.GetCommonTags()

	terraformOptions := helpers.TerraformOptionsWithVars(
		"fixtures/api_key",
		region,
		map[string]interface{}{
			"api_name":        testName,
			"api_key_name":    testName + "-key",
			"usage_plan_name": testName + "-plan",
			"tags":            commonTags,
		},
	)

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Validar outputs
	restAPIID := terraform.Output(t, terraformOptions, "rest_api_id")
	apiKeyID := terraform.Output(t, terraformOptions, "api_key_id")
	apiKeyValue := terraform.Output(t, terraformOptions, "api_key_value")
	usagePlanID := terraform.Output(t, terraformOptions, "usage_plan_id")

	// Validaciones
	assert.NotEmpty(t, restAPIID, "rest_api_id should not be empty")
	assert.NotEmpty(t, apiKeyID, "api_key_id should not be empty")
	assert.NotEmpty(t, apiKeyValue, "api_key_value should not be empty")
	assert.NotEmpty(t, usagePlanID, "usage_plan_id should not be empty")

	require.NotNil(t, apiKeyID)
	require.NotNil(t, apiKeyValue)
	require.NotNil(t, usagePlanID)
}
