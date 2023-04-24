output "result_bucket_name" {
  value = aws_s3_bucket.result_bucket.bucket
}

output "input_bucket_name" {
  value = aws_s3_bucket.input_bucket.bucket
}

output "inventory_name" {
  value = aws_s3_bucket_inventory.input_bucket_inventory.name
}

output "result_bucket_id" {
  value = aws_s3_bucket.result_bucket.id
}