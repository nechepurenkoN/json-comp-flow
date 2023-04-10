import boto3
import json
# from deepdiff import DeepDiff


def handle(event, context):
    s3 = boto3.resource('s3')
    result = []
    for item in event['Payload']:
        source_id = item['id']
        obj = s3.Object("nechn-json-comp-flow-source-bucket", f"source/source{source_id}.json")
        content = json.loads(obj.get()['Body'].read().decode('utf-8'))

        #     diff = DeepDiff(event, content, ignore_order=True)
        diff = content["props"]["prop1"] if content["props"]["prop1"] != item["props"]["prop1"] else None
        if diff:
            result.append({"filename": f"result{source_id}", "delta": diff})
            
    print("Compare result:", result)
    return result
