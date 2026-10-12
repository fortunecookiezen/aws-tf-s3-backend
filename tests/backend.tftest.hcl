# Unit tests run against a mocked AWS provider, so no credentials or real
# resources are needed. Run with: terraform init && terraform test

mock_provider "aws" {
  # use the mock values below at plan time too, so no run needs to apply;
  # older Terraform versions fail test cleanup on prevent_destroy resources
  override_during = plan

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
  # give ARNs fixed values that tests can compare against
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
    condition     = aws_s3_bucket.terraform_backend.bucket == "demo-test-123456789012-tf-state-us-east-1"
    error_message = "Bucket name changed; existing backends would be replaced."
  }
  assert {
    condition     = aws_dynamodb_table.tf_lock[0].name == "terraform-lock-table-us-east-1"
    error_message = "Default lock table name changed; existing backends would be replaced."
  }
  assert {
    condition     = aws_kms_alias.tf_state_key.name == "alias/tf-state-key"
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
    condition     = aws_dynamodb_table.tf_lock[0].name == "demo-test-terraform-lock"
    error_message = "lock_table_name was not applied."
  }
  assert {
    condition     = aws_kms_alias.tf_state_key.name == "alias/demo-test-tf-state"
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
    condition     = aws_s3_bucket.terraform_backend.tags["Environment"] == "test"
    error_message = "var.tags not applied to the bucket."
  }
  assert {
    condition     = aws_s3_bucket.terraform_backend.tags["Name"] == "terraform-state"
    error_message = "var.tags overrode the bucket's Name tag."
  }
  assert {
    condition     = aws_kms_key.tf_state_key.tags["Name"] == "tf-state-key"
    error_message = "var.tags overrode the KMS key's Name tag."
  }
  assert {
    condition     = aws_dynamodb_table.tf_lock[0].tags["Name"] == "terraform-lock"
    error_message = "var.tags overrode the lock table's Name tag."
  }
}

run "bucket_policy_denies_insecure_transport" {
  command = plan

  assert {
    condition = anytrue([
      for s in jsondecode(aws_s3_bucket_policy.deny_insecure_transport.policy).Statement :
      s.Effect == "Deny" && try(s.Condition.Bool["aws:SecureTransport"], null) == "false"
    ])
    error_message = "Bucket policy does not deny non-TLS requests."
  }
  assert {
    condition = anytrue([
      for s in jsondecode(aws_s3_bucket_policy.deny_insecure_transport.policy).Statement :
      s.Effect == "Deny" && try(s.Condition.NumericLessThan["s3:TlsVersion"], null) == 1.2
    ])
    error_message = "Bucket policy does not deny TLS versions below 1.2."
  }
  assert {
    condition = alltrue([
      for s in jsondecode(aws_s3_bucket_policy.deny_insecure_transport.policy).Statement :
      s.Effect == "Deny" && contains(s.Resource, "${aws_s3_bucket.terraform_backend.arn}/*")
    ])
    error_message = "Bucket policy contains an allow, or a statement that does not cover objects in the bucket."
  }
}

run "rejects_uppercase_organization" {
  command = plan

  variables {
    organization = "Demo"
  }

  expect_failures = [var.organization]
}

run "rejects_environment_with_trailing_hyphen" {
  command = plan

  variables {
    environment = "test-"
  }

  expect_failures = [var.environment]
}

run "rejects_bucket_name_over_63_characters" {
  command = plan

  variables {
    organization = "a-very-long-organization-name"
  }

  expect_failures = [aws_s3_bucket.terraform_backend]
}

run "lock_table_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_dynamodb_table.tf_lock) == 1
    error_message = "Lock table not created by default."
  }
  assert {
    condition     = output.backend_config.dynamodb_table == "terraform-lock-table-us-east-1"
    error_message = "backend_config does not use the DynamoDB lock table."
  }
  assert {
    condition     = !contains(keys(output.backend_config), "use_lockfile")
    error_message = "backend_config sets use_lockfile alongside the lock table."
  }
}

run "lock_table_optional" {
  command = plan

  variables {
    create_lock_table = false
  }

  assert {
    condition     = length(aws_dynamodb_table.tf_lock) == 0
    error_message = "Lock table created although create_lock_table is false."
  }
  assert {
    condition     = output.lock_table == null
    error_message = "lock_table output is not null without a lock table."
  }
  assert {
    condition     = output.backend_config.use_lockfile == true && !contains(keys(output.backend_config), "dynamodb_table")
    error_message = "backend_config does not switch to S3 native locking."
  }
}

run "backend_config_points_at_backend" {
  command = plan

  assert {
    condition = (
      output.backend_config.bucket == "demo-test-123456789012-tf-state-us-east-1" &&
      output.backend_config.region == "us-east-1" &&
      output.backend_config.encrypt == true &&
      output.backend_config.kms_key_id == aws_kms_key.tf_state_key.arn
    )
    error_message = "backend_config does not match the created backend."
  }
}

run "storage_settings" {
  command = plan

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.encryption.rule[*].bucket_key_enabled) == true
    error_message = "S3 bucket key is not enabled."
  }
  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.lifecycle_rule.rule[0].noncurrent_version_expiration[*].noncurrent_days) == 30
    error_message = "Default noncurrent version expiration is not 30 days."
  }
  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.lifecycle_rule.rule[0].noncurrent_version_expiration[*].newer_noncurrent_versions) == 10
    error_message = "Default number of retained noncurrent versions is not 10."
  }
  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.lifecycle_rule.rule[0].abort_incomplete_multipart_upload[*].days_after_initiation) == 7
    error_message = "Incomplete multipart uploads are not aborted after 7 days."
  }
  assert {
    condition     = aws_kms_key.tf_state_key.deletion_window_in_days == 30
    error_message = "KMS key deletion window is not 30 days."
  }
}

run "noncurrent_version_expiration_configurable" {
  command = plan

  variables {
    noncurrent_version_expiration_days = 90
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.lifecycle_rule.rule[0].noncurrent_version_expiration[*].noncurrent_days) == 90
    error_message = "noncurrent_version_expiration_days was not applied."
  }
}

run "rejects_zero_noncurrent_days" {
  command = plan

  variables {
    noncurrent_version_expiration_days = 0
  }

  expect_failures = [var.noncurrent_version_expiration_days]
}

run "noncurrent_versions_retention_can_be_disabled" {
  command = plan

  variables {
    noncurrent_versions_to_retain = null
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.lifecycle_rule.rule[0].noncurrent_version_expiration[*].newer_noncurrent_versions) == null
    error_message = "noncurrent_versions_to_retain = null still retains versions."
  }
}

run "rejects_too_many_retained_versions" {
  command = plan

  variables {
    noncurrent_versions_to_retain = 101
  }

  expect_failures = [var.noncurrent_versions_to_retain]
}
