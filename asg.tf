resource "aws_launch_template" "app" {
  name_prefix            = "${var.environment}-lt-"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.instances.id]

  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    environment = var.environment
  }))

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.environment}-asg"
  min_size            = var.asg_min
  max_size            = var.asg_max
  desired_capacity    = var.asg_desired
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}
