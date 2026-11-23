terraform {
  required_version = ">= 1.10"

  required_providers {
    aws       = { source = "hashicorp/aws", version = "~> 5.80" }
    infisical = { source = "infisical/infisical", version = "~> 0.16" }
  }

  # Remote state in S3 with native locking (use_lockfile, Terraform >= 1.10).
  # bucket/region come from backend.hcl:  terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "tennislog/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  # Every resource gets these tags; the deploy command targets instances by Project.
  default_tags {
    tags = { Project = var.project, ManagedBy = "terraform" }
  }
}
