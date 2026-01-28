package test

import (
	"testing"

	"github.com/KaribuLab/terraform-aws-api-gateway-v1/test/helpers"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestWAF(t *testing.T) {
	t.Parallel()

	region := helpers.GetAWSRegion()
	testName := helpers.GenerateTestName("test-api-gateway-waf")
	commonTags := helpers.GetCommonTags()

	terraformOptions := helpers.TerraformOptionsWithVars(
		"fixtures/waf",
		region,
		map[string]interface{}{
			"api_name":     testName,
			"web_acl_name": testName + "-waf",
			"tags":         commonTags,
		},
	)

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validar outputs
	restAPIID := terraform.Output(t, terraformOptions, "rest_api_id")
	stageName := terraform.Output(t, terraformOptions, "stage_name")
	stageARN := terraform.Output(t, terraformOptions, "stage_arn")
	invokeURL := terraform.Output(t, terraformOptions, "invoke_url")
	webACLARN := terraform.Output(t, terraformOptions, "web_acl_arn")

	// Validaciones
	assert.NotEmpty(t, restAPIID, "rest_api_id should not be empty")
	assert.Equal(t, "test", stageName, "stage_name should be 'test'")
	assert.NotEmpty(t, stageARN, "stage_arn should not be empty when stage is created")
	assert.NotEmpty(t, invokeURL, "invoke_url should not be empty when stage is created")
	assert.Contains(t, invokeURL, restAPIID, "invoke_url should contain rest_api_id")
	assert.Contains(t, invokeURL, "test", "invoke_url should contain stage name")
	assert.NotEmpty(t, webACLARN, "web_acl_arn should not be empty")
	assert.Contains(t, webACLARN, "wafv2", "web_acl_arn should contain 'wafv2'")

	require.NotNil(t, stageName)
	require.NotNil(t, stageARN)
	require.NotNil(t, invokeURL)
	require.NotNil(t, webACLARN)
}
