#!/bin/bash
# Install packages using Amazon Linux repo (works via VPC endpoints)
amazon-linux-extras install python3.8 -y
yum install -y python3-pip

# Install Python packages
pip3 install fastapi uvicorn --no-cache-dir

# Create application directory
mkdir -p /app
cd /app

# Create FastAPI application
cat > app.py << 'PYEOF'
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"status": "🚀 DevSecOps 0 VULNERABILITIES!", "vulnerabilities": 0}

@app.get("/health")
def health():
    return {"status": "healthy"}
PYEOF

# Start the application
nohup python3 -m uvicorn app:app --host 0.0.0.0 --port 8000 > /var/log/app.log 2>&1 &

echo "Application started!" > /tmp/startup-complete.txt