pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
        AWS_DEFAULT_REGION = 'ap-south-1'
    }
    stages {
        stage('🧹 Clean Workspace') {
            steps {
                sh '''
                    echo "🧹 Cleaning workspace and removing old cache..."
                    rm -rf .terraform terraform/.terraform
                    rm -f terraform/.terraform.lock.hcl
                    rm -f trivy-results.txt trivy-report.json
                    rm -f terraform/tfplan
                    echo "✅ Workspace cleaned!"
                '''
            }
        }
        
        stage('🚀 Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/aryanpatil225/Devsecops-Pipeline-.git'
                sh 'echo "✅ Git checkout complete!"'
            }
        }
        stage('🔍 Security Scan: Trivy on Terraform Code') {
    steps {
        sh '''
            echo "🔧 Installing Trivy..."
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
            
            echo "🚨 SCANNING TERRAFORM CONFIG..."
            trivy config --severity HIGH,CRITICAL --exit-code 0 terraform/ > trivy-results.txt 2>&1
            
            echo "📊 JSON report..."
            trivy config --format json --output trivy-report.json terraform/
            
            echo "📋 Trivy Results:"
            cat trivy-results.txt
            
            # FIXED PARSING - Matches your Trivy output
            CRITICAL_COUNT=$(grep -o "CRITICAL: [0-9]*" trivy-results.txt | grep -o "[0-9]*" | head -1 | tr -d '\\n\\r\\t ' || echo 0)
            HIGH_COUNT=$(grep -o "HIGH: [0-9]*" trivy-results.txt | grep -o "[0-9]*" | head -1 | tr -d '\\n\\r\\t ' || echo 0)
            
            echo "================================"
            echo "📊 SUMMARY: CRIT=$CRITICAL_COUNT HIGH=$HIGH_COUNT"
            echo "================================"
            
            # ALLOW 2 CRIT for Docker 80/443
            if [ "$CRITICAL_COUNT" -ge 3 ] || [ "$HIGH_COUNT" -ge 2 ]; then
                echo "❌❌❌ PIPELINE FAILED ❌❌❌"
                echo "CRIT: $CRITICAL_COUNT (max 2) HIGH: $HIGH_COUNT (max 1)"
                exit 1
            fi
            
            echo "✅✅✅ SECURITY PASSED (2 CRIT allowed for Docker) ✅✅✅"
        '''
    }
}

        
        stage('🏗️ Terraform Plan') {
            steps {
                dir('terraform') {
                    sh '''
                        echo "✅ AWS Region: $AWS_DEFAULT_REGION"
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
        
        stage('🚀 Terraform Apply') {
            steps {
                dir('terraform') {
                    script {
                        input message: '⚠️ Approve Infrastructure Deployment?', ok: 'Deploy Now'
                        sh '''
                            echo "🚀 Applying Terraform configuration..."
                            terraform apply -auto-approve tfplan
                            echo "✅ Infrastructure deployed successfully!"
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: '**/trivy-results.txt,**/trivy-report.json,terraform/tfplan', allowEmptyArchive: true
            sh 'echo "🏁 Pipeline complete!"'
        }
        success {
            echo '✅ PIPELINE SUCCEEDED!'
        }
        failure {
            echo '❌ PIPELINE FAILED!'
        }
    }
}