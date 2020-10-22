provider "aws" {
  region  = "eu-west-1"
  profile = "rory-terraform"
}

resource "aws_instance" "webserver" {
  ami           = "ami-06fd8a495a537da8b"
  instance_type = "t2.micro"
  tags = {
    Name = "terraform-example"
  }
}