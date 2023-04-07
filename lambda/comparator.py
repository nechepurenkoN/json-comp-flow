# import boto3
# import json


def handle(event, context):
    print(event)
    return '{"delta": {}}'
    # return json.dumps({
    #     "delta": {}
    # })
