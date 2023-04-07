provider "aws" {
  region = "eu-central-1"
}

locals {
  input_jsons  = yamldecode(file("files.yml"))["input"]
  source_jsons = yamldecode(file("files.yml"))["source"]
}

data "archive_file" "generator_lambda_archive" {
  output_path = "lambda_generator.zip"
  source_file = "../lambda/generator.py"
  type        = "zip"
}

data "archive_file" "comparator_lambda_archive" {
  output_path = "lambda_comparator.zip"
  source_file = "../lambda/comparator.py"
  type        = "zip"
}

resource "aws_s3_bucket" "input_bucket" {
  bucket = "nechn-json-comp-flow-input-bucket"
}

resource "aws_s3_bucket" "source_bucket" {
  bucket = "nechn-json-comp-flow-source-bucket"
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