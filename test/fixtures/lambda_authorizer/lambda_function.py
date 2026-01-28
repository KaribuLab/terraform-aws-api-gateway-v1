import json

def lambda_handler(event, context):
    """
    Lambda authorizer simple para pruebas.
    Retorna una política que permite el acceso si el token es válido.
    """
    token = event.get('authorizationToken', '')
    
    # Autorización simple para pruebas
    if token == 'allow':
        policy = {
            'principalId': 'user123',
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [
                    {
                        'Action': 'execute-api:Invoke',
                        'Effect': 'Allow',
                        'Resource': event.get('methodArn', '*')
                    }
                ]
            }
        }
        return policy
    else:
        # Denegar acceso
        raise Exception('Unauthorized')
