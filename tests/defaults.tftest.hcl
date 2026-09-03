######################################################################
# Default Security Posture
######################################################################
#
# Asserts that the default values for security variables remain secure.
#
# These settings are variables with safe defaults. This file verifies
# that the defaults have not been weakened — a change to a default
# value will fail here and force an explicit decision.
#
# Runs in plan mode against a mocked AWS provider: no credentials, no
# API calls, no infrastructure created, no cost.
######################################################################

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  repository_name = "test/my-service"
  kms_key_arn     = "arn:aws:kms:eu-west-1:111122223333:key/00000000-0000-0000-0000-000000000000"
}

######################################################################
# Security Defaults
######################################################################

run "security_defaults_are_secure" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this.image_tag_mutability == "IMMUTABLE"
    error_message = "image_tag_mutability default must be IMMUTABLE — published tags must not be overwritable."
  }

  assert {
    condition     = aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push == true
    error_message = "scan_on_push default must be true — every pushed image is scanned for vulnerabilities."
  }

  assert {
    condition     = aws_ecr_repository.this.force_delete == false
    error_message = "force_delete default must be false — a repository holding images must not be destroyable."
  }

  assert {
    condition     = aws_ecr_repository.this.encryption_configuration[0].encryption_type == "KMS"
    error_message = "encryption_type must be KMS — AES256 is not acceptable for image storage."
  }
}

######################################################################
# Conditional Repository Policy
######################################################################

run "no_policy_when_no_principals" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository_policy.this) == 0
    error_message = "No repository policy should be created when no cross-account IDs or push principals are given."
  }
}

run "policy_created_for_cross_account_pull" {
  command = plan

  variables {
    cross_account_pull_ids = ["111122223333"]
  }

  assert {
    condition     = length(aws_ecr_repository_policy.this) == 1
    error_message = "A repository policy must be created when cross_account_pull_ids is populated."
  }
}

run "policy_created_for_push_principals" {
  command = plan

  variables {
    push_principal_arns = ["arn:aws:iam::111122223333:role/ci-build"]
  }

  assert {
    condition     = length(aws_ecr_repository_policy.this) == 1
    error_message = "A repository policy must be created when push_principal_arns is populated."
  }
}
