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
                    
                    echo "🔄 Terraform Init & Plan for Security Scan..."
                    cd terraform
                    terraform init
                    terraform plan -out=tfplan
                    
                    cd ..
                    echo "🚨 SCANNING TERRAFORM PLAN (tfplan)..."
                    trivy config --severity HIGH,CRITICAL terraform/tfplan > trivy-results.txt 2>&1
                    
                    echo "📊 Generating JSON report..."
                    trivy config --format json --output trivy-report.json terraform/tfplan
                    
                    echo "📋 Trivy Summary:"
                    cat trivy-results.txt

                    # 🎯 COUNT vulnerabilities
                    HIGH_COUNT=$(grep -o "HIGH: [0-9]*" trivy-results.txt 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ' || echo 0)
                    CRIT_COUNT=$(grep -o "CRITICAL: [0-9]*" trivy-results.txt 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ' || echo 0)
                    TOTAL_FAIL=$(grep -o "FAILURES: [0-9]*" trivy-results.txt 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ' || echo 0)

                    echo "🔢 Vulnerability Summary:"
                    echo "   HIGH:    $HIGH_COUNT"
                    echo "   CRITICAL: $CRIT_COUNT"
                    echo "   TOTAL:   $TOTAL_FAIL"

                    # 🚨 FAIL criteria: 2+ HIGH OR 1+ CRITICAL
                    if [ "$CRIT_COUNT" -ge 1 ] || [ "$HIGH_COUNT" -ge 2 ] || [ "$TOTAL_FAIL" -ge 2 ]; then
                        echo "❌ PIPELINE FAILED - Security violations!"
                        echo "   CRITICAL: $CRIT_COUNT (FAIL if >=1)"
                        echo "   HIGH:     $HIGH_COUNT (FAIL if >=2)"
                        echo "Full report:"
                        cat trivy-results.txt
                        exit 1
                    fi
                    
                    echo "✅ SECURITY SCAN PASSED!"
                    echo "   ✅ 1 HIGH allowed | ✅ 0 CRITICAL | ✅ Total < 2"
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
    }

    post {
        always {
            archiveArtifacts artifacts: '**/*.txt,trivy-report.json,tfplan', allowEmptyArchive: true
            sh 'echo "🏁 Pipeline complete - check artifacts!"'
        }
    }
}