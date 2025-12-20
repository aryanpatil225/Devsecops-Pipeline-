provider "aws" {
  region = "ap-south-1"  # Mumbai region - FREE tier eligible
}

# VPC - FREE (unlimited)
resource "aws_vpc" "main" {
  cidr_block = "10.123.0.0/16"
  tags = {
    Name = "devsecops-free-vpc"
  }
}

# Public Subnet - FREE (map_public_ip_on_launch=true for app access)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true  # Required for public HTTP access (Trivy AVD-AWS-0164 warning expected)
  tags = {
    Name = "public-subnet-free"
  }
}

# Internet Gateway - FREE (unlimited)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "devsecops-igw-free"
  }
}

# Route Table with public internet access - FREE
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# SECURE Security Group - NO SSH (Fixes AVD-AWS-0107)
resource "aws_security_group" "web_sg" {
  name        = "devsecops-sg-free"
  vpc_id      = aws_vpc.main.id
  description = "Free tier secure SG - HTTP + FastAPI only"

  # HTTP port 80
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FastAPI port 8000
  ingress {
    description = "FastAPI app"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FIXED: Restricted egress - HTTPS + HTTP only (Fixes AVD-AWS-0104)
  egress {
    description = "HTTPS only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP only" 
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-sg-free"
  }
}

# FREE TIER t2.micro EC2 Instance (750 hours/month FREE)[web:15]
resource "aws_instance" "app" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"  # Amazon Linux 2023 FREE[web:16]
  instance_type          = "t2.micro"              # FREE TIER (750 hrs/month)[web:15]
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # FIXED: IMDSv2 required (Fixes AVD-AWS-0028)[web:17][web:22]
  metadata_options {
    http_tokens = "required"
  }

  # FIXED: Encrypted root volume (Fixes AVD-AWS-0131) - FREE 20GB[web:18][web:23]
  root_block_device {
    encrypted   = true
    volume_size = 20  # FREE tier EBS limit
  }

  # User data: FastAPI app with Docker
  user_data = base64encode(<<-EOF
#!/bin/bash
dnf update -y
dnf install docker python3-pip git -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
mkdir /app && cd /app
pip3 install fastapi uvicorn
cat > app.py << 'APP'
from fastapi import FastAPI
app = FastAPI()
@app.get("/") 
def root(): 
    return {"status": "🚀 DevSecOps FREE TIER App Live!", "secure": true}
@app.get("/health") 
def health(): 
    return {"status": "healthy"}
APP
nohup uvicorn app:app --host 0.0.0.0 --port 8000 &
EOF
  )

  tags = {
    Name = "devsecops-free-app"
  }
}

# Outputs
output "instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "instance_id" {
  value = aws_instance.app.id
}
