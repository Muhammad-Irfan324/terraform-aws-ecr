######################################################################
# KMS Key Lookup
######################################################################

# Read only when the caller did not supply an ARN. Without the count this
# ran on every plan and the result was discarded whenever kms_key_arn was
# set — which meant every consumer needed ssm:GetParameter on this path,
# and a missing parameter failed the plan over a value nothing used.
data "aws_ssm_parameter" "kms_key" {
  count = var.kms_key_arn == null ? 1 : 0

  name = var.kms_key_ssm_path
}

# Partition, so the principal ARNs below are correct outside commercial AWS.
# Resolves to "aws" there, so this changes no existing plan.
data "aws_partition" "current" {}

######################################################################
# Locals
######################################################################

locals {
  # SSM marks every parameter value sensitive. A KMS key ARN is not a secret,
  # and leaving the marking on would force output "kms_key_arn" to be sensitive
  # too, hiding an identifier consumers need. Stripping it is deliberate.
  kms_key_arn = nonsensitive(
    var.kms_key_arn != null ? var.kms_key_arn : data.aws_ssm_parameter.kms_key[0].value
  )

  has_repository_policy = length(var.cross_account_pull_ids) > 0 || length(var.push_principal_arns) > 0

  placeholder_platform = var.placeholder_architecture == "arm64" ? "linux/arm64" : "linux/amd64"
}

######################################################################
# ECR Repository
######################################################################

resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = local.kms_key_arn
  }

  tags = var.tags
}

######################################################################
# Lifecycle Policy
######################################################################

# Untagged images are build noise and expire quickly. Tagged images are retained
# by count rather than age so a rarely-deployed service keeps a rollback target.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than ${var.untagged_image_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the last ${var.tagged_image_count} tagged images"
        selection = {
          tagStatus = "tagged"
          # ECR rejects an empty prefix. A "*" pattern is the supported way to
          # match every tag regardless of its format.
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.tagged_image_count
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}

######################################################################
# Repository Policy
######################################################################

data "aws_iam_policy_document" "repository" {
  count = local.has_repository_policy ? 1 : 0

  dynamic "statement" {
    for_each = length(var.cross_account_pull_ids) > 0 ? [1] : []
    content {
      sid    = "CrossAccountPull"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [for id in var.cross_account_pull_ids : "arn:${data.aws_partition.current.partition}:iam::${id}:root"]
      }

      actions = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
      ]
    }
  }

  dynamic "statement" {
    for_each = length(var.push_principal_arns) > 0 ? [1] : []
    content {
      sid    = "Push"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = var.push_principal_arns
      }

      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
      ]
    }
  }
}

resource "aws_ecr_repository_policy" "this" {
  count      = local.has_repository_policy ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.repository[0].json
}

######################################################################
# Placeholder Image Seeding
######################################################################

# Declared here rather than with the other data sources: the seeding block
# below is its only consumer.
data "aws_region" "current" {}

# Optional bootstrap: push a placeholder so a container Lambda can be created
# before the real image exists. Opt-in because it needs docker on the apply host.
resource "terraform_data" "seed_placeholder" {
  count = var.seed_placeholder_image ? 1 : 0

  # Re-seed only if the repository itself is replaced.
  triggers_replace = [aws_ecr_repository.this.arn]

  provisioner "local-exec" {
    interpreter = ["bash", "-ce"]
    command     = <<-EOT
      REPO_URL="${aws_ecr_repository.this.repository_url}"
      REGION="${data.aws_region.current.region}"
      SOURCE_IMAGE="public.ecr.aws/lambda/provided:al2023"

      aws ecr get-login-password --region "$REGION" \
        | docker login --username AWS --password-stdin "$REPO_URL"

      docker pull --platform "${local.placeholder_platform}" "$SOURCE_IMAGE"
      docker tag "$SOURCE_IMAGE" "$REPO_URL:placeholder"
      docker push "$REPO_URL:placeholder"

      docker rmi "$SOURCE_IMAGE" "$REPO_URL:placeholder" 2>/dev/null || true
    EOT
  }
}

# Deliberate formatting break to test required status checks.
# Remove this block after the test.
locals {
  test_broken_formatting    = "one"
  another_one   = "two"
      indented_wrong = "three"
}
