# terraform-aws-ecr

Terraform module for creating an AWS ECR repository with KMS encryption, configurable tag mutability, lifecycle policies, and optional cross-account pull / push access.

Security defaults (immutable tags, scan-on-push, force-delete protection) are set to safe values out of the box but can be overridden when a use case genuinely requires it.

```hcl
module "ecr" {
  source = "github.com/Muhammad-Irfan324/terraform-aws-ecr?ref=v1.0.0"

  repository_name = "my-team/my-service"
}
```

Pin `ref` to a released tag. Releases are cut automatically from `main` by semantic-release, so commit messages drive the version number.

### Cross-account pull and CI/CD push

```hcl
module "ecr" {
  source = "github.com/Muhammad-Irfan324/terraform-aws-ecr?ref=v1.0.0"

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
```

A repository policy is only created when `cross_account_pull_ids` or `push_principal_arns` is non-empty.

Cross-account consumers also need `kms:Decrypt` on the key encrypting the repository. That permission is granted in the KMS key policy where the key is defined, not by this module.

## Security defaults

The following values ship with secure defaults. The first three are variables that can be overridden when a specific use case requires it. Encryption is hardcoded to KMS and cannot be weakened.

| Setting | Default | Configurable | Why |
|---------|---------|:---:|-----|
| `image_tag_mutability` | `IMMUTABLE` | yes | Prevents tag overwrites — a tag always points to the same image, eliminating supply-chain risks from tag reuse |
| `scan_on_push` | `true` | yes | Every image is scanned for vulnerabilities on push — no opt-out by default |
| `force_delete` | `false` | yes | Repositories cannot be deleted while they contain images, preventing accidental data loss |
| `encryption_type` | `KMS` | no | All images are encrypted with a customer-managed KMS key, never the default `AES256` |

## Examples

- [Basic](examples/basic) — minimal usage
- [Cross-Account](examples/cross-account) — cross-account pull and CI/CD push access

## Encryption

Encryption is always KMS, never `AES256`. The key is resolved in this order:

1. `kms_key_arn`, when set.
2. The SSM parameter at `kms_key_ssm_path` (default `/ecr/kms_key`), which holds the account-level ECR key ARN.

The SSM parameter must exist in the target account and region when `kms_key_arn` is not supplied.

## Lifecycle policy

Every repository gets a two-rule policy by default:

| Priority | Selection | Action |
|----------|-----------|--------|
| 1 | Untagged images older than `untagged_image_retention_days` (default 30) | Expire |
| 2 | Tagged images beyond the most recent `tagged_image_count` (default 20) | Expire |

Untagged images are treated as build noise and expire on age. Tagged images expire on count rather than age so a rarely deployed service always keeps a rollback target.

## Placeholder image seeding

`seed_placeholder_image = true` pushes `public.ecr.aws/lambda/provided:al2023` to the repository as `:placeholder` on creation. This exists to bootstrap a container-image Lambda that has to be created before its real image is built.

Caveats:

- Requires `docker` and the `aws` CLI on the machine running `terraform apply`, so it will not work in a plan-only or minimal CI runner.
- `placeholder_architecture` must match the consuming Lambda's architecture.
- Re-seeding only happens if the repository itself is replaced.

Prefer having the build pipeline push a real image where that is possible.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## License

Apache 2.0 Licensed. See [LICENSE](LICENSE).
