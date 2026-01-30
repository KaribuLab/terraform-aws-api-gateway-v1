package test

import (
	"testing"

	"github.com/KaribuLab/terraform-aws-api-gateway-v1/test/helpers"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestStageModule(t *testing.T) {
	t.Parallel()

	region := helpers.GetAWSRegion()
	testName := helpers.GenerateTestName("test-stage-module")
	commonTags := helpers.GetCommonTags()

	terraformOptions := helpers.TerraformOptionsWithVars(
		"fixtures/stage_module",
		region,
		map[string]interface{}{
			"api_name":   testName,
			"stage_name": "test",
			"tags":       commonTags,
		},
	)

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validar outputs del API Gateway
	restAPIID := terraform.Output(t, terraformOptions, "rest_api_id")
	assert.NotEmpty(t, restAPIID, "rest_api_id should not be empty")

	// Validar outputs del módulo stage
	deploymentID := terraform.Output(t, terraformOptions, "deployment_id")
	stageName := terraform.Output(t, terraformOptions, "stage_name")
	stageARN := terraform.Output(t, terraformOptions, "stage_arn")
	invokeURL := terraform.Output(t, terraformOptions, "invoke_url")
	executionARN := terraform.Output(t, terraformOptions, "execution_arn")

	assert.NotEmpty(t, deploymentID, "deployment_id should not be empty")
	assert.Equal(t, "test", stageName, "stage_name should be 'test'")
	assert.NotEmpty(t, stageARN, "stage_arn should not be empty")
	assert.NotEmpty(t, invokeURL, "invoke_url should not be empty")
	assert.NotEmpty(t, executionARN, "execution_arn should not be empty")
	assert.Contains(t, invokeURL, restAPIID, "invoke_url should contain rest_api_id")
	assert.Contains(t, invokeURL, stageName, "invoke_url should contain stage_name")
	assert.Contains(t, executionARN, restAPIID, "execution_arn should contain rest_api_id")
	assert.Contains(t, executionARN, stageName, "execution_arn should contain stage_name")

	require.NotNil(t, deploymentID)
	require.NotNil(t, stageName)
	require.NotNil(t, stageARN)
	require.NotNil(t, invokeURL)
	require.NotNil(t, executionARN)
}

func TestStageModuleWithCacheAndThrottling(t *testing.T) {
	t.Parallel()

	region := helpers.GetAWSRegion()
	testName := helpers.GenerateTestName("test-stage-module-cache")
	commonTags := helpers.GetCommonTags()

	terraformOptions := helpers.TerraformOptionsWithVars(
		"fixtures/stage_module",
		region,
		map[string]interface{}{
			"api_name":              testName,
			"stage_name":            "test",
			"cache_cluster_enabled": true,
			"cache_cluster_size":    "0.5",
			"method_settings": map[string]interface{}{
				"*/*": map[string]interface{}{
					"throttling_burst_limit": 100,
					"throttling_rate_limit":  50,
					"caching_enabled":        true,
					"cache_ttl_in_seconds":   300,
				},
			},
			"tags": commonTags,
		},
	)

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validar que el stage se creó correctamente
	stageName := terraform.Output(t, terraformOptions, "stage_name")
	assert.Equal(t, "test", stageName, "stage_name should be 'test'")

	invokeURL := terraform.Output(t, terraformOptions, "invoke_url")
	assert.NotEmpty(t, invokeURL, "invoke_url should not be empty")

	require.NotNil(t, stageName)
	require.NotNil(t, invokeURL)
}
