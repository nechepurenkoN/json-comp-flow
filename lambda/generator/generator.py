import boto3
import json


def handle(event, context):
    s3 = boto3.resource('s3')

    event_id = event["id"]
    obj = s3.Object("nechn-json-comp-flow-input-bucket", f"input/input{event_id}.json")
    content = json.loads(obj.get()['Body'].read().decode('utf-8'))

    return {
        "id": event_id,
        "props": {
            "prop1": content["input"],
            "prop2": "val2",
            "prop3": "val3"
        }
    }
