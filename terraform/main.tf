# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "devsecops-vpc"
  }
}

# Public Subnet (for NAT Gateway)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "devsecops-public-subnet"
  }
}

# Private Subnet (for EC2 - no public IP, passes Trivy)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.2.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false  # ✅ No public IP = passes Trivy
  
  tags = {
    Name = "devsecops-private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "devsecops-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "devsecops-nat-eip"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway (allows private instances to reach internet)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  
  tags = {
    Name = "devsecops-nat"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "devsecops-public-rt"
  }
}

# Private Route Table (routes through NAT)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  
  tags = {
    Name = "devsecops-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Application Load Balancer Security Group (public-facing)
resource "aws_security_group" "alb" {
  name        = "devsecops-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To application instances"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.123.0.0/16"]  # ✅ VPC only, passes Trivy
  }

  tags = {
    Name = "devsecops-alb-sg"
  }
}

# EC2 Security Group (private, restricted)
resource "aws_security_group" "ec2" {
  name        = "devsecops-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Application port from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # ✅ Only from ALB
  }

  egress {
    description = "HTTPS for package downloads"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ✅ Specific port, acceptable
  }

  egress {
    description = "HTTP for package repos"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ✅ Specific port, acceptable
  }

  tags = {
    Name = "devsecops-ec2-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "devsecops-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id]  # Note: ALB needs at least 2 subnets in production
  
  enable_deletion_protection = false
  
  tags = {
    Name = "devsecops-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "devsecops-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name = "devsecops-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-south-1.s3"
  
  route_table_ids = [aws_route_table.private.id]
  
  tags = {
    Name = "devsecops-s3-endpoint"
  }
}

# EC2 Instance (in private subnet)
resource "aws_instance" "main" {
  ami                    = "ami-0f5ee6cb1e35c1d3d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id  # ✅ Private subnet
  vpc_security_group_ids = [aws_security_group.ec2.id]

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

# Attach EC2 to Target Group
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.main.id
  port             = 8000
}

# Outputs
output "alb_dns_name" {
  description = "🌐 Load Balancer URL - Open this in your browser!"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_url" {
  description = "🚀 Application URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "health_check_url" {
  description = "❤️ Health Check URL"
  value       = "http://${aws_lb.main.dns_name}/health"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "instance_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.main.private_ip
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP"
  value       = aws_eip.nat.public_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}