terraform {
  backend "s3" {
    bucket = "rhoulihan-terraform-state"
    key    = "stage/services/backend/terraform.tfstate"
    region = "eu-west-1"

    dynamodb_table = "rhoulihan-terraform-locks"
    encrypt        = true
    profile        = "rory-terraform"
  }
}

provider "aws" {
  region  = "eu-west-1"
  profile = "rory"
}

variable "server_port" {
  description = "The port the server will use for http requests"
  type        = number
  default     = 8080
}


data "aws_vpc" "default_vpc" {
  default = true
}


data "aws_subnet_ids" "default_vpc_subnet_ids" {
  vpc_id = data.aws_vpc.default_vpc.id
}


resource "aws_security_group" "sg_webserver" {
  name = "sg_terraform_webserver"
  ingress {
    to_port     = var.server_port
    from_port   = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "sg_alb" {
  name = "sg_terraform_webserver_alb"

  # Allow inbound http requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "launch_config_webservers" {
  image_id        = "ami-06fd8a495a537da8b"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.sg_webserver.id]
  user_data       = <<-EOF
                 #!/bin/bash
                 echo "Hello, World" > index.html
                 nohup busybox httpd -f -p ${var.server_port} &
                 EOF

  # Required when using launch configuration with auto scaling group
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "auto_scl_grp_webserver" {
  launch_configuration = aws_launch_configuration.launch_config_webservers.name
  vpc_zone_identifier  = data.aws_subnet_ids.default_vpc_subnet_ids.ids

  target_group_arns = [aws_lb_target_group.webserver_target_group.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-webserver"
    propagate_at_launch = true
  }
}


resource "aws_lb" "lb_webserver" {
  name               = "terraform-asg-lb-webserver"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default_vpc_subnet_ids.ids
  security_groups    = [aws_security_group.sg_alb.id]
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb_webserver.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}


resource "aws_lb_target_group" "webserver_target_group" {
  name     = "terraform-tgt-grp-webserver"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}


resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver_target_group.arn
  }
}


output "alb_dns_name" {
  value       = aws_lb.lb_webserver.dns_name
  description = "The domain name of the load balancer"
}