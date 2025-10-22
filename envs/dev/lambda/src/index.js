exports.handler = async (event) => {
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,OPTIONS'
        },
        body: JSON.stringify({
            message: 'Hello venkata welcome to lambda deployment',
            timestamp: new Date().toISOString(),
            environment: process.env.ENVIRONMENT || 'dev',
            requestId: event.requestContext?.requestId || 'unknown'
        })
    };
    return response;
};
