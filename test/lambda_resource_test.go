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

	// Validar outputs del API Gateway
	restAPIID := terraform.Output(t, terraformOptions, "rest_api_id")
	assert.NotEmpty(t, restAPIID, "rest_api_id should not be empty")

	// Validar outputs del módulo parent (recurso compartido)
	usersResourceID := terraform.Output(t, terraformOptions, "users_resource_id")
	usersResourcePath := terraform.Output(t, terraformOptions, "users_resource_path")

	assert.NotEmpty(t, usersResourceID, "users_resource_id should not be empty")
	assert.Equal(t, "/users", usersResourcePath, "users_resource_path should be '/users'")

	require.NotNil(t, usersResourceID)
	require.NotNil(t, usersResourcePath)

	// Validar outputs del módulo users_get (GET /users)
	usersGetResourceID := terraform.Output(t, terraformOptions, "users_get_resource_id")
	usersGetMethodID := terraform.Output(t, terraformOptions, "users_get_method_id")

	assert.NotEmpty(t, usersGetResourceID, "users_get_resource_id should not be empty")
	assert.Equal(t, usersResourceID, usersGetResourceID, "users_get_resource_id should match users_resource_id")
	assert.NotEmpty(t, usersGetMethodID, "users_get_method_id should not be empty")

	require.NotNil(t, usersGetResourceID)
	require.NotNil(t, usersGetMethodID)

	// Validar outputs del módulo users_post (POST /users con CORS)
	usersPostResourceID := terraform.Output(t, terraformOptions, "users_post_resource_id")

	assert.NotEmpty(t, usersPostResourceID, "users_post_resource_id should not be empty")
	assert.Equal(t, usersResourceID, usersPostResourceID, "users_post_resource_id should match users_resource_id")

	require.NotNil(t, usersPostResourceID)

	// Validar Lambda
	lambdaFunctionName := terraform.Output(t, terraformOptions, "lambda_function_name")
	lambdaFunctionARN := terraform.Output(t, terraformOptions, "lambda_function_arn")

	assert.NotEmpty(t, lambdaFunctionName, "lambda_function_name should not be empty")
	assert.NotEmpty(t, lambdaFunctionARN, "lambda_function_arn should not be empty")
	assert.Contains(t, lambdaFunctionARN, lambdaFunctionName, "lambda_function_arn should contain function name")

	require.NotNil(t, lambdaFunctionName)
	require.NotNil(t, lambdaFunctionARN)
}
