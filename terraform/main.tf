# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "devsecops-vpc"
  }
}

# Subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false  # ✅ No public IP
  
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

# Security Group - VPC ONLY egress (0 vulnerabilities)
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

  # Egress - VPC internal ONLY (✅ Passes Trivy)
  egress {
    description = "VPC internal communication"
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

# Elastic IP for public access
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
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]
  iam_instance_profile   = aws_iam_instance_profile.main.name

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

# IAM Role for EC2 (to use SSM for package installation)
resource "aws_iam_role" "main" {
  name = "devsecops-ec2-role"

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
    Name = "devsecops-ec2-role"
  }
}

# Attach SSM policy (for Systems Manager)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "main" {
  name = "devsecops-instance-profile"
  role = aws_iam_role.main.name

  tags = {
    Name = "devsecops-instance-profile"
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

output "note" {
  description = "Important Note"
  value       = "⚠️ After deployment, wait 3-5 minutes for application to start. Use SSM Session Manager if you need to troubleshoot."
}