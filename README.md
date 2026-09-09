# Data platform (Terraform)

[![CI](https://github.com/Bhanu047/data-platform-terraform/actions/workflows/ci.yml/badge.svg)](https://github.com/Bhanu047/data-platform-terraform/actions/workflows/ci.yml)

The AWS side of a data platform: an S3 lake in three layers, a Glue catalog, and a least-privilege role for the pipelines that use them.

```
modules/data-lake         raw / staging / curated buckets
modules/glue-catalog      databases the pipeline registers tables into
modules/pipeline-identity the role, scoped to exactly those buckets
```

Tested with mocked providers, so `terraform test` runs with no AWS account and no credentials. CI validates every module independently and runs the full suite on every push.

Like my other repos, this README is mostly about why. The configuration is a few hundred lines and reads quickly; the reasoning behind the defaults is the part that doesn't survive being inferred from a diff.

## Running it

```bash
make check      # fmt, validate every module, run the tests
make lint       # tflint
```

No credentials needed for any of that. `make plan-dev` needs real ones.

## Why the pipeline cannot write to raw

This is the decision I'd defend first.

The pipeline reads raw and staging, and writes staging and curated. It has no write access to raw at all.

Raw is what the ingestion tier lands — often the only copy of what the source actually sent. A transform job that can rewrite its own input can destroy that, and no amount of care in the job prevents it. Only the policy does.

The access model is stated as locals at the root and exposed as outputs, rather than being passed inline into the module call. That's so it can be asserted on in a test and read without tracing arguments across a module boundary. Who can touch what is the thing a reviewer most needs to check, so it shouldn't require archaeology.

## Why there are no wildcards in the IAM policy

`s3:*` on `*` is the policy everyone writes on day one and nobody revisits. It means a compromised job can read every bucket in the account, including whatever the security team is storing.

Read and write are separate statements against separate bucket lists, because "can read raw" and "can write curated" are genuinely different permissions and collapsing them removes the ability to say so.

Two details that are easy to get wrong:

`s3:ListBucket` is a bucket-level action on the bucket ARN, not the object ARN. Without it, reading a key that doesn't exist returns `AccessDenied` instead of `NoSuchKey`, and every debugging session starts by chasing the wrong error.

Multipart uploads need `AbortMultipartUpload` and `ListMultipartUploadParts`. A Spark job writing large files fails without them, and the error message names neither.

Deliberately absent: `glue:DeleteTable` and `glue:DeleteDatabase`. A pipeline that can drop a table will eventually drop a table.

## Why force_destroy is refused in prod rather than trusted

`force_destroy = true` lets `terraform destroy` delete a non-empty bucket. In a sandbox that's convenience. In prod it means one wrong workspace deletes the lake, and there is no undo.

So the root config refuses it in prod regardless of what the variable says, and there's a test asserting that asking is not the same as receiving. Leaving it to code review would work right up until the review that gets skimmed.

## Why every S3 control is set explicitly

Public access blocking, encryption, versioning and TLS-only are all stated even where the AWS default is currently fine. Defaults change, and a stated value shows intent — "we thought it inherited that" is how buckets end up public.

Some specifics:

**Public access is blocked per-bucket as well as account-wide.** Account settings are one console click from being changed by someone who doesn't know what depends on them.

**TLS-only needs a bucket policy.** S3 accepts plain HTTP by default and there's no toggle; an explicit `Deny` on `aws:SecureTransport = false` is the only way.

**Bucket keys are enabled with KMS.** Without them, every object read makes its own KMS call. On a Spark job reading tens of thousands of files that's both slow and a surprising line on the bill.

**Lifecycle rules clean up non-current versions.** Versioning is what turns "someone overwrote the partition" from an incident into an inconvenience, but on a versioned bucket every overwrite leaves the old object behind — invisible in the console, fully billed. Same for incomplete multipart uploads, which a failed Spark write can leave thousands of.

The transitions differ per layer because the access patterns do. Raw is read constantly for a month then rarely, so it moves to IA then Glacier. Curated is queried continuously, so moving it to IA would cost more in retrieval than it saves in storage.

## Why separate buckets per layer

Bucket policies and lifecycle rules apply per bucket. One shared bucket with prefixes means every access rule has to be expressed as a prefix condition, and those are easy to write slightly wrong and hard to audit.

## Why one root config rather than a directory per environment

Copied directories drift. Someone fixes a lifecycle rule in prod, forgets dev, and six months later a bug reproduces in one and not the other for reasons nobody can explain.

One parameterised root, with `environments/*/terraform.tfvars` holding the differences and nothing else.

## Why the tests use mocked providers

`terraform test` with `mock_provider` synthesises provider responses instead of calling AWS, so the suite runs in seconds, needs no account, and works on a fork.

The limit is worth stating plainly: **this tests the plan, not the cloud.** It catches a bucket created without a public access block, or a guard that stopped working. It cannot catch a bucket policy AWS itself would reject. That needs an apply into a sandbox account, which is a slower and more expensive kind of test, and the right next step rather than a substitute for this one.

It also shapes what's worth asserting. A mocked provider returns a synthetic value for `aws_iam_policy_document.json`, so asserting on the rendered policy would be asserting on the mock. The bucket lists are real configuration, and they're the decision that actually matters.

## Why the provider version is `~> 5.60`

Pessimistic on the minor, not pinned to a patch. Security fixes land in patches and shouldn't need a code change to pick up. A minor bump can rename attributes and deserves a deliberate upgrade with a plan diff to read.

`.terraform.lock.hcl` is gitignored here because this is a module collection rather than a deployed root. A repo that actually owns an environment should commit the lock file so every apply uses identical provider builds.

## What's missing

On purpose:

- **The state backend is commented out.** It can't be created by the configuration that uses it — the bucket has to exist first, bootstrapped separately. The block is there with the two settings that matter (`use_lockfile`, `encrypt`) and an explanation.
- **No KMS key resource.** Key policy and rotation are their own decision, usually owned by a security team. The module takes an ARN and falls back to SSE-S3 so it works before that exists.
- **No compute.** Glue jobs, EMR clusters and Airflow all sit on top of this. The role they assume is here; what they run is a different repo.
- **No `terraform apply` in CI.** That needs an account and a spend limit. Fine for a real team, dishonest in a portfolio repo where I'd have to fake the credentials.
