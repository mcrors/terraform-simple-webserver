terraform {
  backend "s3" {
    bucket = "rhoulihan-terraform-state"
    key = "global/terraform.tfstate"
    region = "eu-west-1"

    dynamodb_table = "rhoulihan-terraform-locks"
    encrypt = true
    profile = "rory-terraform"
  }
}


provider "aws" {
  region  = "eu-west-1"
  profile = "rory-terraform"
}


resource "aws_s3_bucket" "terraform_state" {
  bucket = "rhoulihan-terraform-state"

  # prevent accidental deletion of this bucket
  lifecycle {
    prevent_destroy = true
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}


resource "aws_dynamodb_table" "terraform_locks" {
  name         = "rhoulihan-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

