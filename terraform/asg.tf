data "aws_ami" "wg_ami" {
  owners = [
  "self"]
  most_recent = true

  filter {
    name = "name"
    values = [
    "packer-debian-wireguard-thrift*"]
  }

  filter {
    name = "root-device-type"
    values = [
    "ebs"]
  }

  filter {
    name = "virtualization-type"
    values = [
    "hvm"]
  }
}

locals {
  user_data = templatefile(
    "${path.module}/templates/user-data.txt",
    {
      wg_server_listen_addr = var.wg_server_listen_addr
      wg_server_port        = var.wg_server_port
      wg_priv_key_path      = var.wg_server_private_key_path
      region                = var.region
      peers                 = local.wg_client_template

      post_provisioning_steps = var.post_provisioning_steps
    }
  )

  wg_client_template = templatefile(
    "${path.module}/templates/client-data.tpl",
    {
      wg_client_pub_keys = var.wg_client_pub_keys
    }
  )
}

resource "aws_launch_template" "wg_launch_template" {
  name_prefix                          = "debian-wireguard-launch-template-"
  image_id                             = data.aws_ami.wg_ami.id
  instance_type                        = var.instance_type
  ebs_optimized                        = true
  key_name                             = var.ssh_key_id
  instance_initiated_shutdown_behavior = "terminate"

  credit_specification {
    cpu_credits = "standard"
  }

  user_data = base64encode(local.user_data)
  iam_instance_profile {
    arn = aws_iam_instance_profile.wg_instance_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.wg_security_group_external.id]
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "terminate"
      spot_instance_type             = "one-time"
      max_price                      = var.spot_max_price
    }
  }


  tags = {
    Terraform = true
    role      = "wireguard-vpn"
  }
}

resource "aws_autoscaling_group" "wg_asg" {
  name             = "wireguard_asg"
  max_size         = var.asg_max_size
  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_size

  vpc_zone_identifier = aws_subnet.wg_subnet_public[*].id

  launch_template {
    id      = aws_launch_template.wg_launch_template.id
    version = "$Latest"
  }

  # 3600 * 24 * 31 = 1 Month
  max_instance_lifetime = 2678400
}
