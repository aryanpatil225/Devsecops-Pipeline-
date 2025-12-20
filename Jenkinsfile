pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/aryanpatil225/Devsecops-Pipeline-.git'
            }
        }

        stage('Security Scan: Trivy') {
            steps {
                script {
                    sh '''
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                        
                        echo "=== SCANNING TERRAFORM FOR VULNERABILITIES ==="
                        trivy config ./terraform
                        
                        echo "=== DETAILED HIGH/CRITICAL SCAN ==="
                        trivy config --severity HIGH,CRITICAL ./terraform
                        
                        echo "=== JSON REPORT ==="
                        trivy config --format json --output trivy-report.json ./terraform
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh '''
                        # Install unzip for terraform
                        apt-get update
                        apt-get install -y wget unzip
                        
                        # Install Terraform manually
                        cd /tmp
                        wget https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip
                        unzip terraform_1.9.5_linux_amd64.zip
                        mv terraform /usr/local/bin/
                        
                        terraform init
                        terraform plan -out=tfplan
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
        }
    }
}
