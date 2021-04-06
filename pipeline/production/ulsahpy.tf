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

resource "aws_security_group" "ulsahpy_app_sg" {
  name        = "ulsahpy_app_sg"
  vpc_id      = data.aws_vpc.default.id

  # Application port from anywhere
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
    Name = "ulsahpy_app_sg"
  }
}

resource "aws_security_group" "ulsahpy_lb_sg" {
  name        = "ulsahpy_lb_sg"
  vpc_id      = data.aws_vpc.default.id

  # HTTP from anywhere
  ingress {
    description = "HTTP ports open to internet"
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
    Name = "ulsahpy_lb_sg"
  }
}

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 2.0"

  name               = "ulsahpy-elb"

  security_groups    = [aws_security_group.ulsahpy_lb_sg.id]
  subnets            = data.aws_subnet_ids.all.ids
  internal           = false

  listener = [
    {
      instance_port     = 8081
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    },
  ]

  health_check = {
    target              = "HTTP:8081/healthy"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  // ELB attachments
  number_of_instances = 2
  instances           = [aws_instance.ulsahpy-a.id, aws_instance.ulsahpy-b.id]

  tags = {
    Owner       = "user"
    Environment = "prod"
  }
}

resource "aws_instance" "ulsahpy-a" {
  ami           = var.aws_image
  instance_type = "t2.micro"
  key_name      = "TestKP"
  vpc_security_group_ids = [aws_security_group.ulsahpy_app_sg.id]

  tags = {
    Name = "ulsahpy-a"
  }
}

resource "aws_instance" "ulsahpy-b" {
  ami           = var.aws_image
  instance_type = "t2.micro"
  key_name      = "TestKP"
  vpc_security_group_ids = [aws_security_group.ulsahpy_app_sg.id]

  tags = {
    Name = "ulsahpy-b"
  }
}

output "ulsahpy-elb-dnsname" {
  description = "The DNS name of the ELB"
  value       = module.elb_http.this_elb_dns_name
}
