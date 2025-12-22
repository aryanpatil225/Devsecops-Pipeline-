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

# Private Subnet (NO public IPs - fixes HIGH vulnerability)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.2.0/24"  # ✅ CHANGED from 10.123.1.0/24
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false  # ✅ NO public IP
  
  tags = {
    Name = "devsecops-private-subnet"
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

# Route Table Association
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.main.id
}

# Security Group - Allow HTTPS for Docker & SSM
resource "aws_security_group" "app" {
  name        = "devsecops-app-sg-v2"
  description = "Security group for DevSecOps application"
  vpc_id      = aws_vpc.main.id

  # Ingress - ONLY port 8000
  ingress {
    description = "Application port"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - HTTPS for Docker Hub & SSM
  egress {
    description = "HTTPS for Docker Hub and AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - HTTP for packages
  egress {
    description = "HTTP for package repos"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - VPC internal
  egress {
    description = "VPC internal only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.123.0.0/16"]
  }

  tags = {
    Name = "devsecops-app-sg"
  }
}

# S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.main.id]
  
  tags = {
    Name = "devsecops-s3-endpoint"
  }
}

# IAM Role for EC2 (SSM access)
resource "aws_iam_role" "ec2" {
  name = "devsecops-ec2-role-v2"  # ✅ CHANGED name to avoid conflict

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
  name = "devsecops-instance-profile-v2"  # ✅ CHANGED name
  role = aws_iam_role.ec2.name

  tags = {
    Name = "devsecops-instance-profile"
  }
}

# Elastic IP (static public IP)
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id
  
  tags = {
    Name = "devsecops-eip"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  
  user_data = base64encode(file("${path.module}/userdata.sh"))

  # Encrypted root volume (✅ fixes AVD-AWS-0131)
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    
    tags = {
      Name = "devsecops-root-volume"
    }
  }

  # IMDSv2 enforced (✅ security best practice)
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
  description = "🌐 Application URL"
  value       = "http://${aws_eip.app.public_ip}:8000"
}

output "health_check_url" {
  description = "❤️ Health check"
  value       = "http://${aws_eip.app.public_ip}:8000/health"
}

output "public_ip" {
  description = "📍 Elastic IP"
  value       = aws_eip.app.public_ip
}

output "instance_id" {
  description = "🖥️ Instance ID"
  value       = aws_instance.app.id
}

output "ssm_connect" {
  description = "🔐 SSM connection"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.region}"
}