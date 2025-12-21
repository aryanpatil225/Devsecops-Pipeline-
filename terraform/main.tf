provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "devsecops-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false
  
  tags = {
    Name = "devsecops-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "devsecops-igw"
  }
}

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

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "main" {
  name        = "devsecops-sg"
  description = "Security group for DevSecOps application"
  vpc_id      = aws_vpc.main.id

  # NO SSH - Using SSM instead for secure access
    # 🚨 CRITICAL VULN #1: SSH open to WORLD
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # # Application port only
   ingress {
     description = "Application access"
     from_port   = 8000
     to_port     = 8000
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }

  # Allow all outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-sg"
  }
}

# IAM Role for EC2 to use SSM
resource "aws_iam_role" "ssm_role" {
  name = "devsecops-ssm-role"

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
    Name = "devsecops-ssm-role"
  }
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "devsecops-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-south-1.s3"
  route_table_ids   = [aws_route_table.main.id]

  tags = {
    Name = "devsecops-s3-endpoint"
  }
}

# VPC Endpoint for SSM (required for Systems Manager)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-south-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true

  tags = {
    Name = "devsecops-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-south-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true

  tags = {
    Name = "devsecops-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-south-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true

  tags = {
    Name = "devsecops-ec2messages-endpoint"
  }
}

resource "aws_instance" "main" {
  ami                    = "ami-0c44f651ab5e9285f"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    encrypted             = false  # 🚨 CRITICAL VULN #2: Unencrypted!
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  monitoring = true
  user_data   = filebase64("${path.module}/userdata.sh")

  tags = {
    Name = "devsecops-app"
  }
}

resource "aws_eip" "main" {
  instance = aws_instance.main.id
  domain   = "vpc"

  tags = {
    Name = "devsecops-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "instance_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.main.private_ip
}

output "instance_public_ip" {
  description = "EC2 instance public IP (Elastic IP)"
  value       = aws_eip.main.public_ip
}

output "application_url" {
  description = "Application URL - Open this in browser"
  value       = "http://${aws_eip.main.public_ip}:8000"
}

output "ssm_connect_command" {
  description = "Connect via AWS Systems Manager (NO SSH KEY NEEDED)"
  value       = "aws ssm start-session --target ${aws_instance.main.id}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.main.id
}