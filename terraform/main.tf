provider "aws" {
  region = "eu-central-1"
}

locals {
  input_jsons = yamldecode(file("files.yml"))["input"]
  source_jsons = yamldecode(file("files.yml"))["source"]
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
  key    = format("subfolder/%s", each.value.name)
  source = format("../json/%s", each.value.name)
}

resource "aws_s3_object" "source_object" {
  for_each = {for source_object in local.source_jsons : source_object.name => source_object}

  bucket = aws_s3_bucket.source_bucket.bucket
  key    = format("source/%s", each.value.name)
  source = format("../json/%s", each.value.name)
}

