terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
resource "aws_s3_bucket" "terraform-backend" {
  bucket = "${var.organization}-${var.environment}-${data.aws_caller_identity.current.account_id}-tf-state-${data.aws_region.current.id}"

  tags = {
    Name         = "terraform-state"
    Organization = var.organization
    Environment  = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access_block" {
  bucket                  = aws_s3_bucket.terraform-backend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform-backend.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform-backend.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tf-state-key.id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle_rule" {
  bucket = aws_s3_bucket.terraform-backend.id
  rule {
    id     = "noncurrent-version-expiration"
    status = "Enabled"
    filter {
      prefix = ""
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
resource "aws_kms_key" "tf-state-key" {
  description             = "key used to encrypt terraform state file"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy                  = <<POLICY
{
  "Id": "ci-key-policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow root to administer the key",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": [
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
  tags = {
    Name         = "tf-state-key"
    Organization = var.organization
    Environment  = var.environment
  }
}
resource "aws_kms_alias" "tf-state-key" {
  name          = "alias/tf-state-key"
  target_key_id = aws_kms_key.tf-state-key.key_id
}

resource "aws_dynamodb_table" "tf-lock" {
  name         = "terraform-lock-table-${data.aws_region.current.id}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tf-state-key.arn
  }
  point_in_time_recovery {
    enabled = true
  }
  tags = {
    Name         = "terraform-config"
    Organization = var.organization
    Environment  = var.environment
  }
}
