# VPC with a really small range
# Public subnet
# Security groups

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
  count                   = num_azs
  vpc_id                  = aws_vpc.wg_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr_range, num_azs, count.index + 1)
  map_public_ip_on_launch = false
  availability_zone_id    = var.allowed_availability_zone_ids[count.index]
}

resource "aws_subnet" "wg_subnet_public" {
  count                   = num_azs
  vpc_id                  = aws_vpc.wg_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr_range, num_azs, count.index + num_azs + 1)
  map_public_ip_on_launch = true
  availability_zone_id    = var.allowed_availability_zone_ids[count.index]
}
