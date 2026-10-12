output "terraform_bucket" {
  description = "Name of the S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.terraform-backend.id
}
output "lock_table" {
  description = "Name of the DynamoDB table used for state locking."
  value       = aws_dynamodb_table.tf-lock.name
}
output "key_arn" {
  description = "ARN of the KMS key that encrypts the state bucket and lock table."
  value       = aws_kms_key.tf-state-key.arn
}
