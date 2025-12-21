terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "devsecops-vpc"
  }
}

resource "aws_subnet" "app_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false
  
  tags = {
    Name = "secure-private-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "devsecops-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name        = "devsecops-secure"
  description = "Security group for DevSecOps application"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Application port access"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-secure"
  }
}

resource "aws_instance" "app" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    encrypted             = true
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    
    tags = {
      Name = "devsecops-root-volume"
    }
  }

  monitoring = true

  user_data = filebase64("${path.module}/userdata.sh")

  tags = {
    Name        = "devsecops-secure-app"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/devsecops-app"
  retention_in_days = 7
  
  tags = {
    Name = "devsecops-app-logs"
  }
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.app.id
}