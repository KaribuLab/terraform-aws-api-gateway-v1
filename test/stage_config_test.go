package test

import (
	"testing"

	"github.com/KaribuLab/terraform-aws-api-gateway-v1/test/helpers"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestStageConfig(t *testing.T) {
	t.Parallel()

	region := helpers.GetAWSRegion()
	testName := helpers.GenerateTestName("test-api-gateway-stage-config")
	commonTags := helpers.GetCommonTags()

	terraformOptions := helpers.TerraformOptionsWithVars(
		"fixtures/stage_config",
		region,
		map[string]interface{}{
			"api_name":             testName,
			"stage_name":           "test",
			"cache_cluster_enabled": false,
			"tags":                 commonTags,
		},
	)

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validar outputs del módulo con stage_config
	restAPIID := terraform.Output(t, terraformOptions, "rest_api_id")
	stageName := terraform.Output(t, terraformOptions, "stage_name")
	stageARN := terraform.Output(t, terraformOptions, "stage_arn")
	invokeURL := terraform.Output(t, terraformOptions, "invoke_url")

	// Validaciones
	assert.NotEmpty(t, restAPIID, "rest_api_id should not be empty")
	assert.Equal(t, "test", stageName, "stage_name should be 'test'")
	assert.NotEmpty(t, stageARN, "stage_arn should not be empty when stage is created by module")
	assert.NotEmpty(t, invokeURL, "invoke_url should not be empty when stage is created by module")
	assert.Contains(t, invokeURL, restAPIID, "invoke_url should contain rest_api_id")
	assert.Contains(t, invokeURL, "test", "invoke_url should contain stage name")

	require.NotNil(t, stageName)
	require.NotNil(t, stageARN)
	require.NotNil(t, invokeURL)
}
