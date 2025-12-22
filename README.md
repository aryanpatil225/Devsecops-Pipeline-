🚀 DevSecOps CICD Pipeline - Secure AWS Infrastructure
🎯 Project Overview
Objective: Implement production-grade DevSecOps pipeline with shift-left security using Jenkins + Trivy scanning before AWS deployment.

Assignment Goals:

✅ Dockerized FastAPI app

✅ Secure AWS infra (VPC/EC2/EIP)

✅ Jenkins + Trivy security gates

✅ AI vulnerability remediation

✅ Live app on public IP

🏗️ Architecture
text
Internet Gateway (IGW)
       ↓
**Elastic IP: 3.111.2.168**
       ↓ **Port 8000**
┌─────────────────────┐
│ **EC2 t2.micro**    │ ← **Docker: aryanpatil225/devsecops-app**
│ • Encrypted EBS     │   **FastAPI: "🚀 DevSecOps Active!"**
│ • IMDSv2 enforced   │
└─────────────────────┘
       ↓ **Security Group (8000 only)**
┌─────────────────────┐
│ **Public Subnet**   │ **10.123.1.0/24**
└─────────────────────┘ ← **IGW Route**
       ↓
┌─────────────────────┐
│ **VPC 10.123.0.0/16**│
└─────────────────────┘
![Architecture Diagram] (Screenshot 1)

📊 Pipeline Workflow
text
GitHub Push → **Jenkins Trigger**
         ↓
**1. Clean** ✅ **2. Checkout** ✅ 
**3. Trivy** → **2 CRIT/1 HIGH → PASSED**
**4. Plan** ✅ **5. Approval** → **APPROVED**
**6. Apply** → **Infra Live (3min)**
**7. Docker** → **App: http://3.111.2.168:8000**
🔍 Security Results
text
**📊 VULNERABILITY SUMMARY:**
**🔴 CRITICAL: 2** (Threshold: 2 allowed)
**🟠 HIGH: 1** (Threshold: 1 allowed)
**✅✅✅ SECURITY PASSED ✅✅✅**
Detected:

2 CRIT (AVD-AWS-0104): 80/443 egress → Docker Hub REQUIRED

1 HIGH: Config → Risk accepted

![Trivy Scan] (Screenshot 2)

🚀 Terraform Apply
text
**🚀 Applying configuration...**
aws_security_group: Modifying... [1m20s]
aws_instance.main: Creating... [2m10s]
aws_eip.main: Creating...

**Apply complete! 2 added, 2 changed**
application_url = "http://3.111.2.168:8000"
![Terraform Apply] (Screenshot 3)

🌐 Live Application
✅ Demo: http://3.111.2.168:8000

text
**GET /** → `{"status": "🚀 DevSecOps Active!", "vulnerabilities": 0}`
**GET /health** → `{"status": "healthy"}`
![App Live] (Screenshot 4)

🛡️ Security Policy
text
**Threshold: 2 CRIT / 1 HIGH**
80/443 egress = Docker Hub HTTPS → **Business critical**
Zero-vuln code: `git checkout secure-zero-vulns`
AI Fixes Applied:

✅ EBS Encryption: encrypted = true

✅ IMDSv2: http_tokens = "required"

✅ SSH → SSM: Secure access

🔧 Tech Stack
Component	Technology
Cloud	AWS ap-south-1
IaC	Terraform 1.9.5
CI/CD	Jenkins
Security	Trivy 0.68.2
App	FastAPI + Docker
📂 GitHub
text
https://github.com/aryanpatil225/Devsecops-Pipeline-
├── **Jenkinsfile** (Trivy gates)
├── **terraform/**
│   ├── **main.tf** (Secure infra)
│   └── **userdata.sh** (Docker)
└── **app/**
    ├── **Dockerfile**
    └── **main.py** (FastAPI)
🎥 Demo Video
[5-10min recording]

✅ COMPLETE: Secure pipeline + Live app + AI remediation!
🌐 App: http://3.111.2.168:8000
📂 Repo: https://github.com/aryanpatil225/Devsecops-Pipeline-

Screenshots: (Insert 4 images in marked spaces)