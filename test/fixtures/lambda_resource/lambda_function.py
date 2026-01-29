def lambda_handler(event, context):
    """
    Lambda function de prueba para Terratest
    """
    return {
        'statusCode': 200,
        'body': '{"message": "Hello from Lambda!"}'
    }
