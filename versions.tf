######################################################################
# Version Constraints
######################################################################

terraform {
  # terraform_data (used for optional placeholder image seeding) requires >= 1.4.
  required_version = ">= 1.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
