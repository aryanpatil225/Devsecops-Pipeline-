pipeline {
    agent any

    parameters {
        string(name: 'AWS_ACCESS_KEY_ID', defaultValue: '', description: 'AWS Access Key')
        string(name: 'AWS_SECRET_ACCESS_KEY', defaultValue: '', description: 'AWS Secret Key')
    }

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
                    script {
                        env.AWS_ACCESS_KEY_ID = params.AWS_ACCESS_KEY_ID
                        env.AWS_SECRET_ACCESS_KEY = params.AWS_SECRET_ACCESS_KEY
                        env.AWS_DEFAULT_REGION = 'ap-south-1'
                        
                        sh '''
                            echo "✅ Terraform ready: $(terraform version)"
                            terraform init
                            terraform plan -out=tfplan
                            echo "✅ Terraform Plan Complete!"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivy-results.txt,trivy-report.json,tfplan', allowEmptyArchive: true
        }
    }
}
