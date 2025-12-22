#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/userdata.log)
exec 2>&1

echo "=========================================="
echo "Starting UserData Script"
echo "=========================================="

# Update system
echo "Updating system packages..."
yum update -y

# Install Docker
echo "Installing Docker..."
yum install -y docker

# Start Docker service
echo "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group (optional but useful)
usermod -a -G docker ec2-user

# Wait for Docker to be ready
sleep 5

# Pull Docker image for AMD64 architecture
echo "Pulling Docker image..."
docker pull --platform linux/amd64 aryanpatil225/devsecops-app:latest

# Stop and remove existing container if it exists
echo "Cleaning up old containers..."
docker stop devsecops-app 2>/dev/null || true
docker rm devsecops-app 2>/dev/null || true

# Run the container
echo "Starting application container..."
docker run -d \
  --name devsecops-app \
  --restart always \
  --platform linux/amd64 \
  -p 8000:8000 \
  aryanpatil225/devsecops-app:latest

# Wait for container to start
sleep 3

# Verify container is running
if docker ps | grep -q devsecops-app; then
  echo "✅ Container started successfully!"
  docker ps > /var/log/docker.log
  echo "App started!" > /tmp/app-ready.txt
else
  echo "❌ Container failed to start!"
  docker logs devsecops-app > /var/log/docker-error.log 2>&1
  exit 1
fi

# Show container status
echo "=========================================="
echo "Container Status:"
docker ps
echo "=========================================="
echo "UserData Script Completed Successfully!"
echo "=========================================="