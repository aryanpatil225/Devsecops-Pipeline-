# Provider
provider "aws" {
  region = var.region
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "devsecops-vpc"
  }
}

# Public Subnet (without auto-assign public IP) ✅ FIXES HIGH: AVD-AWS-0164
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false  # ✅ CHANGED to false
  
  tags = {
    Name = "devsecops-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "devsecops-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "devsecops-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group with restricted egress ✅ FIXES CRITICAL: AVD-AWS-0104
resource "aws_security_group" "app" {
  name        = "devsecops-app-sg"
  description = "Security group for DevSecOps application"
  vpc_id      = aws_vpc.main.id

  # Ingress - Application port
  ingress {
    description = "Application port"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - HTTPS only (for Docker Hub, SSM, etc.)
  egress {
    description = "HTTPS for AWS services and Docker"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - HTTP for package repos
  egress {
    description = "HTTP for package repositories"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-app-sg"
  }
}

# IAM Role for EC2 (SSM access)
resource "aws_iam_role" "ec2" {
  name = "devsecops-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "devsecops-ec2-role"
  }
}

# Attach SSM policy
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "devsecops-instance-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "devsecops-instance-profile"
  }
}

# Elastic IP (manually assigned)
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id
  
  tags = {
    Name = "devsecops-app-eip"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# EC2 Instance with encrypted volume ✅ FIXES HIGH: AVD-AWS-0131
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  
  user_data = base64encode(file("${path.module}/userdata.sh"))

  # Encrypted root volume ✅ FIXES HIGH: AVD-AWS-0131
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true  # ✅ ENCRYPTION ENABLED
    delete_on_termination = true
    
    tags = {
      Name = "devsecops-root-volume"
    }
  }

  # IMDSv2 enforced
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  monitoring = true

  tags = {
    Name = "devsecops-app"
  }
}

# Outputs
output "application_url" {
  description = "Application URL"
  value       = "http://${aws_eip.app.public_ip}:8000"
}

output "health_check_url" {
  description = "Health check"
  value       = "http://${aws_eip.app.public_ip}:8000/health"
}

output "public_ip" {
  description = "Elastic IP"
  value       = aws_eip.app.public_ip
}

output "instance_id" {
  description = "Instance ID"
  value       = aws_instance.app.id
}

output "ssm_connect" {
  description = "SSM connection command"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.region}"
}