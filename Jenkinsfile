
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
                    
                    echo "🚨 SCANNING TERRAFORM CONFIGURATION FILES..."
                    trivy config --severity HIGH,CRITICAL --exit-code 0 terraform/ > trivy-results.txt 2>&1
                    
                    echo "📊 Generating JSON report..."
                    trivy config --format json --output trivy-report.json terraform/
                    
                    echo "📋 Trivy Scan Results:"
                    cat trivy-results.txt
                    echo ""
                    
                    # Count vulnerabilities using the correct pattern
                    CRITICAL_COUNT=$(grep -o "CRITICAL: [0-9]*" trivy-results.txt | grep -o "[0-9]*" | head -1 | tr -d '\\n\\r\\t ' || echo "0")
                    HIGH_COUNT=$(grep -o "HIGH: [0-9]*" trivy-results.txt | grep -o "[0-9]*" | head -1 | tr -d '\\n\\r\\t ' || echo "0")
                    
                    # Also check for vulnerability lines like "AVD-AWS-0104 (CRITICAL)"
                    CRITICAL_VULN_COUNT=$(grep -c "(CRITICAL)" trivy-results.txt 2>/dev/null || echo "0")
                    HIGH_VULN_COUNT=$(grep -c "(HIGH)" trivy-results.txt 2>/dev/null || echo "0")
                    
                    # Use the higher count from either method
                    if [ "$CRITICAL_VULN_COUNT" -gt "$CRITICAL_COUNT" ]; then
                        CRITICAL_COUNT=$CRITICAL_VULN_COUNT
                    fi
                    if [ "$HIGH_VULN_COUNT" -gt "$HIGH_COUNT" ]; then
                        HIGH_COUNT=$HIGH_VULN_COUNT
                    fi
                    
                    # Ensure we have valid numbers
                    if [ -z "$CRITICAL_COUNT" ] || [ "$CRITICAL_COUNT" = "" ]; then
                        CRITICAL_COUNT=0
                    fi
                    if [ -z "$HIGH_COUNT" ] || [ "$HIGH_COUNT" = "" ]; then
                        HIGH_COUNT=0
                    fi
                    
                    echo "================================"
                    echo "📊 VULNERABILITY SUMMARY:"
                    echo "   🔴 CRITICAL: $CRITICAL_COUNT"
                    echo "   🟠 HIGH: $HIGH_COUNT"
                    echo "================================"
                    
                    # Fail on CRITICAL vulnerabilities (1 or more)
                    if [ "$CRITICAL_COUNT" -ge 1 ]; then
                        echo ""
                        echo "❌❌❌ PIPELINE FAILED ❌❌❌"
                        echo "🚨 Reason: Found $CRITICAL_COUNT CRITICAL vulnerability(ies)"
                        echo "🔒 Policy: ANY CRITICAL vulnerability blocks deployment"
                        echo ""
                        echo "📋 Full Security Report:"
                        cat trivy-results.txt
                        exit 1
                    fi
                    
                    # Fail on HIGH vulnerabilities (2 or more)
                    if [ "$HIGH_COUNT" -ge 2 ]; then
                        echo ""
                        echo "❌❌❌ PIPELINE FAILED ❌❌❌"
                        echo "🚨 Reason: Found $HIGH_COUNT HIGH vulnerability(ies)"
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
