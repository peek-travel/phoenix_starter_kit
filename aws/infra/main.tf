terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Remote state — uses partial backend configuration.
  # Pass the environment-specific backend file on init:
  #
  #   sandbox: terraform init -backend-config=backend.sandbox.hcl
  #   prod:    terraform init -backend-config=backend.prod.hcl
  #
  # One-time S3/DynamoDB bootstrap (already done):
  #   aws s3api create-bucket --bucket phoenix-starter-kit-terraform-state --region us-west-2 \
  #     --create-bucket-configuration LocationConstraint=us-west-2
  #   aws s3api put-bucket-versioning --bucket phoenix-starter-kit-terraform-state \
  #     --versioning-configuration Status=Enabled
  #   aws dynamodb create-table --table-name phoenix-starter-kit-terraform-locks \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST --region us-west-2
  #
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.app_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name_prefix = "${var.app_name}-${var.environment}"
}
