variable "organization" {
  type        = string
  description = "Organization name, used as the prefix of the state bucket name. Lowercase letters, digits and hyphens."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.organization))
    error_message = "organization must contain only lowercase letters, digits and hyphens, and must start and end with a letter or digit."
  }
}
variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, prod), included in the state bucket name. Lowercase letters, digits and hyphens."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.environment))
    error_message = "environment must contain only lowercase letters, digits and hyphens, and must start and end with a letter or digit."
  }
}
variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources. A Name tag set here is overridden per resource."
  default     = {}
}
variable "kms_alias_name" {
  type        = string
  description = "Name of the KMS key alias. Set a unique value to deploy more than one backend per account and region."
  default     = "alias/tf-state-key"

  validation {
    condition     = startswith(var.kms_alias_name, "alias/") && !startswith(var.kms_alias_name, "alias/aws/")
    error_message = "kms_alias_name must start with \"alias/\" and must not start with the reserved \"alias/aws/\" prefix."
  }
}
variable "lock_table_name" {
  type        = string
  description = "Name of the DynamoDB lock table. Defaults to terraform-lock-table-<region>. Set a unique value to deploy more than one backend per account and region."
  default     = null
}
variable "create_lock_table" {
  type        = bool
  description = "Create a DynamoDB table for state locking. Set to false when using S3 native locking (use_lockfile = true, Terraform 1.10+)."
  default     = true
}
variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Days to keep noncurrent versions of state files before they expire. Old versions are how you recover a corrupted state file."
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1 && floor(var.noncurrent_version_expiration_days) == var.noncurrent_version_expiration_days
    error_message = "noncurrent_version_expiration_days must be a whole number of at least 1."
  }
}
variable "noncurrent_versions_to_retain" {
  type        = number
  description = "Number of noncurrent versions of each state file to keep regardless of age, so a rarely changed state keeps its backups. Set to null to expire purely by age."
  default     = 10

  validation {
    condition = var.noncurrent_versions_to_retain == null ? true : (
      var.noncurrent_versions_to_retain >= 1 &&
      var.noncurrent_versions_to_retain <= 100 &&
      floor(var.noncurrent_versions_to_retain) == var.noncurrent_versions_to_retain
    )
    error_message = "noncurrent_versions_to_retain must be null or a whole number from 1 to 100."
  }
}
