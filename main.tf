terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

locals {
  bucket_name = "${var.organization}-${var.environment}-${data.aws_caller_identity.current.account_id}-tf-state-${data.aws_region.current.region}"
}

resource "aws_s3_bucket" "terraform_backend" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name = "terraform-state"
  })

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = length(local.bucket_name) <= 63
      error_message = "Bucket name ${local.bucket_name} is ${length(local.bucket_name)} characters; S3 allows 63. Shorten organization or environment."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access_block" {
  bucket                  = aws_s3_bucket.terraform_backend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "deny_insecure_transport" {
  bucket = aws_s3_bucket.terraform_backend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_backend.arn,
          "${aws_s3_bucket.terraform_backend.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyOutdatedTls"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_backend.arn,
          "${aws_s3_bucket.terraform_backend.arn}/*",
        ]
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = 1.2
          }
        }
      },
    ]
  })

  # S3 rejects concurrent bucket policy and public access block updates
  depends_on = [aws_s3_bucket_public_access_block.bucket_public_access_block]
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_backend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform_backend.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tf_state_key.id
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle_rule" {
  bucket = aws_s3_bucket.terraform_backend.id
  rule {
    id     = "noncurrent-version-expiration"
    status = "Enabled"
    filter {
      prefix = ""
    }
    noncurrent_version_expiration {
      noncurrent_days           = var.noncurrent_version_expiration_days
      newer_noncurrent_versions = var.noncurrent_versions_to_retain
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_kms_key" "tf_state_key" {
  description             = "key used to encrypt terraform state file"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy = jsonencode({
    Id      = "tf-state-key-policy"
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow root to administer the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "tf-state-key"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "tf_state_key" {
  name          = var.kms_alias_name
  target_key_id = aws_kms_key.tf_state_key.key_id
}

resource "aws_dynamodb_table" "tf_lock" {
  count = var.create_lock_table ? 1 : 0

  name         = coalesce(var.lock_table_name, "terraform-lock-table-${data.aws_region.current.region}")
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tf_state_key.arn
  }
  point_in_time_recovery {
    enabled = true
  }
  tags = merge(var.tags, {
    Name = "terraform-lock"
  })
}
