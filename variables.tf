variable "organization" {
  type        = string
  description = "Organization name, used as the prefix of the state bucket name."
}
variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, prod), included in the state bucket name."
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
