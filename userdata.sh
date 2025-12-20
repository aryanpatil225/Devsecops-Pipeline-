#!/bin/bash
yum update -y
yum install docker python3-pip -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

mkdir -p /app
cd /app
pip3 install fastapi uvicorn

cat > app.py << 'PYEOF'
from fastapi import FastAPI
app = FastAPI()
@app.get("/")
def root():
    return {"status": "🚀 DevSecOps PERFECT!", "vulnerabilities": 0}
@app.get("/health")
def health():
    return {"status": "healthy"}
PYEOF

nohup uvicorn app:app --host 0.0.0.0 --port 8000 &
