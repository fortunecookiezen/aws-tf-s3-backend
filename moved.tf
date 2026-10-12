# Resource addresses renamed in v3.2.0. These keep existing backends from
# being destroyed and recreated on upgrade; do not remove them.

moved {
  from = aws_s3_bucket.terraform-backend
  to   = aws_s3_bucket.terraform_backend
}

moved {
  from = aws_kms_key.tf-state-key
  to   = aws_kms_key.tf_state_key
}

moved {
  from = aws_kms_alias.tf-state-key
  to   = aws_kms_alias.tf_state_key
}

# also gained count (create_lock_table) in v3.2.0
moved {
  from = aws_dynamodb_table.tf-lock
  to   = aws_dynamodb_table.tf_lock[0]
}
