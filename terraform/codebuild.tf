resource "aws_codebuild_project" "wg_build_ami" {
  name        = "wg_build_ami_scheduled"
  description = "Create Wireguard AMIs"

  service_role = aws_iam_role.codebuild_service_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "CPU_ARCH"
      value = length(regexall(".*g$", element(split(".", var.instance_type), 0))) == 1 ? "arm64" : "amd64"
    }

    environment_variable {
      name  = "INSTANCE_TYPE"
      value = var.instance_type
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/wg_build_ami"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/ninadsp/thrift-vpn.git"
    git_clone_depth = 1
  }

  source_version = "master"

  tags = {
    Terraform = true
  }
}

resource "aws_cloudwatch_event_rule" "codebuild_trigger_rule" {
  name        = "wg_build_trigger_rule"
  description = "Trigger Wireguard AMI build once a month"

  schedule_expression = "cron(5 12 1 * ? *)"
}

resource "aws_cloudwatch_event_target" "codebuild_trigger_target" {
  rule     = aws_cloudwatch_event_rule.codebuild_trigger_rule.name
  arn      = aws_codebuild_project.wg_build_ami.arn
  role_arn = aws_iam_role.codebuild_trigger_role.arn
}
