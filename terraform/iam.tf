data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "wg_instance_profile_doc" {
  statement {
    sid = "SSMAccess"

    effect = "Allow"

    actions = ["ssm:GetParameters"]

    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/wireguard/*"]
  }

  statement {
    sid = "KMSAccess"

    effect = "Allow"

    actions = ["kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]

    resources = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"]
  }

  statement {
    sid = "InstanceRenameAccess"

    effect = "Allow"

    actions = ["ec2:CreateTags"]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/aws:autoscaling:groupName"
      values   = [aws_autoscaling_group.wg_asg.name]
    }
  }
}

data "aws_iam_policy_document" "wg_instance_profile_assume_role_doc" {
  statement {

    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild_service_profile_doc" {
  statement {
    sid    = "CodeBuildService"
    effect = "Allow"

    actions = [
      "iam:GetInstanceProfile",
      "s3:GetBucketAcl",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "s3:PutObject",
      "s3:GetObject",
      "logs:CreateLogStream",
      "codebuild:UpdateReport",
      "codebuild:BatchPutCodeCoverages",
      "codebuild:BatchPutTestCases",
      "s3:GetBucketLocation",
      "s3:GetObjectVersion"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*",
      "arn:aws:codebuild:${var.region}:${data.aws_caller_identity.current.account_id}:report-group/wg_build_ami-*",
      "arn:aws:s3:::codepipeline-${var.region}-*",
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/wg_build_ami",
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/wg_build_ami:*"
    ]
  }

  statement {
    sid    = "PackerSecurityGroups"
    effect = "Allow"

    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PackerAMIs"
    effect = "Allow"

    actions = [
      "ec2:CreateImage",
      "ec2:RegisterImage",
      "ec2:DeregisterImage",
      "ec2:DescribeImages",
      "ec2:ModifyImageAttribute"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PackerSnapshots"
    effect = "Allow"

    actions = [
      "ec2:CreateSnapshot",
      "ec2:DeleteSnaphot",
      "ec2:DescribeSnapshots"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PackerInstances"
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:RebootInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstances",
      "ec2:CreateTags",
      "ec2:DescribeRegions"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PackerVolumes"
    effect = "Allow"

    actions = [
      "ec2:AttachVolume",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:DescribeVolume*",
      "ec2:DetachVolume"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PackerKeypairs"
    effect = "Allow"

    actions = [
      "ec2:CreateKeyPair",
      "ec2:DeleteKeyPair",
      "ec2:DescribeKeyPairs"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AMICleanerASG"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLaunchConfigurations"
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "codebuild_profile_assume_role_doc" {
  statement {

    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild_trigger_role_doc" {
  statement {
    effect    = "Allow"
    actions   = ["codebuild:StartBuild"]
    resources = [aws_codebuild_project.wg_build_ami.arn]
  }
}

data "aws_iam_policy_document" "codebuild_trigger_assume_role_doc" {
  statement {

    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}
resource "aws_iam_policy" "wg_instance_policy" {
  name        = "wg_instance_policy"
  description = "Allow Wireguard Instance access to AWS resources via IAM"

  policy = data.aws_iam_policy_document.wg_instance_profile_doc.json
}

resource "aws_iam_role" "wg_instance_role" {
  name               = "wg-instance-role"
  assume_role_policy = data.aws_iam_policy_document.wg_instance_profile_assume_role_doc.json
}

resource "aws_iam_role_policy_attachment" "wg_instance_role_policy_attachment" {
  role       = aws_iam_role.wg_instance_role.name
  policy_arn = aws_iam_policy.wg_instance_policy.arn
}

resource "aws_iam_instance_profile" "wg_instance_profile" {
  name = "wg-instance-profile"
  role = aws_iam_role.wg_instance_role.name
}

resource "aws_iam_policy" "codebuild_service_policy" {
  name        = "codebuild_service_policy"
  description = "Allow CodeBuild access to resources needed to build AMIs"

  policy = data.aws_iam_policy_document.codebuild_service_profile_doc.json
}

resource "aws_iam_role" "codebuild_service_role" {
  name               = "codebuild_service_role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_profile_assume_role_doc.json
}

resource "aws_iam_role_policy_attachment" "codebuild_service_role_policy_attachment" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = aws_iam_policy.codebuild_service_policy.arn
}

resource "aws_iam_policy" "codebuild_trigger_service_policy" {
  name        = "codebuild_trigger_service_policy"
  description = "Allow CodeBuild access to resources needed to build AMIs"

  policy = data.aws_iam_policy_document.codebuild_trigger_role_doc.json
}

resource "aws_iam_role" "codebuild_trigger_role" {
  name               = "codebuild-trigger-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trigger_assume_role_doc.json
}

resource "aws_iam_role_policy_attachment" "codebuild_trigger_role_policy_attachment" {
  role       = aws_iam_role.codebuild_trigger_role.name
  policy_arn = aws_iam_policy.codebuild_trigger_service_policy.arn
}
