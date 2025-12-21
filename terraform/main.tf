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

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false
  
  tags = {
    Name = "devsecops-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "devsecops-igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "devsecops-rt"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "main" {
  name        = "devsecops-sg"
  description = "Security group for DevSecOps application"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Application access"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.123.0.0/16"]
  }

  tags = {
    Name = "devsecops-sg"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-south-1.s3"
  route_table_ids   = [aws_route_table.main.id]

  tags = {
    Name = "devsecops-s3-endpoint"
  }
}

resource "aws_instance" "main" {
  ami                    = "ami-0c44f651ab5e9285f"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]

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
  }

  monitoring = true
  user_data   = filebase64("${path.module}/userdata.sh")

  tags = {
    Name = "devsecops-app"
  }
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "instance_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.main.private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.main.id
}

output "s3_endpoint_id" {
  description = "S3 VPC Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}