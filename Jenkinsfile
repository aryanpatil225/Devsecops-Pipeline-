pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
        AWS_DEFAULT_REGION = 'ap-south-1'
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

        stage('🏗️ Terraform Plan') {
            steps {
                dir('terraform') {
                    script {
                        // Re-inject credentials in dir scope
                        env.AWS_ACCESS_KEY_ID = credentials('aws-access-key')
                        env.AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
                    }
                    sh '''
                        echo "✅ AWS Region: $AWS_DEFAULT_REGION"
                        echo "✅ Terraform version:"
                        terraform version
                        
                        echo "🔄 Initializing Terraform..."
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
            archiveArtifacts artifacts: '**/*.txt,trivy-report.json,tfplan', allowEmptyArchive: true
            sh 'echo "🏁 Pipeline complete - check artifacts!"'
        }
    }
}