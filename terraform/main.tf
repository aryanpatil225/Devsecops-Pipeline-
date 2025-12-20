provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.123.0.0/16"
  tags = {
    Name = "devsecops-vpc"
  }
}

resource "aws_subnet" "app_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.123.1.0/24"
  availability_zone = "ap-south-1a"
  # NO map_public_ip_on_launch = true ✅
  tags = {
    Name = "secure-subnet"
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

resource "aws_security_group" "app" {
  name   = "devsecops-vulnerable"
  vpc_id = aws_vpc.main.id

  # 🚨 VULNERABILITY: SSH open to world
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-vulnerable"
  }
}  ami                    = "ami-0f5ee6cb1e35c1d3d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app.id]
  # NO associate_public_ip_address ✅

  metadata_options {
    http_tokens = "required"  # IMDSv2 ✅
  }

  root_block_device {
    encrypted   = true        # Encrypted EBS ✅
    volume_size = 20
  }

  user_data = filebase64("${path.module}/userdata.sh")

  tags = {
    Name = "devsecops-secure-app"
  }
}

output "instance_id" {
  value = aws_instance.app.id
}
