import boto3
import json


def handle(event, context):
    s3 = boto3.resource('s3')
    return [s3_key_to_source_item(s3, file_key=item['input_file']['Key'])
            for item in event['Items']]


def s3_key_to_source_item(s3, file_key):
    obj = s3.Object("nechn-json-comp-flow-input-bucket", file_key)
    content = json.loads(obj.get()['Body'].read().decode('utf-8'))
    return {
        "id": file_key.split('input/input')[-1][:-5],
        "props": {
            "prop1": content["input"],
            "prop2": "val2",
            "prop3": "val3"
        }
    }
