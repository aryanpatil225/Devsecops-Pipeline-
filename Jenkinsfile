pipeline {
    agent any
    
    environment {
        AWS_CREDENTIALS = credentials('aws-devsecops')
        AWS_REGION = 'ap-south-1'
        TF_IN_AUTOMATION = 'true'
    }
    
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
                        # Install Trivy in Jenkins agent
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                        
                        echo "=== SCANNING TERRAFORM FOR MISCONFIGURATIONS ==="
                        trivy config --exit-code 1 --no-progress --severity HIGH,CRITICAL ./terraform
                        
                        echo "=== FULL TERRAFORM SCAN REPORT ==="
                        trivy config --exit-code 0 --no-progress --format json --output trivy-report.json ./terraform
                    '''
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    script {
                        sh '''
                            # Install Terraform
                            curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
                            apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
                            apt-get update && apt-get install -y terraform
                            
                            terraform init
                            terraform plan -out=tfplan
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
            publishHTML([
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: '.',
                reportFiles: 'trivy-report.json',
                reportName: 'Trivy Security Report'
            ])
        }
    }
}
