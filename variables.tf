######################################################################
# Required Variables
######################################################################

variable "repository_name" {
  description = "Name of the ECR repository (e.g. 'my-team/my-service')"
  type        = string

  validation {
    condition = (
      length(var.repository_name) >= 2 &&
      length(var.repository_name) <= 256 &&
      can(regex("^(?:[a-z0-9]+(?:[._-][a-z0-9]+)*/)*[a-z0-9]+(?:[._-][a-z0-9]+)*$", var.repository_name))
    )
    error_message = "repository_name must conform to ECR naming rules (2-256 chars, lowercase alphanumeric with . _ - separators and optional / path segments)."
  }
}

######################################################################
# Security Variables
######################################################################

variable "image_tag_mutability" {
  description = "Tag mutability setting for the repository. IMMUTABLE prevents tag overwrites."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Whether images are scanned for vulnerabilities on push"
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Whether the repository can be deleted when it still contains images"
  type        = bool
  default     = false
}

######################################################################
# Optional Variables
######################################################################

variable "kms_key_arn" {
  description = <<-EOT
    ARN of the KMS key used to encrypt the repository. When null, the key ARN is
    read from the SSM parameter at kms_key_ssm_path instead.

    Note: consumers pulling from this repository cross-account need decrypt
    permission on this key. Grant that in the key policy where the key is defined.
  EOT
  type        = string
  default     = null
}

variable "kms_key_ssm_path" {
  description = "SSM parameter path holding the ECR KMS key ARN. Only read when kms_key_arn is null."
  type        = string
  default     = "/ecr/kms_key"
}

variable "cross_account_pull_ids" {
  description = "AWS account IDs granted pull access to this repository"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.cross_account_pull_ids : can(regex("^\\d{12}$", id))
    ])
    error_message = "Each element of cross_account_pull_ids must be a 12-digit AWS account ID."
  }
}

variable "push_principal_arns" {
  description = "IAM principal ARNs granted push access (e.g. a CI/CD role or user that builds images)"
  type        = list(string)
  default     = []
}

variable "untagged_image_retention_days" {
  description = "Days before an untagged image is expired. Untagged images are build noise; this is cost policy, not a security control."
  type        = number
  default     = 30

  validation {
    condition     = var.untagged_image_retention_days >= 1 && var.untagged_image_retention_days <= 3650 && floor(var.untagged_image_retention_days) == var.untagged_image_retention_days
    error_message = "untagged_image_retention_days must be a whole number between 1 and 3650."
  }
}

variable "tagged_image_count" {
  description = <<-EOT
    Number of tagged images to keep. Retained by count rather than age so a
    rarely-deployed service always keeps a rollback target.
  EOT
  type        = number
  default     = 20

  validation {
    condition     = var.tagged_image_count >= 1 && floor(var.tagged_image_count) == var.tagged_image_count
    error_message = "tagged_image_count must be a whole number of at least 1."
  }
}

variable "tags" {
  description = "Tags applied to the repository, merged with whatever the provider applies by default"
  type        = map(string)
  default     = {}
}

variable "seed_placeholder_image" {
  description = <<-EOT
    Push a placeholder image on first creation so a consumer (e.g. a container
    Lambda) can be created before the real image exists.

    Requires docker and the aws CLI on the machine running terraform apply, and
    is generally only needed to bootstrap a service before its build pipeline
    exists. Prefer having the pipeline push a real image instead.
  EOT
  type        = bool
  default     = false
}

variable "placeholder_architecture" {
  description = "Architecture of the seeded placeholder image. Must match the consuming Lambda's architecture."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.placeholder_architecture)
    error_message = "placeholder_architecture must be 'arm64' or 'x86_64'."
  }
}
