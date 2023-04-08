import boto3
from deepdiff import DeepDiff


def handle(event, context):
    s3 = boto3.resource('s3')

    obj = s3.Object("nechn-json-comp-flow-source-bucket", f"source/source{event['id']}.json")
    content = obj.get()['Body'].read().decode('utf-8')

    diff = DeepDiff(event, content, ignore_order=True)
    if diff:
        return {"filename": f"result{event['id']}", "delta": diff}

