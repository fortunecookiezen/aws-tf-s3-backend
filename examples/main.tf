module "backend" {
  source       = "git::https://github.com/fortunecookiezen/aws-tf-s3-backend.git?ref=v3.2.0"
  organization = "demo"
  environment  = "test"
  tags = {
    Organization = "demo"
    Environment  = "test"
  }

  # Optional settings, shown with their defaults
  create_lock_table                  = true # false when using S3 native locking
  lock_table_name                    = null # terraform-lock-table-<region>
  kms_alias_name                     = "alias/tf-state-key"
  noncurrent_version_expiration_days = 30
  noncurrent_versions_to_retain      = 10
}

# Values for the backend "s3" block of configurations that store state here
output "backend_config" {
  value = module.backend.backend_config
}
