# aws-tf-s3-backend

Terraform module that creates an S3 backend for Terraform state:

- a versioned S3 bucket, encrypted with a dedicated KMS key, private, and
  reachable only over TLS 1.2 or later
- an optional DynamoDB table for state locking
- lifecycle rules that keep recent state versions for recovery and clean up
  incomplete uploads

The bucket and KMS key have `prevent_destroy` set, so `terraform destroy` fails
on them unless you remove that setting.

## Using the backend

Apply the module, then copy the `backend_config` output into the `backend "s3"`
block of each configuration that stores state here, adding a `key` unique to
that configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "demo-test-123456789012-tf-state-us-east-1"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/..."
    dynamodb_table = "terraform-lock-table-us-east-1" # or use_lockfile = true
  }
}
```

To run more than one backend in the same account and region, give each a
unique `kms_alias_name` and `lock_table_name`.

## Moving to S3 native locking

Terraform 1.10 and later can lock state with a lock file in the S3 bucket
(`use_lockfile = true`) instead of a DynamoDB table. HashiCorp has deprecated
DynamoDB locking. To move without a window where state is unlocked:

1. Upgrade Terraform to 1.10 or later everywhere that uses the backend,
   including CI.
2. In each configuration's `backend "s3"` block, add `use_lockfile = true` and
   keep `dynamodb_table`, then run `terraform init -reconfigure`. Terraform
   takes both locks while both are set.
3. Once every configuration and pipeline runs with both settings, remove
   `dynamodb_table` from each backend block and run
   `terraform init -reconfigure` again.
4. Set `create_lock_table = false` on this module and apply. This deletes the
   DynamoDB table, and `backend_config` switches to `use_lockfile = true`.

Identities that run Terraform need `s3:GetObject`, `s3:PutObject` and
`s3:DeleteObject` on `<key>.tflock` in the bucket, in addition to access to the
state file itself.

## Upgrading

- **v3.2.0:** resources were renamed to snake_case and the lock table moved to
  `aws_dynamodb_table.tf_lock[0]`. `moved` blocks handle this, so the upgrade
  plan only updates resources in place. `organization` and `environment` now
  only accept lowercase letters, digits and hyphens.
- **v3.0.0:** requires AWS provider 6.x. The `Organization` and `Environment`
  tags are no longer added automatically; pass them in `tags`.

<!-- BEGIN_TF_DOCS -->


## Example

```hcl
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
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

No modules.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_lock_table"></a> [create\_lock\_table](#input\_create\_lock\_table) | Create a DynamoDB table for state locking. Set to false when using S3 native locking (use\_lockfile = true, Terraform 1.10+). | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g. dev, prod), included in the state bucket name. Lowercase letters, digits and hyphens. | `string` | n/a | yes |
| <a name="input_kms_alias_name"></a> [kms\_alias\_name](#input\_kms\_alias\_name) | Name of the KMS key alias. Set a unique value to deploy more than one backend per account and region. | `string` | `"alias/tf-state-key"` | no |
| <a name="input_lock_table_name"></a> [lock\_table\_name](#input\_lock\_table\_name) | Name of the DynamoDB lock table. Defaults to terraform-lock-table-<region>. Set a unique value to deploy more than one backend per account and region. | `string` | `null` | no |
| <a name="input_noncurrent_version_expiration_days"></a> [noncurrent\_version\_expiration\_days](#input\_noncurrent\_version\_expiration\_days) | Days to keep noncurrent versions of state files before they expire. Old versions are how you recover a corrupted state file. | `number` | `30` | no |
| <a name="input_noncurrent_versions_to_retain"></a> [noncurrent\_versions\_to\_retain](#input\_noncurrent\_versions\_to\_retain) | Number of noncurrent versions of each state file to keep regardless of age, so a rarely changed state keeps its backups. Set to null to expire purely by age. | `number` | `10` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Organization name, used as the prefix of the state bucket name. Lowercase letters, digits and hyphens. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources. A Name tag set here is overridden per resource. | `map(string)` | `{}` | no |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_dynamodb_table.tf_lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_kms_alias.tf_state_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.tf_state_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.terraform_backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.lifecycle_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.deny_insecure_transport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.bucket_public_access_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_config"></a> [backend\_config](#output\_backend\_config) | Settings for an S3 backend block that uses this backend. Add your own key. Uses DynamoDB locking when the lock table is created, otherwise S3 native locking (Terraform 1.10+). |
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | ARN of the KMS key that encrypts the state bucket and lock table. |
| <a name="output_lock_table"></a> [lock\_table](#output\_lock\_table) | Name of the DynamoDB table used for state locking, or null when create\_lock\_table is false. |
| <a name="output_lock_table_arn"></a> [lock\_table\_arn](#output\_lock\_table\_arn) | ARN of the DynamoDB table used for state locking, or null when create\_lock\_table is false. |
| <a name="output_terraform_bucket"></a> [terraform\_bucket](#output\_terraform\_bucket) | Name of the S3 bucket that stores Terraform state. |
| <a name="output_terraform_bucket_arn"></a> [terraform\_bucket\_arn](#output\_terraform\_bucket\_arn) | ARN of the S3 bucket that stores Terraform state. |
<!-- END_TF_DOCS -->