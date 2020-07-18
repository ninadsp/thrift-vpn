resource "null_resource" "check-min-asg-size" {
  count = var.asg_min_size < 1 ? 1 : 0
  triggers = {
    "Please specify a valid minimum ASG size (1 or more)" = 1
  }
}

resource "null_resource" "check-asg-desired-size" {
  count = var.asg_desired_size >= var.asg_min_size && var.asg_desired_size <= var.asg_max_size ? 0 : 1
  triggers = {
    "Desired size for the ASG is not within the range of minimum/maximum ASG sizes specified" = 1
  }
}
