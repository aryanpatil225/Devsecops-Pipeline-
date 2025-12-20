provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = "10.123.0.0/16"
  tags = {
    Name = "devsecops-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# ❌ INTENTIONAL VULNERABILITY
resource "aws_security_group" "web_sg" {
  name   = "devsecops-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-USERDATA
#!/bin/bash
dnf update -y
dnf install -y docker python3-pip git
systemctl start docker
systemctl enable docker
pip3 install fastapi uvicorn

cat > /app.py << 'APP'
from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def root():
    return {"status": "DevSecOps App Live!"}
APP

nohup uvicorn app:app --host 0.0.0.0 --port 8000 &
USERDATA
  )

  tags = {
    Name = "devsecops-app"
  }
}
