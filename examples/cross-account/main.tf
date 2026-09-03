# Cross-Account ECR Repository Example
#
# Creates a repository intended to hold a single artifact that is promoted
# across environments. Workload accounts are granted pull access, and a CI/CD
# principal is granted push access.
#
# Consumers pulling cross-account also need decrypt permission on the KMS key
# encrypting this repository. That is granted in the key policy, not here.

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

  # Workload accounts that run the image
  cross_account_pull_ids = [
    "111122223333",
    "444455556666",
  ]

  # CI/CD principal that builds and pushes the image
  push_principal_arns = [
    "arn:aws:iam::777788889999:role/ci-build-push-ecr",
  ]
}

output "repository_url" {
  description = "URL of the created repository"
  value       = module.ecr.repository_url
}
