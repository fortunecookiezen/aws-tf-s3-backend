module "backend" {
  source       = "git::https://github.com/fortunecookiezen/aws-tf-s3-backend.git?ref=v3.0.0"
  organization = "demo"
  environment  = "test"
  tags = {
    Organization = "demo"
    Environment  = "test"
  }
}
