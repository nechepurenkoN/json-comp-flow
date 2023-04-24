output "lambda_role_arn" {
  value = aws_iam_role.lambda_s3_role.arn
}

output "step_func_arn" {
  value = aws_iam_role.step_functions_role.arn
}