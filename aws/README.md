# AWS Setup Guide

Step-by-step instructions for provisioning and deploying this app on AWS.

**Stack:** ECS Fargate + RDS Postgres + ALB + ECR  
**Redis:** Optional — set `enable_redis = true` in your tfvars if your app uses it  
**SSL:** ACM cert on ALB (HTTPS on port 443)  
**CI/CD:** GitHub Actions — merge to `main` → sandbox, GitHub release → prod  

---

## Prerequisites

Install the required tools if not already present:

```bash
brew install awscli terraform sops
```

Verify versions:

```bash
aws --version        # needs 2.x+
terraform --version  # needs 1.5+
sops --version       # needs 3.8+
docker --version
```

---

## Phase 1 — Create IAM Users for Terraform

Sandbox and prod are **separate AWS accounts**, so you'll configure one AWS CLI profile per account.

In **each** AWS account:

1. Go to **AWS Console → IAM → Users → Create user**
2. Name it `terraform-admin`
3. Select **"I want to create an IAM user"** (no console access needed)
4. Attach policy: **AdministratorAccess**
5. Click through to **Create user**
6. Open the user → **Security credentials → Create access key**
7. Choose **Command Line Interface (CLI)** → download the CSV

Configure a profile per account:

```bash
# Sandbox (do now)
aws configure --profile my-app-terraform-sandbox
#   region: us-west-2

# Prod (do later, once prod credentials are issued)
aws configure --profile my-app-terraform-prod
#   region: us-west-1
```

Verify:

```bash
aws sts get-caller-identity --profile my-app-terraform-sandbox
```

---

## Phase 2 — Bootstrap Terraform State

Terraform needs an S3 bucket and DynamoDB table before it can store remote state. Run these commands once per environment:

```bash
export AWS_PROFILE=my-app-terraform-sandbox

# Create the state bucket
aws s3api create-bucket \
  --bucket my-app-terraform-state \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-app-terraform-state \
  --versioning-configuration Status=Enabled

# Block all public access
aws s3api put-public-access-block \
  --bucket my-app-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable server-side encryption (Terraform state contains generated passwords)
aws s3api put-bucket-encryption \
  --bucket my-app-terraform-state \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# Create the DynamoDB lock table
aws dynamodb create-table \
  --table-name my-app-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

Update `infra/aws/backend.sandbox.hcl` with your actual bucket name.

> **Why encryption matters:** Terraform state contains the generated database password in plaintext. S3 server-side encryption + the `encrypt = true` flag in the backend block ensures it's encrypted at rest.

### Create KMS keys for SOPS secret encryption

Sandbox and prod live in different AWS accounts so each env gets its own KMS key. That way sandbox principals can't decrypt prod secrets.

#### Sandbox

```bash
export AWS_PROFILE=my-app-terraform-sandbox

SANDBOX_KEY_ID=$(aws kms create-key \
  --description "SOPS — my-app sandbox tfvars secrets" \
  --region us-west-2 \
  --query 'KeyMetadata.KeyId' --output text)
aws kms create-alias \
  --alias-name alias/my-app-sandbox-sops \
  --target-key-id "$SANDBOX_KEY_ID" \
  --region us-west-2

# Fill in the <SANDBOX_ACCOUNT_ID> placeholder in infra/aws/.sops.yaml
SANDBOX_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
sed -i.bak "s/<SANDBOX_ACCOUNT_ID>/$SANDBOX_ACCOUNT/g" infra/aws/.sops.yaml && rm infra/aws/.sops.yaml.bak
```

Commit the updated `.sops.yaml` — AWS account IDs are not secrets.

#### Prod (run once prod credentials are provisioned)

```bash
export AWS_PROFILE=my-app-terraform-prod

PROD_KEY_ID=$(aws kms create-key \
  --description "SOPS — my-app prod tfvars secrets" \
  --region us-west-1 \
  --query 'KeyMetadata.KeyId' --output text)
aws kms create-alias \
  --alias-name alias/my-app-prod-sops \
  --target-key-id "$PROD_KEY_ID" \
  --region us-west-1

PROD_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
sed -i.bak "s/<PROD_ACCOUNT_ID>/$PROD_ACCOUNT/g" infra/aws/.sops.yaml && rm infra/aws/.sops.yaml.bak
```

---

## Phase 3 — Set Terraform Variables

Each environment has two files:

| File | Contents | Committed? |
|---|---|---|
| `terraform.<env>.tfvars` | Non-secret vars (region, sizing, domain) | No — gitignored |
| `secrets.<env>.enc.json` | Secrets (secret_key_base, peek_*, etc.), SOPS-encrypted | **Yes** |

### Non-secret vars

**Sandbox** — create `infra/aws/terraform.sandbox.tfvars`:
```hcl
aws_region        = "us-west-2"
environment       = "sandbox"
phx_host          = "my-app-sandbox.example.com"
github_repo       = "your-org/my-app"
ecs_cpu           = 256
ecs_memory        = 512
ecs_desired_count = 1
ecs_min_count     = 1
ecs_max_count     = 2
# enable_redis    = true  # uncomment if your app uses Redis
```

**Prod** — create `infra/aws/terraform.tfvars`:
```hcl
aws_region        = "us-west-1"
environment       = "prod"
phx_host          = "my-app.example.com"
github_repo       = "your-org/my-app"
ecs_cpu           = 512
ecs_memory        = 1024
ecs_desired_count = 2
ecs_min_count     = 2
ecs_max_count     = 6
# enable_redis    = true  # uncomment if your app uses Redis
```

### Encrypted secrets

First-time setup for each environment:

```bash
cd infra/aws

# Start from the template; fill in real values
cp secrets.example.json secrets.sandbox.json
$EDITOR secrets.sandbox.json     # set secret_key_base, peek_api_key, etc.

# Encrypt; the plaintext file is consumed in place
../../scripts/tf-sops.sh encrypt sandbox

# Commit the encrypted file — this IS safe
git add infra/aws/secrets.sandbox.enc.json
```

All six fields (`secret_key_base`, `peek_api_key`, `peek_app_secret`, `peek_app_id`, `posthog_key`, `sentry_dsn`) are required; `sentry_dsn` can be `""` if you're not using Sentry.

### Editing / rotating a secret

```bash
# Opens the decrypted file in $EDITOR and re-encrypts on save
scripts/tf-sops.sh edit sandbox
```

### Running terraform

```bash
cd infra/aws

# Decrypt once per session — writes secrets.<env>.auto.tfvars.json (gitignored)
../../scripts/tf-sops.sh decrypt sandbox

terraform plan  -var-file=terraform.sandbox.tfvars
terraform apply -var-file=terraform.sandbox.tfvars

# When you're done, optionally wipe the decrypted file:
../../scripts/tf-sops.sh clean sandbox
```

> **How secrets flow:** `secrets.<env>.enc.json` → (SOPS decrypt, local only) → `secrets.<env>.auto.tfvars.json` → Terraform variables → SSM Parameter Store (`SecureString`) → ECS task definition (via the `secrets` block). They're never plain env vars in the task definition, ECS console, or CloudWatch logs.

---

## Phase 4 — Terraform Apply

The backend uses partial configuration — pass the environment-specific backend file on init.

> **Switching environments in the same directory:** run `terraform init -reconfigure -backend-config=backend.<env>.hcl` to swap backends.

### Sandbox

```bash
cd infra/aws
export AWS_PROFILE=my-app-terraform-sandbox

../../scripts/tf-sops.sh decrypt sandbox

terraform init -backend-config=backend.sandbox.hcl
terraform plan -var-file=terraform.sandbox.tfvars
terraform apply -var-file=terraform.sandbox.tfvars
```

`terraform apply` will **pause** waiting for ACM certificate validation (you'll see `aws_acm_certificate_validation.main: Still creating...`). This is expected — see Phase 6 to unblock it.

When it completes, note the outputs:
```
alb_dns_name           = "my-app-sandbox-alb-xxxx.us-west-2.elb.amazonaws.com"
ecr_repository_url     = "123456789.dkr.ecr.us-west-2.amazonaws.com/my-app"
github_deploy_role_arn = "arn:aws:iam::123456789:role/my-app-sandbox-github-deploy"
```

### Prod

```bash
cd infra/aws
export AWS_PROFILE=my-app-terraform-prod

../../scripts/tf-sops.sh decrypt prod

terraform init -reconfigure -backend-config=backend.prod.hcl
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## Phase 5 — Set GitHub Actions Secrets

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value |
|--------|-------|
| `AWS_DEPLOY_ROLE_ARN_SANDBOX` | `github_deploy_role_arn` from sandbox terraform output |
| `AWS_DEPLOY_ROLE_ARN_PROD` | `github_deploy_role_arn` from prod terraform output |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL (optional, for deploy notifications) |

> **OIDC role conditions — sandbox vs prod must stay separate:**
> The sandbox role's trust policy is scoped to `refs/heads/main`. The prod role is scoped to `refs/tags/*` (release publishes). These conditions are mutually exclusive — keep them on separate roles.

---

## Phase 6 — Unblock ACM Certificate Validation

`terraform apply` pauses at `aws_acm_certificate_validation.main: Still creating...` because ACM needs to verify you own the domain. **While the apply is still running**, open a second terminal:

```bash
cd infra/aws
export AWS_PROFILE=my-app-terraform-sandbox

terraform output acm_certificate_validation_records
```

This returns something like:
```json
{
  "my-app-sandbox.example.com" = {
    "name"  = "_abc123.my-app-sandbox.example.com."
    "type"  = "CNAME"
    "value" = "_xyz456.acm-validations.aws."
  }
}
```

Add that CNAME to your DNS provider. Within ~2 minutes ACM validates and Terraform resumes.

Also add:
- **Sandbox:** CNAME `my-app-sandbox` → `alb_dns_name` from terraform output
- **Prod:** CNAME `my-app` → `alb_dns_name` from terraform output

> **If using Cloudflare:** Set SSL/TLS mode to **Full** (not Full Strict). The ALB terminates TLS via ACM — traffic from Cloudflare to the ALB is HTTPS on port 443. Add the ACM validation CNAME as DNS-only (grey cloud, not proxied).

---

## Phase 7 — First Deploy

**Sandbox** — the first deploy happens automatically on the next merge to `main` (after CI passes).

If you need to run migrations manually on first deploy:

```bash
aws ecs run-task \
  --cluster my-app-sandbox-cluster \
  --task-definition my-app-sandbox-app \
  --launch-type FARGATE \
  --network-configuration "$(aws ecs describe-services \
    --cluster my-app-sandbox-cluster \
    --services my-app-sandbox-app \
    --query 'services[0].networkConfiguration' \
    --output json)" \
  --overrides '{"containerOverrides":[{"name":"app","command":["/app/bin/migrate"]}]}' \
  --profile my-app-terraform-sandbox
```

**Prod** — triggered by publishing a GitHub release:

```bash
git tag v1.0.0
git push origin v1.0.0
# then create a release on GitHub from that tag
```

---

## Deploy Flow Going Forward

| Event | Environment |
|-------|-------------|
| Merge to `main` (CI passes) | AWS sandbox |
| GitHub release published | AWS prod |

---

## Troubleshooting

### `Credentials could not be loaded` in GitHub Actions

The OIDC token's `sub` claim doesn't match the IAM role's trust policy condition.

- **Sandbox** triggers on `workflow_run` from `main` — the sub is `ref:refs/heads/main`
- **Prod** triggers on `release: published` — the sub is `ref:refs/tags/vX.Y.Z`

If you collapsed them into a single role, one will always fail — keep them separate.

### Terraform fails on the OIDC provider

If the GitHub OIDC provider already exists in your AWS account (from another project), import it:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

terraform import aws_iam_openid_connect_provider.github \
  arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com
```

Then re-run `terraform apply`.

### ECS task fails to start

Check CloudWatch logs:

```bash
aws logs tail /ecs/my-app-sandbox --follow --profile my-app-terraform-sandbox
```

Common causes: bad `DATABASE_URL` SSM parameter, missing Peek/PostHog secrets, or misconfigured PHX_HOST.

### Migration task fails

The migration runs before the service update. If it fails, ECS is not updated — the old version keeps running. Check CloudWatch logs under the same log group.

### Health check failing

The ALB health check hits `GET /health`. Make sure the app started correctly. Common cause: bad `DATABASE_URL` (SSM parameter not set correctly).

### Check SSM parameters are correct

```bash
aws ssm get-parameter \
  --name /my-app/sandbox/database-url \
  --with-decryption \
  --profile my-app-terraform-sandbox \
  --query Parameter.Value \
  --output text
```

### Redis (optional)

If you add `enable_redis = true` to your tfvars, Terraform provisions an ElastiCache Redis cluster and injects `REDIS_URL` into the ECS task. Re-run `terraform apply` to create it.
