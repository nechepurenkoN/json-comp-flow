import boto3

def handle(event, context):
    s3 = boto3.resource('s3')

    obj = s3.Object("nechn-json-comp-flow-input-bucket", event["key"])
    content = obj.get()['Body'].read().decode('utf-8')

    return {
        "id": 0,
        "props": {"prop1": content}
    }