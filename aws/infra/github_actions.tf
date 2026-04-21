# --- GitHub Actions OIDC → AWS ---
#
# Allows GitHub Actions to assume an IAM role without storing long-lived
# AWS credentials as secrets. Uses the official GitHub OIDC provider.

variable "github_repo" {
  description = "GitHub repo in owner/repo format (e.g. peek-travel/my-app)"
  type        = string
  default     = "peek-travel/phoenix-starter-kit"
}

data "aws_caller_identity" "current" {}

# Fetch GitHub's current OIDC certificate thumbprint dynamically so it stays
# up to date if GitHub rotates their TLS cert.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# GitHub's OIDC provider (one per AWS account — safe to declare here,
# Terraform will error if it already exists; import it with:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com)
resource "aws_iam_openid_connect_provider" "github" {
  for_each = var.environment == "sandbox" ? { "this" = "this" } : {}

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# IAM role that GitHub Actions assumes on main-branch CI runs (sandbox deploys)
resource "aws_iam_role" "github_deploy" {
  for_each = var.environment == "sandbox" ? { "this" = "this" } : {}

  name = "${local.name_prefix}-github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github["this"].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Only main-branch runs on this repo can assume this role
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

# ECR — push images
resource "aws_iam_role_policy" "github_deploy_ecr" {
  for_each = var.environment == "sandbox" ? { "this" = "this" } : {}

  name = "${local.name_prefix}-github-ecr"
  role = aws_iam_role.github_deploy["this"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

# ECS — run migrations + rolling deploys
resource "aws_iam_role_policy" "github_deploy_ecs" {
  for_each = var.environment == "sandbox" ? { "this" = "this" } : {}

  name = "${local.name_prefix}-github-ecs"
  role = aws_iam_role.github_deploy["this"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Actions that support the ecs:cluster condition key
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:UpdateService",
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = aws_ecs_cluster.main.arn
          }
        }
      },
      # RegisterTaskDefinition and DescribeTaskDefinition are account-scoped —
      # the cluster condition is not enforced for these actions
      {
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
        Resource = "*"
      },
      # Allow ECS to pass the task execution + task roles when running tasks
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.ecs_execution.arn,
          aws_iam_role.ecs_task.arn,
        ]
      }
    ]
  })
}

output "github_deploy_role_arn" {
  description = "Set this as AWS_DEPLOY_ROLE_ARN_SANDBOX in GitHub Actions secrets"
  value       = try(aws_iam_role.github_deploy["this"].arn, null)
}
