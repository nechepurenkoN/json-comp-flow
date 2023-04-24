provider "aws" {
  region = "eu-central-1"
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

module "s3" {
  source = "./s3"
}

module "iam" {
  source = "./iam"
}

resource "aws_lambda_function" "generator" {
  function_name = "json_generator"
  role          = module.iam.lambda_role_arn

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
  role          = module.iam.lambda_role_arn

  handler = "comparator.handle"
  runtime = "python3.8"

  filename         = data.archive_file.comparator_lambda_archive.output_path
  source_code_hash = data.archive_file.comparator_lambda_archive.output_base64sha256

  environment {
    variables = {}
  }
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = "state_machine"
  role_arn = module.iam.step_func_arn

  definition = templatefile("sf.json", {
    generator_arn  = aws_lambda_function.generator.arn,
    comparator_arn = aws_lambda_function.comparator.arn,
    result_bucket  = module.s3.result_bucket_name,
    input_bucket   = module.s3.input_bucket_name,
    inventory_name = module.s3.inventory_name,
    manifest_date  = "2023-04-09T01-00Z"
  })
}

resource "aws_athena_database" "json_comp_results_db" {
  name   = "json_comp_results"
  bucket = module.s3.result_bucket_id
}

resource "aws_athena_workgroup" "json_comp_results_db_wg" {
  name = "json_comp_athena_wg"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${module.s3.result_bucket_name}/athena/"
    }
  }
}

resource "aws_athena_named_query" "view_query" {
  name     = "view_query"
  database = aws_athena_database.json_comp_results_db.name
  query    = templatefile("athena_query.sql", {
    result_bucket = module.s3.result_bucket_name,
    run_id_path   = "2023-04-10T17:10:44.269Z/3334173f-138e-3faa-aeae-9d715fc2f3b2"
  })
  workgroup = aws_athena_workgroup.json_comp_results_db_wg.name
}