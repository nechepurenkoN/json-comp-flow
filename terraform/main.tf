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

resource "aws_iam_role_policy_attachment" "lambda_basic_exec_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
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

resource "aws_iam_policy_attachment" "step_functions_start_execution_policy_attachment" {
  name       = "step_functions_start_execution_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
  roles      = [aws_iam_role.step_functions_role.name]
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = "state_machine"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("sf.json", {
    generator_arn  = aws_lambda_function.generator.arn,
    comparator_arn = aws_lambda_function.comparator.arn,
    result_bucket  = aws_s3_bucket.result_bucket.bucket,
    input_bucket   = aws_s3_bucket.input_bucket.bucket,
    inventory_name = aws_s3_bucket_inventory.input_bucket_inventory.name,
    manifest_date  = "2023-04-09T01-00Z"
  })
}

resource "aws_iam_role" "glue_role" {
  name = "glue_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_cloudwatch_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.glue_role.name
}

resource "aws_iam_role_policy_attachment" "glue_fa_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  role       = aws_iam_role.glue_role.name
}

resource "aws_s3_bucket" "glue_jobs_bucket" {
  bucket = "nechn-glue-jobs-bucket"
}

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.glue_jobs_bucket.bucket
  key    = "glue/transform_to_jsonl.py"
  source = "../glue/transform_to_jsonl.py"
}

resource "aws_glue_job" "convert_to_jsonl" {
  name              = "convert_to_jsonl"
  role_arn          = aws_iam_role.glue_role.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.glue_jobs_bucket.id}/${aws_s3_object.glue_script.key}"
  }
  default_arguments = {
    "--job-language" = "python",
  }
}

resource "aws_athena_database" "json_comp_results_db" {
  name   = "json_comp_results"
  bucket = aws_s3_bucket.result_bucket.id
}

resource "aws_athena_workgroup" "json_comp_results_db_wg" {
  name = "json_comp_athena_wg"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.result_bucket.bucket}/athena/"
    }
  }
}

resource "aws_athena_named_query" "view_query" {
  name     = "view_query"
  database = aws_athena_database.json_comp_results_db.name
  query    = templatefile("athena_query.sql", {
    result_bucket = aws_s3_bucket.result_bucket.bucket,
    run_id_path   = "2023-04-10T17:10:44.269Z/3334173f-138e-3faa-aeae-9d715fc2f3b2"
  })
  workgroup = aws_athena_workgroup.json_comp_results_db_wg.name
}

resource "aws_iam_policy_attachment" "s3_role_policy_attachment" {
  name       = "s3_fa_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  roles      = [aws_iam_role.lambda_s3_role.name, aws_iam_role.step_functions_role.name]
}