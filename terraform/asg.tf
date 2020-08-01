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

resource "aws_launch_template" "wg_launch_template" {
  name_prefix = "debian-wireguard-launch-template-"
  image_id = data.aws_ami.wg_ami.id
  instance_type = var.instance_type
  ebs_optimized = true
  key_name = var.ssh_key_id
  instance_initiated_shutdown_behavior = "terminate"

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination = true
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "terminate"
      spot_instance_type = "persistent"
      max_price = var.spot_max_price
    }
  }

  vpc_security_group_ids = [
    aws_security_group.wg_security_group_external.id]

  tags = {
    Terraform = true
    role = "wireguard-vpn"
  }
}

resource "aws_autoscaling_group" "wg_asg" {
  max_size = var.asg_max_size
  min_size = var.asg_min_size
  desired_capacity = var.asg_desired_size

  availability_zones = var.allowed_availability_zone_ids

  launch_template {
    id = aws_launch_template.wg_launch_template.id
    version = "$Latest"
  }
}