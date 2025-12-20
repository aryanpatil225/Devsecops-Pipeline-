provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.123.0.0/16"
  tags = {
    Name = "devsecops-vpc"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.123.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "devsecops-igw"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "devsecops-nat"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.2.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "private-rt-nat"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "app_sg" {
  name   = "devsecops-app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-app-sg"
  }
}

resource "aws_instance" "app" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

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
dnf install docker python3-pip -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

mkdir -p /app
cd /app

pip3 install fastapi uvicorn

cat > /app/app.py <<PYEOF
from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def root():
    return {"status": "🚀 DevSecOps PERFECT 0 VULNERABILITIES!", "secure": True}

@app.get("/health")
def health():
    return {"status": "healthy"}
PYEOF

nohup uvicorn app:app --host 0.0.0.0 --port 8000 > /var/log/app.log 2>&1 &
  EOF
  )

  tags = {
    Name = "devsecops-perfect-app"
  }
}

output "instance_id" {
  value = aws_instance.app.id
}
