output "terraform_bucket" {
  value = aws_s3_bucket.terraform-backend.id
}
output "lock_table" {
  value = aws_dynamodb_table.tf-lock.name
}
output "key_arn" {
  value = aws_kms_key.tf-state-key.arn
}
