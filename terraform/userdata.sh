#!/bin/bash
set -e

# Install Docker
yum update -y
yum install -y docker

# Start Docker service
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Pull pre-built image from Docker Hub
docker pull aryanpatil225/devsecops-app:latest

# Run the container
docker run -d \
  --name devsecops-app \
  --restart unless-stopped \
  -p 8000:8000 \
  aryanpatil225/devsecops-app:latest

# Wait for container to start
sleep 5

# Log status
docker ps > /var/log/docker-status.log
docker logs devsecops-app > /var/log/app.log 2>&1

echo "Application started with Docker!" > /tmp/startup-complete.txt