# import boto3
# import json


def handle(event, context):
    print(event)
    return '{"id": 0, "props": {}}'
    # return json.dumps({
    #     "id": 0,
    #     "props": {}
    # })
