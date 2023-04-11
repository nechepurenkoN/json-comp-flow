from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from pyspark.context import SparkContext
from awsglue.job import Job

glueContext = GlueContext(SparkContext.getOrCreate())

# create a dynamic frame from an S3 object using options
dyf = DynamicFrame.from_options(
    connection_type="s3",
    connection_options={
        "path": "s3://nechn-json-comp-flow-result-bucket/2023-04-11T10:35:17.083Z/a4bd5a53-9049-34fa-8d42-083f448851d7/SUCCEEDED_0.json",
        "recurse": True
    },
    format="json",
    format_options={
        "jsonPath": "$[*]"
    }
)

# print the schema of the dynamic frame
print(dyf.schema())
