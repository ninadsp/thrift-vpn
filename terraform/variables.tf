variable "ssh_key_id" {
  description = "Which SSH key ID to allow access to the Wireguard VPN instances"
  default     = "foo"
}

variable "instance_type" {
  description = "Instance size to use for the Wireguard VPN instance"
  default     = "t3a.nano"
  type        = string
}

variable "ami_id" {
  description = "Amazon Machine Image ID which has Wireguard pre-installed, to use for the VPN instance"
  type        = string
  default     = "foo"
}

variable "asg_min_size" {
  type        = number
  default     = 1
  description = "Minimum number of instances in the Auto Scaling Group"
}

variable "asg_max_size" {
  type        = number
  default     = 2
  description = "Maximum number of instances in the Auto Scaling Group"
}

variable "asg_desired_size" {
  type        = number
  default     = 1
  description = "Desired number of instances in the Auto Scaling Group"
}

# A /25 is recommended, can be a wider range than this
# Here's how to compute this: 
# Number of maximum IPs in _one_ availability zone/subnet * number of allowed subnets * 2 (private + public) 
variable "vpc_cidr_range" {
  type        = string
  default     = "10.0.0.0/25"
  description = "Range of IP addresses in the AWS Virtual Private Network"
}

variable "allowed_availability_zone_ids" {
  type        = list
  default     = ["aps1-az1", "aps1-az2", "aps1-az3"]
  description = "Which availability zones should we spin up Wireguard instances in?"
}

variable "ssh_allow_ip_range" {
  type        = string
  description = "Which IP addresses to allow ssh access from"
  default     = "127.0.0.1/32"
}

variable "wg_server_private_key_path" {
  description = "The SSM parameter configuration path containing the private key for the Wireguard server"
  type        = string
  default     = "foo"
}
