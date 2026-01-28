package test

import (
	"testing"

	"github.com/KaribuLab/terraform-aws-api-gateway-v1/test/helpers"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBasicAPIGateway(t *testing.T) {
	t.Parallel()

	region := helpers.GetAWSRegion()
	testName := helpers.GenerateTestName("test-api-gateway-basic")
	commonTags := helpers.GetCommonTags()

	terraformOptions := helpers.TerraformOptionsWithVars(
		"fixtures/basic",
		region,
		map[string]interface{}{
			"api_name":        testName,
			"api_description": "Basic API Gateway test",
			"tags":            commonTags,
		},
	)

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validar outputs
	restAPIID := terraform.Output(t, terraformOptions, "rest_api_id")
	rootResourceID := terraform.Output(t, terraformOptions, "rest_api_root_resource_id")

	// Validaciones básicas
	assert.NotEmpty(t, restAPIID, "rest_api_id should not be empty")
	assert.NotEmpty(t, rootResourceID, "rest_api_root_resource_id should not be empty")

	require.NotNil(t, restAPIID)
	require.NotNil(t, rootResourceID)
}
