# Unit tests run against a mocked AWS provider, so no credentials or real
# resources are needed. Run with: terraform init && terraform test

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  # random mock values are not valid ARNs, which the provider rejects on apply
  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::demo-test-123456789012-tf-state-us-east-1"
    }
  }
}

variables {
  organization = "demo"
  environment  = "test"
}

run "default_names_unchanged" {
  command = plan

  assert {
    condition     = aws_s3_bucket.terraform-backend.bucket == "demo-test-123456789012-tf-state-us-east-1"
    error_message = "Bucket name changed; existing backends would be replaced."
  }
  assert {
    condition     = aws_dynamodb_table.tf-lock.name == "terraform-lock-table-us-east-1"
    error_message = "Default lock table name changed; existing backends would be replaced."
  }
  assert {
    condition     = aws_kms_alias.tf-state-key.name == "alias/tf-state-key"
    error_message = "Default KMS alias changed; existing backends would be replaced."
  }
}

run "name_overrides" {
  command = plan

  variables {
    lock_table_name = "demo-test-terraform-lock"
    kms_alias_name  = "alias/demo-test-tf-state"
  }

  assert {
    condition     = aws_dynamodb_table.tf-lock.name == "demo-test-terraform-lock"
    error_message = "lock_table_name was not applied."
  }
  assert {
    condition     = aws_kms_alias.tf-state-key.name == "alias/demo-test-tf-state"
    error_message = "kms_alias_name was not applied."
  }
}

run "rejects_alias_without_prefix" {
  command = plan

  variables {
    kms_alias_name = "tf-state-key"
  }

  expect_failures = [var.kms_alias_name]
}

run "rejects_reserved_aws_alias" {
  command = plan

  variables {
    kms_alias_name = "alias/aws/s3"
  }

  expect_failures = [var.kms_alias_name]
}

run "tags_merged_and_name_preserved" {
  command = plan

  variables {
    tags = {
      Environment = "test"
      Name        = "should-be-overridden"
    }
  }

  assert {
    condition     = aws_s3_bucket.terraform-backend.tags["Environment"] == "test"
    error_message = "var.tags not applied to the bucket."
  }
  assert {
    condition     = aws_s3_bucket.terraform-backend.tags["Name"] == "terraform-state"
    error_message = "var.tags overrode the bucket's Name tag."
  }
  assert {
    condition     = aws_kms_key.tf-state-key.tags["Name"] == "tf-state-key"
    error_message = "var.tags overrode the KMS key's Name tag."
  }
  assert {
    condition     = aws_dynamodb_table.tf-lock.tags["Name"] == "terraform-config"
    error_message = "var.tags overrode the lock table's Name tag."
  }
}

run "bucket_policy_denies_insecure_transport" {
  # apply so the mocked bucket ARN in the policy is known
  command = apply

  assert {
    condition = alltrue([
      for s in jsondecode(aws_s3_bucket_policy.deny_insecure_transport.policy).Statement :
      s.Effect == "Deny" && s.Condition.Bool["aws:SecureTransport"] == "false"
    ])
    error_message = "Bucket policy does not deny non-TLS requests."
  }
  assert {
    condition = contains(
      jsondecode(aws_s3_bucket_policy.deny_insecure_transport.policy).Statement[0].Resource,
      "${aws_s3_bucket.terraform-backend.arn}/*"
    )
    error_message = "Bucket policy does not cover objects in the bucket."
  }
}
