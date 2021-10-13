# aws-tf-s3-backend

terraform module to create your terraform backend. Yeah.

<!-- BEGIN_TF_DOCS -->


## Example

```hcl
module "backend" {
  source       = "git::https://github.com/fortunecookiezen/aws-tf-s3-backend.git"
  organization = "demo"
  environment  = "test"
}

```

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_sso_role"></a> [admin\_sso\_role](#input\_admin\_sso\_role) | n/a | `string` | n/a | yes |
| <a name="input_ci-user"></a> [ci-user](#input\_ci-user) | n/a | `string` | n/a | yes |
| <a name="input_costcenter"></a> [costcenter](#input\_costcenter) | n/a | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | n/a | yes |
| <a name="input_organization"></a> [organization](#input\_organization) | n/a | `string` | n/a | yes |

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.tf-lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_kms_alias.tf-state-key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.tf-state-key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.terraform-backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Outputs

No outputs.
<!-- END_TF_DOCS -->