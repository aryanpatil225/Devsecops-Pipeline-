provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.123.0.0/16"
  tags = {
    Name = "devsecops-vpc-secure"
  }
}

# Private Subnet (NO public IP)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false  # FIXED: AVD-AWS-0164
  tags = {
    Name = "private-subnet-secure"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "devsecops-igw"
  }
}

# NAT Gateway for private subnet outbound
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_nat.id
  tags = {
    Name = "devsecops-nat"
  }
}

# Public subnet for NAT
resource "aws_subnet" "public_nat" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.2.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-nat-subnet"
  }
}

# Route Tables
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "private-rt-secure"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# SECURE Security Group (NO SSH!)
resource "aws_security_group" "web_sg" {
  name        = "devsecops-sg-secure"
  vpc_id      = aws_vpc.main.id
  description = "Secure SG for DevSecOps app"  # FIXED: Description added

  # HTTP
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App port 8000 (ALB only - restrict later)
  ingress {
    description = "App from ALB"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.123.0.0/16"]  # VPC only
  }

  # FIXED: NO SSH PORT 22!
  # FIXED: Restricted egress (no 0.0.0.0/0 all ports)
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-sg-secure"
  }
}

# SECURE EC2 (Private subnet)
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id  # Private subnet!
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  # FIXED: AVD-AWS-0028 - IMDSv2 required
  metadata_options {
    http_tokens = "required"
  }

  # FIXED: AVD-AWS-0131 - Encrypted root volume
  root_block_device {
    encrypted   = true
    volume_size = 20
  }

  user_data = base64encode
#!/bin/bash
dnf update -y
dnf install docker python3-pip git -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
mkdir /app && cd /app
pip3 install fastapi uvicorn
cat > app.py << APP
from fastapi import FastAPI
app = FastAPI()
@app.get("/")
def root(): return {"status": "DevSecOps Secure App!"}
@app.get("/health")
def health(): return {"status": "healthy"}
APP
nohup uvicorn app:app --host 0.0.0.0 --port 8000 &

  

  tags = {
    Name = "devsecops-app-secure"
  }
}

# Application Load Balancer (Public access)
resource "aws_lb" "app_lb" {
  name               = "devsecops-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_nat.id]

  tags = {
    Name = "devsecops-alb"
  }
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "devsecops-alb-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "App backend"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.123.0.0/16"]
  }

  tags = {
    Name = "devsecops-alb-sg"
  }
}

output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}
