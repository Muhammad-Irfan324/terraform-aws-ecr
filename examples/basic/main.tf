# Basic ECR Repository Example
#
# Creates a single ECR repository encrypted with the account-level KMS key
# read from SSM, with immutable tags and the default lifecycle policy.

terraform {
  required_version = ">= 1.4"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

module "ecr" {
  source = "../../"

  repository_name = "my-team/my-service"
}

output "repository_url" {
  description = "URL of the created repository"
  value       = module.ecr.repository_url
}
