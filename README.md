# aws-tf-s3-backend

terraform module to create your terraform backend. Yeah.

<!-- BEGIN_TF_DOCS -->


## Example

```hcl
module "backend" {
  source       = "git::https://github.com/fortunecookiezen/aws-tf-s3-backend.git?ref=v3.1.0"
  organization = "demo"
  environment  = "test"
  tags = {
    Organization = "demo"
    Environment  = "test"
  }
}
```

## Requirements

| Name | Version |
| ---- | ------- |
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
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g. dev, prod), included in the state bucket name. | `string` | n/a | yes |
| <a name="input_kms_alias_name"></a> [kms\_alias\_name](#input\_kms\_alias\_name) | Name of the KMS key alias. Set a unique value to deploy more than one backend per account and region. | `string` | `"alias/tf-state-key"` | no |
| <a name="input_lock_table_name"></a> [lock\_table\_name](#input\_lock\_table\_name) | Name of the DynamoDB lock table. Defaults to terraform-lock-table-<region>. Set a unique value to deploy more than one backend per account and region. | `string` | `null` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Organization name, used as the prefix of the state bucket name. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources. A Name tag set here is overridden per resource. | `map(string)` | `{}` | no |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_dynamodb_table.tf-lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_kms_alias.tf-state-key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.tf-state-key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.terraform-backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
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
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | ARN of the KMS key that encrypts the state bucket and lock table. |
| <a name="output_lock_table"></a> [lock\_table](#output\_lock\_table) | Name of the DynamoDB table used for state locking. |
| <a name="output_terraform_bucket"></a> [terraform\_bucket](#output\_terraform\_bucket) | Name of the S3 bucket that stores Terraform state. |
<!-- END_TF_DOCS -->