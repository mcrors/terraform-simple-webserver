provider "aws" {
  region  = "eu-west-1"
  profile = "rory-terraform"
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
  name = "sg_terraform_webserver_example"
  ingress {
    to_port     = var.server_port
    from_port   = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_launch_configuration" "launch_config_webservers" {
  ami             = "ami-06fd8a495a537da8b"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.sg_webserver.id]
  user_data       = <<-EOF
                 #!/bin/bash
                 echo "Hello, World" > index.html
                 nohup busybox httpd -f -p ${var.server_port} &
                 EOF

  # Required when using launch configuration with auto scaling group
  lifecycle = {
    create_before_destory = true
  }
}


resource "aws_autoscaling_group" "auto_scl_grp_webserver" {
  launch_configuration = aws_launch_configuration.launch_config_webservers.name
  vpc_zone_identifier  = data.aws_subnet_ids.default_vpc_subnet_ids.ids

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-webserver"
    propagate_at_launch = true
  }
}

}

output "public_ip" {
  value       = aws_instance.webserver.public_ip
  description = "The public ip address of the webserver"
}