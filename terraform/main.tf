# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "devsecops-vpc"
  }
}

# Subnet (Private, no public IP on launch)
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false  # ✅ Fixes HIGH vulnerability
  
  tags = {
    Name = "devsecops-subnet"
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
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Security Group - Restricted egress to specific ports only
resource "aws_security_group" "main" {
  name        = "devsecops-sg"
  description = "Security group for DevSecOps application"
  vpc_id      = aws_vpc.main.id

  # Ingress - Application port
  ingress {
    description = "Application access"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - HTTPS only (for package downloads)
  egress {
    description = "HTTPS for package management"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - HTTP only (for package repos)
  egress {
    description = "HTTP for package repos"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - VPC internal communication
  egress {
    description = "VPC internal"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.123.0.0/16"]
  }

  tags = {
    Name = "devsecops-sg"
  }
}

# VPC Endpoint for S3 (Free)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-south-1.s3"
  
  route_table_ids = [aws_route_table.main.id]
  
  tags = {
    Name = "devsecops-s3-endpoint"
  }
}

# Elastic IP (Free if attached to running instance)
resource "aws_eip" "main" {
  domain   = "vpc"
  instance = aws_instance.main.id
  
  tags = {
    Name = "devsecops-eip"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"
  instance_type          = "t2.micro"  # Free tier eligible
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
    
    tags = {
      Name = "devsecops-volume"
    }
  }

  monitoring = true
  user_data  = filebase64("${path.module}/userdata.sh")

  tags = {
    Name = "devsecops-app"
  }
}

# Outputs
output "application_url" {
  description = "🌐 Open this URL in your browser!"
  value       = "http://${aws_eip.main.public_ip}:8000"
}

output "health_check_url" {
  description = "❤️ Health check endpoint"
  value       = "http://${aws_eip.main.public_ip}:8000/health"
}

output "instance_public_ip" {
  description = "EC2 Public IP"
  value       = aws_eip.main.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.main.id
}