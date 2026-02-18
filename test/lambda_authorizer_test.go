package test

import (
	"testing"

	"github.com/KaribuLab/terraform-aws-api-gateway-v1/test/helpers"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLambdaAuthorizer(t *testing.T) {
	t.Parallel()

	region := helpers.GetAWSRegion()
	testName := helpers.GenerateTestName("test-api-gateway-lambda-auth")
	commonTags := helpers.GetCommonTags()

	terraformOptions := helpers.TerraformOptionsWithVars(
		"fixtures/lambda_authorizer",
		region,
		map[string]interface{}{
			"api_name":             testName,
			"lambda_function_name": testName + "-authorizer",
			"authorizer_name":      testName + "-auth",
			"tags":                 commonTags,
		},
	)

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	restAPIID := terraform.Output(t, terraformOptions, "rest_api_id")
	stageInvokeURL := terraform.Output(t, terraformOptions, "stage_invoke_url")
	lambdaARN := terraform.Output(t, terraformOptions, "lambda_function_arn")

	assert.NotEmpty(t, restAPIID, "rest_api_id should not be empty")
	assert.NotEmpty(t, stageInvokeURL, "stage_invoke_url should not be empty")
	assert.NotEmpty(t, lambdaARN, "lambda_function_arn should not be empty")
	assert.Contains(t, lambdaARN, "lambda", "lambda_function_arn should contain 'lambda'")

	require.NotNil(t, stageInvokeURL)
	require.NotNil(t, lambdaARN)
}
