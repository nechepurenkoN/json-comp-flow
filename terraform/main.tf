provider "aws" {
  region = "eu-central-1"
}

locals {
  input_jsons  = yamldecode(file("files.yml"))["input"]
  source_jsons = yamldecode(file("files.yml"))["source"]
}

data "archive_file" "generator_lambda_archive" {
  output_path = "lambda_generator.zip"
  source_dir  = "../lambda/generator"
  type        = "zip"
}

data "archive_file" "comparator_lambda_archive" {
  output_path = "lambda_comparator.zip"
  source_dir  = "../lambda/comparator"
  type        = "zip"
}

resource "aws_s3_bucket" "input_bucket" {
  bucket = "nechn-json-comp-flow-input-bucket"
}

resource "aws_s3_bucket" "source_bucket" {
  bucket = "nechn-json-comp-flow-source-bucket"
}

resource "aws_s3_bucket" "result_bucket" {
  bucket = "nechn-json-comp-flow-result-bucket"
}

resource "aws_s3_bucket_ownership_controls" "input_bucket_oc" {
  bucket = aws_s3_bucket.input_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "input_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.input_bucket_oc]

  bucket = aws_s3_bucket.input_bucket.id
  acl    = "private"
}

resource "aws_s3_object" "input_object" {
  for_each = {for input_object in local.input_jsons : input_object.name => input_object}

  bucket = aws_s3_bucket.input_bucket.bucket
  key    = format("input/%s", each.value.name)
  source = format("../json/%s", each.value.name)
}

resource "aws_s3_object" "source_object" {
  for_each = {for source_object in local.source_jsons : source_object.name => source_object}

  bucket = aws_s3_bucket.source_bucket.bucket
  key    = format("source/%s", each.value.name)
  source = format("../json/%s", each.value.name)
}

resource "aws_s3_bucket_inventory" "input_bucket_inventory" {
  bucket = aws_s3_bucket.input_bucket.id
  name   = "input_json_daily_inventory"

  included_object_versions = "Current"

  schedule {
    frequency = "Daily"
  }

  filter {
    prefix = "input/"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = aws_s3_bucket.input_bucket.arn
      prefix     = "inventory"
    }
  }
}

resource "aws_s3_bucket_policy" "inventory_input_policy" {
  bucket = aws_s3_bucket.input_bucket.bucket

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3ToWriteObjects"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.input_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_s3_role" {
  name = "lambda_s3_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.lambda_s3_role.name
}

resource "aws_lambda_function" "generator" {
  function_name = "json_generator"
  role          = aws_iam_role.lambda_s3_role.arn

  handler = "generator.handle"
  runtime = "python3.8"

  filename         = data.archive_file.generator_lambda_archive.output_path
  source_code_hash = data.archive_file.generator_lambda_archive.output_base64sha256

  environment {
    variables = {}
  }
}

resource "aws_lambda_function" "comparator" {
  function_name = "json_comparator"
  role          = aws_iam_role.lambda_s3_role.arn

  handler = "comparator.handle"
  runtime = "python3.8"

  filename         = data.archive_file.comparator_lambda_archive.output_path
  source_code_hash = data.archive_file.comparator_lambda_archive.output_base64sha256

  environment {
    variables = {}
  }
}

resource "aws_iam_role" "step_functions_role" {
  name = "step_functions_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "step_functions_lambda_policy_attachment" {
  name       = "step_functions_lambda_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
  roles      = [aws_iam_role.step_functions_role.name]
}

resource "aws_iam_policy_attachment" "step_functions_s3_policy_attachment" {
  name       = "step_functions_s3_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  roles      = [aws_iam_role.step_functions_role.name]
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = "state_machine"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("sf.json", {
    generator_arn  = aws_lambda_function.generator.arn,
    comparator_arn = aws_lambda_function.comparator.arn,
    result_bucket  = aws_s3_bucket.result_bucket.arn
  })
}


#resource "aws_iam_role" "s3_batch_role" {
#  name = "s3_batch_role"
#
#  assume_role_policy = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Action = "sts:AssumeRole"
#        Effect = "Allow"
#        Principal = {
#          Service = "batchoperations.s3.amazonaws.com"
#        }
#      }
#    ]
#  })
#}
#
#resource "aws_s3_bucket" "batch_job_bucket" {
#  bucket = "batch_job_bucket"
#}
#
#resource "aws_s3_bucket_object" "batch_job_manifest" {
#  bucket = aws_s3_bucket.batch_job_bucket.id
#  key    = "manifest.json"
#  source = "path/to/manifest.json"
#}
#
#resource "aws_s3_bucket_notification" "batch_job_notification" {
#  bucket = aws_s3_bucket.batch_job_bucket.id
#
#  lambda_function {
#    lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:batch_job_function"
#    events              = ["s3:ObjectCreated:*"]
#    filter_prefix       = "batch/"
#  }
#}
#
#resource "aws_s3control_job" "s3_batch_job" {
#  name        = "s3_batch_job"
#  description = "An example S3 batch job"
#  role_arn    = aws_iam_role.s3_batch_role.arn
#  priority    = 1
#  report {
#    bucket = aws_s3_bucket.batch_job_bucket.id
#    format = "Report_CSV_20180820"
#    enabled = true
#    prefix = "reports/"
#    report_scope {
#      include_governance_events = false
#    }
#  }
#  manifest {
#    spec = jsonencode({
#      "Format": "S3BatchOperations_CSV_20180820",
#      "Bucket": aws_s3_bucket.batch_job_bucket.id,
#      "Key": aws_s3_bucket_object.batch_job_manifest.id
#    })
#  }
#}
