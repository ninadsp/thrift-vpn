data "aws_iam_policy_document" "wg_instance_profile_doc" {
  statement {
    sid = "SSMAccess"

    effect = "Allow"

    actions = ["ssm:GetParameters"]

    resources = [data.aws_ssm_parameter.wg_server_private_key]
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

resource "aws_iam_role" "wg_instance_role" {
  name               = "wg-instance-role"
  assume_role_policy = data.aws_iam_policy_document.wg_instance_profile_assume_role_doc.json
}

resource "aws_iam_instance_profile" "wg_instance_profile" {
  name = "wg-instance-profile"
  role = aws_iam_role.wg_instance_role.name
}
