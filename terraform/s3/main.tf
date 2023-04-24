provider "aws" {
  region = "eu-central-1"
}

locals {
  input_jsons  = yamldecode(file("files.yml"))["input"]
  source_jsons = yamldecode(file("files.yml"))["source"]
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