terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.33.0"
    }
  }
}

provider "aws" {
	region = "eu-north-1"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet_public" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/16"
}

resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.rtb_public.id
}

resource "aws_eip" "ip_test_env" {
  instance = "${aws_spot_instance_request.calibre.spot_instance_id}"
  domain   = "vpc"

}
resource "aws_security_group" "sg_22_80" {
  name   = "sg_22"
  vpc_id = aws_vpc.vpc.id

  # SSH access from the VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
data "template_file" "user_data" {
  template = file("./scripts/cloud_init.yaml") 
}
resource "aws_spot_instance_request" "calibre" {
  ami           = "ami-0014ce3e52359afbd"
  instance_type = "t3.medium"
  subnet_id                   = aws_subnet.subnet_public.id
  vpc_security_group_ids      = [aws_security_group.sg_22_80.id]
  key_name = "calibre"
  wait_for_fulfillment = true
  user_data = data.template_file.user_data.rendered 
  tags = {
    Name = "Calibre Backend"
  }

}
output "public_ip" {
  value = aws_eip.ip_test_env.public_ip
}

