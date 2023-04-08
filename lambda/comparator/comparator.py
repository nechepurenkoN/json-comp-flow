import boto3
import json
from deepdiff import DeepDiff


def handle(event, context):
    s3 = boto3.resource('s3')

    event_id = event["id"]
    obj = json.loads(s3.Object("nechn-json-comp-flow-source-bucket", f"source/source{event_id}.json"))
    content = json.loads(obj.get()['Body'].read().decode('utf-8'))

    diff = DeepDiff(event, content, ignore_order=True)
    if diff:
        return {"filename": f"result{event_id}", "delta": diff}

