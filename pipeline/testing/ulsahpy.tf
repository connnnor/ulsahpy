variable "aws_image" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "ulsahpy_test" {
  name        = "ulsahpy_test"
  description = "Allow ICMP ping, and HTTP for application"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "ICMP for pinging"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask Port"
    from_port   = 8081
    to_port     = 8081
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
    Name = "ulsahpy-test-sg"
  }
}

resource "aws_instance" "ulsahpy-latest" {
  ami           = var.aws_image
  instance_type = "t2.micro"
  key_name      = "TestKP"
  vpc_security_group_ids = [aws_security_group.ulsahpy_test.id]

  tags = {
    Name = "ulsahpy-test"
  }
}

output "ulsahpy-test-ip" {
  value = aws_instance.ulsahpy-latest.public_ip
}
