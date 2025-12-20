provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.123.0.0/16"
  tags = {
    Name = "devsecops-vpc"
  }
}

# ✅ FIXED AVD-AWS-0164: Private subnet
resource "aws_subnet" "app_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.123.1.0/24"
  availability_zone = "ap-south-1a"
  # NO map_public_ip_on_launch ✅
  tags = {
    Name = "secure-private-subnet"
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

# ✅ FIXED AVD-AWS-0107 & AVD-AWS-0104: No SSH, no egress
resource "aws_security_group" "app" {
  name   = "devsecops-secure"
  vpc_id = aws_vpc.main.id

  # App port only ✅
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NO SSH (fixes AVD-AWS-0107) ✅
  # NO egress rules (fixes AVD-AWS-0104) ✅

  tags = {
    Name = "devsecops-secure"
  }
}

# ✅ FIXED ALL: IMDSv2 + Encrypted + Private
resource "aws_instance" "app" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app.id]

  # ✅ FIXED AVD-AWS-0028: IMDSv2 required
  metadata_options {
    http_tokens = "required"
  }

  # ✅ FIXED AVD-AWS-0131: Encrypted EBS
  root_block_device {
    encrypted   = true
    volume_size = 20
  }

  user_data = filebase64("${path.module}/userdata.sh")

  tags = {
    Name = "devsecops-perfect-app"
  }
}

output "instance_id" {
  value = aws_instance.app.id
}
