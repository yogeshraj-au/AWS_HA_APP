#Initialize the module to retrieve the ami-id
module "server-ami" {
  source = "./modules/amilookup"
}

#Define a name
locals {
  name = "backend"
}

#Create a security group to allow ssh for the private ec2's
resource "aws_security_group" "backend_sg" {
  name        = "${local.name}-sg"
  description = "Allow ssh inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Access to the backend app"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-sg"
  }
}

#Create a security group rule to allow traffic from alb-sg to backend-sg
resource "aws_security_group_rule" "allow_traffic" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

#Create a security group for teh load balancer
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow http traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "allow traffic on port 8080"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Define the launch template
resource "aws_launch_template" "backend_template" {
  name_prefix   = "java"
  image_id      = module.server-ami.ami-id
  instance_type = var.backend_server_instance_type

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp2"
    }
  }

  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  user_data = filebase64("jardownload.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name}-asg"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "optional"
  }

  monitoring {
    enabled = true
  }

  key_name = aws_key_pair.server_ssh_key.id
  # Launch template versions
  lifecycle {
    create_before_destroy = true
  }
}

# Define the auto scaling group
resource "aws_autoscaling_group" "backend_asg" {

  name_prefix = "${local.name}-asg"
  launch_template {
    id      = aws_launch_template.backend_template.id
    version = "$Latest"
  }
  vpc_zone_identifier       = [module.vpc.private_subnets[0], module.vpc.private_subnets[1], module.vpc.private_subnets[2]]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size                      
  max_size                  = var.max_size                      
  target_group_arns         = [aws_lb_target_group.backend_target_group.arn] 
  metrics_granularity = "1Minute"
  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupTerminatingInstances", "GroupStandbyInstances", "GroupTotalInstances", "GroupInServiceCapacity", "GroupPendingCapacity", "GroupTerminatingCapacity", "GroupStandbyCapacity", "GroupTotalCapacity"]
}

# Define the application load balancer
resource "aws_lb" "backend-alb" {
  name                       = "${local.name}-alb"
  internal                   = false # Set to false if you want an internet-facing LB
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = toset(module.vpc.public_subnets) 
  enable_deletion_protection = true               
  tags = {
    Name = "${local.name}-alb"
  }
}

# Define the application load balancer target group
resource "aws_lb_target_group" "backend_target_group" {
  name_prefix = "jav-tg"
  port        = 8080 # Replace with your desired port
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id 
  health_check {
    interval = 30
    path     = "/"
    port     = 8080 # Replace with your desired port
    protocol = "HTTP"
    timeout  = 10
  }
  tags = {
    Name = "${local.name}-target-group"
  }
}

#Create an ALB listener for port 80 and forward traffic to the target group
resource "aws_lb_listener" "backend_http" {
  load_balancer_arn = aws_lb.backend-alb.arn
  port              = 80 
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_target_group.arn
  }
}

#Create a Route53 Record and map loadbalancers dns name to a custom dns name 
resource "aws_route53_record" "backend_record" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "${var.custom_dns_name}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.backend-alb.dns_name
    zone_id                = aws_lb.backend-alb.zone_id
    evaluate_target_health = true
  }
}

#Create SNS topic
resource "aws_sns_topic" "autoscaling_topic" {
  name = "autoscaling-topic"
}

#Create subscription to the SNS topic
resource "aws_sns_topic_subscription" "autoscaling_subscription" {
  topic_arn = aws_sns_topic.autoscaling_topic.arn
  protocol  = "email"
  endpoint  = "youremail@example.com"
}

#Create autoscaling policy for the cpu scale out
resource "aws_autoscaling_policy" "backend_scale_out_cpu_policy" {
  name                   = "backend-scale-out-cpu-policy"
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  scaling_adjustment     = 1
  cooldown               = 300

  depends_on = [
    aws_cloudwatch_metric_alarm.backend_scale_out_cpu_alarm
  ]
}

#Create cloudwatch alarm for the cpu scale out
resource "aws_cloudwatch_metric_alarm" "backend_scale_out_cpu_alarm" {
  alarm_name          = "backend-scale-out-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  threshold           = "70"
  alarm_description   = "CPU threshold exceeded - scaling out"
  alarm_actions       = [aws_sns_topic.autoscaling_topic.arn]
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  period              = "60"
  statistic           = "Average"

  dimensions = {
    name  = "AutoScalingGroupName"
    value = aws_autoscaling_group.backend_asg.name
  }
}

#Create autoscaling policy for the memory scale out
resource "aws_autoscaling_policy" "backend_scale_out_memory_policy" {
  name                   = "backend_scale_out_memory_policy"
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  scaling_adjustment     = 1
  cooldown               = 300

  depends_on = [
    aws_cloudwatch_metric_alarm.backend-scale-out-memory-alarm
  ]
}

#Create cloudwatch alarm for the memory scale out
resource "aws_cloudwatch_metric_alarm" "backend-scale-out-memory-alarm" {
  alarm_name          = "backend-scale-out-memory-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  threshold           = "60"
  alarm_description   = "Memory threshold exceeded - scaling out"
  alarm_actions       = [aws_sns_topic.autoscaling_topic.arn]
  namespace           = "AWS/EC2"
  metric_name         = "MemoryUtilization"
  period              = "60"
  statistic           = "Average"

  dimensions = {
    name  = "AutoScalingGroupName"
    value = aws_autoscaling_group.backend_asg.name
  }
}

#Create autoscaling policy for the cpu scale in
resource "aws_autoscaling_policy" "backend_scale_in_cpu_policy" {
  name                   = "backend-scale-in-cpu-policy"
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  scaling_adjustment     = 1
  cooldown               = 300
  
  depends_on = [
    aws_cloudwatch_metric_alarm.backend_scale_in_cpu_alarm
  ]
}

#Create cloudwatch alarm for the cpu scale in
resource "aws_cloudwatch_metric_alarm" "backend_scale_in_cpu_alarm" {
  alarm_name          = "backend-scale-in-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  threshold           = "60"
  alarm_description   = "CPU threshold is minimum - scaling in"
  alarm_actions       = [aws_sns_topic.autoscaling_topic.arn]
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  period              = "60"
  statistic           = "Average"

  dimensions = {
    name  = "AutoScalingGroupName"
    value = aws_autoscaling_group.backend_asg.name
  }
}

#Create autoscaling policy for the memory scale in
resource "aws_autoscaling_policy" "backend_scale_in_memory_policy" {
  name                   = "backend_scale_in_memory_policy"
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  scaling_adjustment     = 1
  cooldown               = 300
  
  depends_on = [
    aws_cloudwatch_metric_alarm.backend-scale-in-memory-alarm
  ]
}

#Create cloudwatch alarm for the memory scale in
resource "aws_cloudwatch_metric_alarm" "backend-scale-in-memory-alarm" {
  alarm_name          = "backend-scale-in-memory-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  threshold           = "50"
  alarm_description   = "Memory threshold is reduced - scaling in"
  alarm_actions       = [aws_sns_topic.autoscaling_topic.arn]
  namespace           = "AWS/EC2"
  metric_name         = "MemoryUtilization"
  period              = "60"
  statistic           = "Average"
  
  dimensions = {
    name  = "AutoScalingGroupName"
    value = aws_autoscaling_group.backend_asg.name
  }
}