provider "aws" {
  region = "eu-central-1"
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

resource "aws_iam_policy_attachment" "s3_role_policy_attachment" {
  name       = "s3_fa_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  roles      = [aws_iam_role.lambda_s3_role.name, aws_iam_role.step_functions_role.name]
}