# **DevSecOps Pipeline**

A **DevSecOps** implementation that integrates security into every stage of the CI/CD lifecycle, automating build, test, security scanning, and deployment for modern applications.

---

## **🚀 Live Application**

**Application URL:** [http://35.154.106.48:8000](http://35.154.106.48:8000/)

The deployed application is running on AWS EC2 and accessible via the above link.

---

## **Table of Contents**

- **Overview**
- **Architecture**
- **Features**
- **Tech Stack**
- **Pipeline Stages**
- **AI Usage Report**
- **Getting Started**
- **Future Enhancements**
- **Contributors**

---

## **Overview**

This repository demonstrates a **DevSecOps** pipeline that shifts security left by embedding security checks directly into the CI/CD process. It is designed as a learning and project-ready template for building secure, automated delivery workflows on modern infrastructure.

---

## **Architecture**

The pipeline follows a modular, stage-based architecture integrating build, test, security, image scanning, and deployment.

| **Component**       | **Description**                                                                 |
|---------------------|---------------------------------------------------------------------------------|
| **Source Control**  | GitHub repository used as the single source of truth for application and IaC.  |
| **CI/CD Orchestrator** | Jenkins or GitHub Actions to automate builds, tests, and deployments.       |
| **Security Tools**  | SAST, dependency scanning, and container image scanning integrated in pipeline. |
| **Artifact Storage**| Artifact/Container registry (e.g., Nexus, Docker Hub, ECR).                    |
| **Runtime**         | Containerized app deployed to Kubernetes or virtual machines.                  |

---

## **Features**

- Automated **CI/CD** with build, test, and deployment stages.
- Integrated static code analysis and dependency vulnerability scanning.
- Container image build and vulnerability scanning before deployment.
- Environment-based deployments (dev/stage/prod) with security gates.

---

## **Tech Stack**

- **Version Control:** Git & GitHub
- **CI/CD:** Jenkins and/or GitHub Actions
- **Security & Quality:** SonarQube, Trivy, OWASP Dependency-Check
- **Containerization:** Docker
- **Orchestration:** Kubernetes or VM-based deployment

---

## **Pipeline Stages**

A typical pipeline flow implemented in this project is:

1. **Code Checkout**  
   Pipeline fetches code from GitHub repository.

2. **Build & Unit Test**  
   Application is built and unit tests are executed; pipeline fails fast on errors.

3. **Static Code Analysis (SAST)**  
   Code is scanned for bugs, code smells, and security issues using tools like SonarQube.

4. **Dependency & Image Scanning**  
   Trivy or OWASP Dependency-Check scans dependencies and Docker images for known vulnerabilities.

5. **Artifact Packaging & Publishing**  
   Build artifacts or images are stored in a registry such as Nexus or Docker Hub.

6. **Deployment**  
   Application is deployed to Kubernetes cluster or target servers after passing all checks.

7. **Monitoring & Notifications**  
   Pipeline and application health monitored; notifications sent on failures or critical events.

---

## **AI Usage Report**

This project actively uses **AI tools** during its design and development lifecycle to improve documentation quality, architecture decisions, and debugging efficiency.

### **AI Tools Involved**

| **AI Tool**   | **Purpose of Use**                                                     |
|---------------|------------------------------------------------------------------------|
| **Perplexity**| Used for project ideation, architecture references, and pipeline design research. |
| **Claude**    | Used for error analysis, debugging assistance, and refining configuration files and scripts. |

### **How AI Was Used**

- **Project Formation with Perplexity**  
  Perplexity was used to explore standard DevSecOps patterns, identify common tools (SonarQube, Trivy, Jenkins, GitHub Actions), and shape the overall pipeline design and documentation structure for this project.

- **Error Solving with Claude**  
  Claude was used to debug pipeline failures, fix YAML and Jenkinsfile issues, and refine shell commands, Dockerfiles, and configuration scripts when errors occurred.

**Note:** AI tools supported decision-making and debugging but the final implementation, customization, and integration were done manually.

---

## **Getting Started**

### **1. Clone the Repository**

git clone https://github.com/aryanpatil225/Devsecops-Pipeline-.git
cd Devsecops-Pipeline-


### **2. Configure CI/CD**

- Import Jenkins pipeline or enable GitHub Actions workflow from this repository.
- Set required credentials (registry, GitHub token, Kubernetes context, etc.) in your CI/CD tool.

### **3. Run the Pipeline**

- Commit and push changes to trigger the pipeline.
- Observe stages for build, test, security scans, and deployment.

---

## **Future Enhancements**

- Add **dynamic application security testing (DAST)** stage for runtime security checks.
- Integrate **policy-as-code** (e.g., OPA, Conftest) for enforcing security/compliance rules.
- Extend monitoring using tools like Prometheus and Grafana for deeper observability.

---

## **Contributors**

- **Author:** Aryan Patil (GitHub: `aryanpatil225`)
- **AI Assistance:**  
  - **Perplexity** for project formation and documentation structure.
  - **Claude** for error solving and configuration debugging.

---

**⭐ If you found this project helpful, please give it a star!**
