######################################################################
# Outputs
######################################################################

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "URL of the ECR repository (<account_id>.dkr.ecr.<region>.amazonaws.com/<name>)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.this.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting the repository"
  value       = local.kms_key_arn
}

output "placeholder_image_uri" {
  description = "URI of the seeded placeholder image, or null when seeding is disabled"
  value       = var.seed_placeholder_image ? "${aws_ecr_repository.this.repository_url}:placeholder" : null
}
