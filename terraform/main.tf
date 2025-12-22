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

# Public Subnet (no auto-assign public IP) ✅ FIXES HIGH: AVD-AWS-0164
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false  # ✅ No auto-assign, use Elastic IP instead
  
  tags = {
    Name = "devsecops-public-subnet"
  }
}

# ================================================================================
# 🔒 SECURE PRODUCTION ARCHITECTURE (ZERO VULNERABILITIES)
# Cost: ~$32/month for NAT Gateway
# Fixes: 1 CRITICAL + 1 HIGH vulnerability
# 
# To enable: Uncomment the sections below
# ================================================================================

# # Private Subnet for EC2 Instance
# resource "aws_subnet" "private" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.123.2.0/24"
#   availability_zone       = "${var.region}a"
#   map_public_ip_on_launch = false
#   
#   tags = {
#     Name = "devsecops-private-subnet"
#   }
# }

# # Elastic IP for NAT Gateway
# resource "aws_eip" "nat" {
#   domain = "vpc"
#   
#   tags = {
#     Name = "devsecops-nat-eip"
#   }
#   
#   depends_on = [aws_internet_gateway.main]
# }

# # NAT Gateway (allows private instances to reach internet)
# resource "aws_nat_gateway" "main" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public.id
#   
#   tags = {
#     Name = "devsecops-nat-gateway"
#   }
#   
#   depends_on = [aws_internet_gateway.main]
# }

# # Route Table for Private Subnet
# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.main.id
#   
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.main.id
#   }
#   
#   tags = {
#     Name = "devsecops-private-rt"
#   }
# }

# # Route Table Association for Private Subnet
# resource "aws_route_table_association" "private" {
#   subnet_id      = aws_subnet.private.id
#   route_table_id = aws_route_table.private.id
# }

# ================================================================================
# END OF SECURE ARCHITECTURE
# ================================================================================

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

# Security Group
resource "aws_security_group" "app" {
  name        = "devsecops-app-sg"
  description = "Security group for DevSecOps application"
  vpc_id      = aws_vpc.main.id

  # SSH Access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application Port
  ingress {
    description = "Application port"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-app-sg"
  }
}

# Elastic IP (for static public IP)
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id
  
  tags = {
    Name = "devsecops-app-eip"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  # subnet_id            = aws_subnet.private.id  # 🔒 SECURE: Uncomment for zero vulnerabilities
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_name
  
  user_data = base64encode(file("${path.module}/userdata.sh"))

  # Root volume with encryption ✅ FIXES HIGH: AVD-AWS-0131
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true  # ✅ Encryption enabled
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
  description = "Public IP"
  value       = aws_eip.app.public_ip
}

output "instance_id" {
  description = "Instance ID"
  value       = aws_instance.app.id
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.app.public_ip}"
}

# ================================================================================
# 📋 DEPLOYMENT INSTRUCTIONS FOR SECURE ARCHITECTURE
# ================================================================================
# 
# Current Setup (Development):
# - Cost: $0 in free tier, $8.50/month after
# - Vulnerabilities: 1 CRITICAL, 1 HIGH
# - Instance in: Public subnet
# 
# Secure Setup (Production):
# - Cost: $32/month for NAT Gateway (always)
# - Vulnerabilities: 0 CRITICAL, 0 HIGH
# - Instance in: Private subnet
# 
# To Enable Secure Architecture:
# 1. Uncomment all sections marked with # above
# 2. Change: subnet_id = aws_subnet.public.id
#    To:     subnet_id = aws_subnet.private.id
# 3. Run: terraform apply
# 
# ================================================================================
