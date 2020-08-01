locals {
  num_azs = length(var.allowed_availability_zone_ids)
}

resource "aws_vpc" "wg_vpc" {
  cidr_block = var.vpc_cidr_range

  tags = {
    Terraform = true
  }
}

resource "aws_subnet" "wg_subnet_private" {
  count                   = local.num_azs
  vpc_id                  = aws_vpc.wg_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr_range, local.num_azs, count.index + 1)
  map_public_ip_on_launch = false
  availability_zone_id    = var.allowed_availability_zone_ids[count.index]
}

resource "aws_subnet" "wg_subnet_public" {
  count                   = local.num_azs
  vpc_id                  = aws_vpc.wg_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr_range, local.num_azs, count.index + local.num_azs + 1)
  map_public_ip_on_launch = true
  availability_zone_id    = var.allowed_availability_zone_ids[count.index]
}

resource "aws_security_group" "wg_security_group_external" {
  name        = "wireguard-external"
  description = "Allow Wireguard client traffic from internet"
  vpc_id      = aws_vpc.wg_vpc.id
}

resource "aws_security_group_rule" "wg_security_group_external_clients_ingress" {
  type              = "ingress"
  from_port         = var.wg_server_port
  to_port           = var.wg_server_port
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.wg_security_group_external.id
}

resource "aws_security_group_rule" "wg_security_group_external_clients_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.wg_security_group_external.id
}
