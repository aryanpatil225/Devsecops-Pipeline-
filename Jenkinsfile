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
        
        stage('🔍 Security Scan: Trivy on Terraform Code') {
            steps {
                sh '''
                    echo "🔧 Installing Trivy..."
                    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                    
                    echo "🚨 SCANNING TERRAFORM CONFIGURATION FILES..."
                    # Scan the actual .tf files, not tfplan binary
                    trivy config --severity HIGH,CRITICAL --exit-code 0 terraform/ > trivy-results.txt 2>&1
                    
                    echo "📊 Generating JSON report..."
                    trivy config --format json --output trivy-report.json terraform/
                    
                    echo "📋 Trivy Scan Results:"
                    cat trivy-results.txt
                    
                    # 🎯 COUNT vulnerabilities from the summary section
                    echo ""
                    echo "🔢 Parsing Vulnerability Counts..."
                    
                    # Extract counts from Trivy output
                    CRITICAL_COUNT=$(grep -i "CRITICAL:" trivy-results.txt | grep -oP '\d+' | head -1 || echo "0")
                    HIGH_COUNT=$(grep -i "HIGH:" trivy-results.txt | grep -oP '\d+' | head -1 || echo "0")
                    
                    # Alternative parsing if above doesn't work
                    if [ -z "$CRITICAL_COUNT" ] || [ "$CRITICAL_COUNT" = "0" ]; then
                        CRITICAL_COUNT=$(grep -c "Severity: CRITICAL" trivy-results.txt || echo "0")
                    fi
                    
                    if [ -z "$HIGH_COUNT" ] || [ "$HIGH_COUNT" = "0" ]; then
                        HIGH_COUNT=$(grep -c "Severity: HIGH" trivy-results.txt || echo "0")
                    fi
                    
                    echo "================================"
                    echo "📊 VULNERABILITY SUMMARY:"
                    echo "   🔴 CRITICAL: $CRITICAL_COUNT"
                    echo "   🟠 HIGH:     $HIGH_COUNT"
                    echo "================================"
                    
                    # 🚨 STRICT FAILURE CRITERIA
                    if [ "$CRITICAL_COUNT" -ge 1 ]; then
                        echo ""
                        echo "❌❌❌ PIPELINE FAILED ❌❌❌"
                        echo "🚨 Reason: Found $CRITICAL_COUNT CRITICAL vulnerabilities"
                        echo "🔒 Policy: ANY CRITICAL vulnerability blocks deployment"
                        echo ""
                        echo "📋 Full Security Report:"
                        cat trivy-results.txt
                        exit 1
                    fi
                    
                    if [ "$HIGH_COUNT" -ge 2 ]; then
                        echo ""
                        echo "❌❌❌ PIPELINE FAILED ❌❌❌"
                        echo "🚨 Reason: Found $HIGH_COUNT HIGH vulnerabilities"
                        echo "🔒 Policy: 2 or more HIGH vulnerabilities block deployment"
                        echo ""
                        echo "📋 Full Security Report:"
                        cat trivy-results.txt
                        exit 1
                    fi
                    
                    echo ""
                    echo "✅✅✅ SECURITY SCAN PASSED ✅✅✅"
                    echo "🛡️ Infrastructure is secure to proceed"
                    echo "   ✓ CRITICAL: $CRITICAL_COUNT (threshold: 0)"
                    echo "   ✓ HIGH: $HIGH_COUNT (threshold: <2)"
                '''
            }
        }
        
        stage('🏗️ Terraform Plan') {
            steps {
                dir('terraform') {
                    script {
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
            sh 'echo "🏁 Pipeline complete - check artifacts for reports!"'
        }
        success {
            echo '✅✅✅ PIPELINE SUCCEEDED - All security checks passed!'
        }
        failure {
            echo '❌❌❌ PIPELINE FAILED - Security vulnerabilities detected or deployment error!'
        }
    }
}