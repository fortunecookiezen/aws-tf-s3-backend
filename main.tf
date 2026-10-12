terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
resource "aws_s3_bucket" "terraform-backend" {
  bucket = "${var.organization}-${var.environment}-${data.aws_caller_identity.current.account_id}-tf-state-${data.aws_region.current.region}"

  tags = merge(var.tags, {
    Name = "terraform-state"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access_block" {
  bucket                  = aws_s3_bucket.terraform-backend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "deny_insecure_transport" {
  bucket = aws_s3_bucket.terraform-backend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform-backend.arn,
          "${aws_s3_bucket.terraform-backend.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  # S3 rejects concurrent bucket policy and public access block updates
  depends_on = [aws_s3_bucket_public_access_block.bucket_public_access_block]
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
  tags = merge(var.tags, {
    Name = "tf-state-key"
  })

  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_kms_alias" "tf-state-key" {
  name          = var.kms_alias_name
  target_key_id = aws_kms_key.tf-state-key.key_id
}

resource "aws_dynamodb_table" "tf-lock" {
  name         = coalesce(var.lock_table_name, "terraform-lock-table-${data.aws_region.current.region}")
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
  tags = merge(var.tags, {
    Name = "terraform-config"
  })
}
