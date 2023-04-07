import boto3


def handle(event, context):
    s3 = boto3.resource('s3')

    obj = s3.Object("nechn-json-comp-flow-input-bucket", f"input/input{event['id']}.json")
    content = obj.get()['Body'].read().decode('utf-8')

    return {
        "id": event["id"],
        "props": {
            "prop1": content["input"],
            "prop2": "val2",
            "prop3": "val3"
        }
    }
