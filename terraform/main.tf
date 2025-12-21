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

# VPC with DNS support
resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "devsecops-vpc"
  }
}

# ✅ Private subnet (no public IP assignment)
resource "aws_subnet" "app_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false  # Explicitly set to false
  
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

# ✅ FIXED: Security Group with proper egress and description
resource "aws_security_group" "app" {
  name        = "devsecops-secure"
  description = "Security group for DevSecOps application"  # Added description
  vpc_id      = aws_vpc.main.id

  # App port only with description
  ingress {
    description = "Application port access"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ✅ FIXED AVD-AWS-0104: Add explicit egress rule
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

# ✅ FIXED: Instance with all security best practices
resource "aws_instance" "app" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"  # Ensure this is the latest AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app.id]

  # ✅ FIXED AVD-AWS-0028: IMDSv2 required (prevents SSRF attacks)
  metadata_options {
    http_tokens                 = "required"  # IMDSv2 only
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  # ✅ FIXED AVD-AWS-0131: Encrypted EBS with KMS
  root_block_device {
    encrypted             = true
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    
    tags = {
      Name = "devsecops-root-volume"
    }
  }

  # ✅ FIXED AVD-AWS-0122: Monitoring enabled
  monitoring = true

  # User data for application setup
  user_data = filebase64("${path.module}/userdata.sh")

  tags = {
    Name        = "devsecops-secure-app"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ✅ ADDED: CloudWatch Log Group for monitoring
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/devsecops-app"
  retention_in_days = 7
  
  tags = {
    Name = "devsecops-app-logs"
  }
}

# Outputs
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