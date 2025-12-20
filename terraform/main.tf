provider "aws" {
  region = "ap-south-1"
}

# VPC - FREE
resource "aws_vpc" "main" {
  cidr_block = "10.123.0.0/16"
  tags = {
    Name = "devsecops-free-vpc"
  }
}

# Public Subnet - FREE
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-free"
  }
}

# Internet Gateway - FREE
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "devsecops-igw-free"
  }
}

# Route Table - FREE
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# FIXED Security Group - NO SSH + Restricted Egress
resource "aws_security_group" "web_sg" {
  name        = "devsecops-sg-free"
  vpc_id      = aws_vpc.main.id
  description = "Secure SG - HTTP FastAPI only"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "FastAPI"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-sg-free"
  }
}

# FREE TIER EC2 with ALL FIXES
resource "aws_instance" "app" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = 20
  }

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
    return {"status": "DevSecOps FREE TIER App Live", "secure": True}
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

output "instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "instance_id" {
  value = aws_instance.app.id
}
