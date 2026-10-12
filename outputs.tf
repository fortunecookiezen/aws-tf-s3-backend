output "terraform_bucket" {
  description = "Name of the S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.terraform_backend.id
}
output "terraform_bucket_arn" {
  description = "ARN of the S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.terraform_backend.arn
}
output "lock_table" {
  description = "Name of the DynamoDB table used for state locking, or null when create_lock_table is false."
  value       = one(aws_dynamodb_table.tf_lock[*].name)
}
output "lock_table_arn" {
  description = "ARN of the DynamoDB table used for state locking, or null when create_lock_table is false."
  value       = one(aws_dynamodb_table.tf_lock[*].arn)
}
output "key_arn" {
  description = "ARN of the KMS key that encrypts the state bucket and lock table."
  value       = aws_kms_key.tf_state_key.arn
}
output "backend_config" {
  description = "Settings for an S3 backend block that uses this backend. Add your own key. Uses DynamoDB locking when the lock table is created, otherwise S3 native locking (Terraform 1.10+)."
  value = merge(
    {
      bucket     = aws_s3_bucket.terraform_backend.bucket
      region     = data.aws_region.current.region
      encrypt    = true
      kms_key_id = aws_kms_key.tf_state_key.arn
    },
    var.create_lock_table ? { dynamodb_table = aws_dynamodb_table.tf_lock[0].name } : { use_lockfile = true },
  )
}
