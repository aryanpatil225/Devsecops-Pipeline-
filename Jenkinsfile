pipeline {
    agent any

    stages {
        stage('🚀 Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/aryanpatil225/Devsecops-Pipeline-.git'
                sh 'echo "✅ Git checkout complete!"'
            }
        }

        stage('🔍 Security Scan: Trivy') {
            steps {
                script {
                    sh '''
                        echo "🔧 Installing Trivy..."
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                        
                        echo "🚨 SCANNING FOR VULNERABILITIES..."
                        trivy config --severity HIGH,CRITICAL ./terraform > trivy-results.txt
                        
                        echo "📊 Generating JSON report..."
                        trivy config --format json --output trivy-report.json ./terraform
                        
                        echo "📋 Trivy Summary:"
                        cat trivy-results.txt
                    '''
                }
            }
        }

        stage('🏗️ Terraform Plan') {
            steps {
                dir('terraform') {
                    sh '''
                        echo "📦 Installing ARM64 Terraform (if needed)..."
                        which terraform || (
                            apt-get update &&
                            apt-get install -y wget unzip &&
                            cd /tmp &&
                            rm -rf terraform* &&
                            wget https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_arm64.zip &&
                            unzip -o -q terraform_1.9.5_linux_arm64.zip &&
                            mv terraform /usr/local/bin/ &&
                            chmod +x /usr/local/bin/terraform
                        )
                        
                        echo "✅ Terraform ready: $(terraform version)"
                        
                        echo "🔄 Initializing in CORRECT directory..."
                        pwd  # Should show /var/jenkins_home/.../terraform
                        ls -la  # Should show .tf files
                        
                        terraform init
                        
                        echo "📋 Running terraform plan..."
                        terraform plan -out=tfplan
                        echo "✅ Terraform Plan Complete!"
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivy-results.txt,trivy-report.json,tfplan', allowEmptyArchive: true
            sh 'echo "🏁 Pipeline complete - check artifacts!"'
        }
    }
}
