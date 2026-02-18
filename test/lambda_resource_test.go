package test

import (
	"testing"

	"github.com/KaribuLab/terraform-aws-api-gateway-v1/test/helpers"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLambdaResourceModule(t *testing.T) {
	t.Parallel()

	region := helpers.GetAWSRegion()
	testName := helpers.GenerateTestName("test-lambda-resource")
	commonTags := helpers.GetCommonTags()

	terraformOptions := helpers.TerraformOptionsWithVars(
		"fixtures/lambda_resource",
		region,
		map[string]interface{}{
			"api_name":             testName,
			"lambda_function_name": testName + "-lambda",
			"tags":                 commonTags,
		},
	)

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	restAPIID := terraform.Output(t, terraformOptions, "rest_api_id")
	assert.NotEmpty(t, restAPIID, "rest_api_id should not be empty")

	stageInvokeURL := terraform.Output(t, terraformOptions, "stage_invoke_url")
	assert.NotEmpty(t, stageInvokeURL, "stage_invoke_url should not be empty")
	assert.Contains(t, stageInvokeURL, restAPIID, "stage_invoke_url should contain rest_api_id")

	lambdaFunctionName := terraform.Output(t, terraformOptions, "lambda_function_name")
	lambdaFunctionARN := terraform.Output(t, terraformOptions, "lambda_function_arn")

	assert.NotEmpty(t, lambdaFunctionName, "lambda_function_name should not be empty")
	assert.NotEmpty(t, lambdaFunctionARN, "lambda_function_arn should not be empty")
	assert.Contains(t, lambdaFunctionARN, lambdaFunctionName, "lambda_function_arn should contain function name")

	require.NotNil(t, lambdaFunctionName)
	require.NotNil(t, lambdaFunctionARN)
}
