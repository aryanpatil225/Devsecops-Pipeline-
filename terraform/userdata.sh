#!/bin/bash
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker

# Start Docker
systemctl start docker
systemctl enable docker

# Pull and run your Docker image
docker pull aryanpatil225/devsecops-app:latest

docker run -d \
  --name devsecops-app \
  --restart always \
  -p 8000:8000 \
  aryanpatil225/devsecops-app:latest

# Log completion
echo "App started!" > /tmp/app-ready.txt
docker ps > /var/log/docker.log