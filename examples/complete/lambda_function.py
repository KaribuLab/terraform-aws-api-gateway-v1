def lambda_handler(event, context):
    """
    Lambda function de ejemplo para el API Gateway.
    En producción, reemplaza esto con tu lógica real.
    """
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': '{"message": "Hello from Lambda!"}'
    }
