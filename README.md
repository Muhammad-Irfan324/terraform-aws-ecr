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
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy) | resource |
| [terraform_data.seed_placeholder](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_iam_policy_document.repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Name of the ECR repository (e.g. 'my-team/my-service') | `string` | n/a | yes |
| <a name="input_cross_account_pull_ids"></a> [cross\_account\_pull\_ids](#input\_cross\_account\_pull\_ids) | AWS account IDs granted pull access to this repository | `list(string)` | `[]` | no |
| <a name="input_force_delete"></a> [force\_delete](#input\_force\_delete) | Whether the repository can be deleted when it still contains images | `bool` | `false` | no |
| <a name="input_image_tag_mutability"></a> [image\_tag\_mutability](#input\_image\_tag\_mutability) | Tag mutability setting for the repository. IMMUTABLE prevents tag overwrites. | `string` | `"IMMUTABLE"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the KMS key used to encrypt the repository. When null, the key ARN is<br/>read from the SSM parameter at kms\_key\_ssm\_path instead.<br/><br/>Note: consumers pulling from this repository cross-account need decrypt<br/>permission on this key. Grant that in the key policy where the key is defined. | `string` | `null` | no |
| <a name="input_kms_key_ssm_path"></a> [kms\_key\_ssm\_path](#input\_kms\_key\_ssm\_path) | SSM parameter path holding the ECR KMS key ARN. Only read when kms\_key\_arn is null. | `string` | `"/ecr/kms_key"` | no |
| <a name="input_placeholder_architecture"></a> [placeholder\_architecture](#input\_placeholder\_architecture) | Architecture of the seeded placeholder image. Must match the consuming Lambda's architecture. | `string` | `"arm64"` | no |
| <a name="input_push_principal_arns"></a> [push\_principal\_arns](#input\_push\_principal\_arns) | IAM principal ARNs granted push access (e.g. a CI/CD role or user that builds images) | `list(string)` | `[]` | no |
| <a name="input_scan_on_push"></a> [scan\_on\_push](#input\_scan\_on\_push) | Whether images are scanned for vulnerabilities on push | `bool` | `true` | no |
| <a name="input_seed_placeholder_image"></a> [seed\_placeholder\_image](#input\_seed\_placeholder\_image) | Push a placeholder image on first creation so a consumer (e.g. a container<br/>Lambda) can be created before the real image exists.<br/><br/>Requires docker and the aws CLI on the machine running terraform apply, and<br/>is generally only needed to bootstrap a service before its build pipeline<br/>exists. Prefer having the pipeline push a real image instead. | `bool` | `false` | no |
| <a name="input_tagged_image_count"></a> [tagged\_image\_count](#input\_tagged\_image\_count) | Number of tagged images to keep. Retained by count rather than age so a<br/>rarely-deployed service always keeps a rollback target. | `number` | `20` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the repository, merged with whatever the provider applies by default | `map(string)` | `{}` | no |
| <a name="input_untagged_image_retention_days"></a> [untagged\_image\_retention\_days](#input\_untagged\_image\_retention\_days) | Days before an untagged image is expired. Untagged images are build noise; this is cost policy, not a security control. | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key encrypting the repository |
| <a name="output_placeholder_image_uri"></a> [placeholder\_image\_uri](#output\_placeholder\_image\_uri) | URI of the seeded placeholder image, or null when seeding is disabled |
| <a name="output_repository_arn"></a> [repository\_arn](#output\_repository\_arn) | ARN of the ECR repository |
| <a name="output_repository_name"></a> [repository\_name](#output\_repository\_name) | Name of the ECR repository |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | URL of the ECR repository (<account\_id>.dkr.ecr.<region>.amazonaws.com/<name>) |
<!-- END_TF_DOCS -->

## License

Apache 2.0 Licensed. See [LICENSE](LICENSE).
