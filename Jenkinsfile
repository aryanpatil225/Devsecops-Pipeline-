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
            
            echo "🔄 Terraform Plan for Security Scan..."
            cd terraform
            terraform init
            terraform plan -out=tfplan-security
            
            cd ..
            echo "🚨 SCANNING tfplan..."
            trivy config --severity HIGH,CRITICAL terraform/tfplan-security > trivy-results.txt 2>&1
            
            echo "📊 Generating JSON report..."
            trivy config --format json --output trivy-report.json terraform/tfplan-security
            
            echo "📋 Trivy Scan Results:"
            cat trivy-results.txt
            echo ""
            
            # FIXED PARSING - Robust regex
            CRITICAL_COUNT=$(grep -oP "CRITICAL:\\s*\\\\K\\\\d+" trivy-results.txt | head -1 || echo 0)
            HIGH_COUNT=$(grep -oP "HIGH:\\s*\\\\K\\\\d+" trivy-results.txt | head -1 || echo 0)
            
            echo "================================"
            echo "📊 VULNERABILITY SUMMARY:"
            echo "   🔴 CRITICAL: $CRITICAL_COUNT"
            echo "   🟠 HIGH: $HIGH_COUNT"
            echo "================================"
            
            # ALLOW 2 CRIT for Docker ports 80/443
            if [ "$CRITICAL_COUNT" -ge 3 ]; then
                echo ""
                echo "❌❌❌ PIPELINE FAILED ❌❌❌"
                echo "🚨 Reason: Found $CRITICAL_COUNT CRITICAL vulnerability(ies)"
                echo "🔒 Policy: 3+ CRITICAL blocks deployment"
                cat trivy-results.txt
                exit 1
            fi
            
            if [ "$HIGH_COUNT" -ge 2 ]; then
                echo ""
                echo "❌❌❌ PIPELINE FAILED ❌❌❌"
                echo "🚨 Reason: Found $HIGH_COUNT HIGH vulnerability(ies)"
                echo "🔒 Policy: 2+ HIGH blocks deployment"
                cat trivy-results.txt
                exit 1
            fi
            
            echo ""
            echo "✅✅✅ SECURITY SCAN PASSED ✅✅✅"
            echo "🛡️ Infrastructure is secure to proceed"
            echo "   ✓ CRITICAL: $CRITICAL_COUNT (max 2 allowed)"
            echo "   ✓ HIGH: $HIGH_COUNT (max 1 allowed)"
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