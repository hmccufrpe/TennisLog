# Least-privilege role for the app hosts. Created only when create_iam_resources = true.
# In AWS Academy Learner Lab IAM creation is blocked, so the hosts use the pre-created
# LabInstanceProfile instead (see docs/decisoes-tecnicas.md).
# The role grants only: SSM access (no SSH keys), pulling the two ECR images and
# reading the DB password parameter.

locals {
  instance_profile_name = var.create_iam_resources ? aws_iam_instance_profile.app[0].name : var.instance_profile_name
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  count              = var.create_iam_resources ? 1 : 0
  name               = "${var.project}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Lets Session Manager and Run Command reach the instance.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = var.create_iam_resources ? 1 : 0
  role       = aws_iam_role.app[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this action does not support resource-level restriction
  }

  statement {
    sid = "EcrPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [for repo in aws_ecr_repository.app : repo.arn]
  }

  statement {
    sid       = "ReadDbPassword"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.db_password.arn]
  }

  # SecureString uses the AWS managed key; allow decrypt only when called through SSM.
  statement {
    sid       = "DecryptViaSsm"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "app" {
  count  = var.create_iam_resources ? 1 : 0
  name   = "${var.project}-app"
  role   = aws_iam_role.app[0].id
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_instance_profile" "app" {
  count = var.create_iam_resources ? 1 : 0
  name  = "${var.project}-ec2-profile"
  role  = aws_iam_role.app[0].name
}
