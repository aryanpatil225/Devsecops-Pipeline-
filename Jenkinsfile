
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
        
       stage('🔍 Security Scan: Trivy') {
  steps {
    sh '''
      echo "🔧 Installing Trivy..."
      curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
      
      echo "🔄 Terraform Plan for Security Scan..."
      cd terraform
      terraform init
      terraform plan -out=tfplan-security
      
      cd ..
      echo "🚨 SCANNING tfplan (NOT raw config)..."
      trivy config --severity HIGH,CRITICAL terraform/tfplan-security > trivy-results.txt
      
      echo "📊 JSON report..."
      trivy config --format json --output trivy-report.json terraform/tfplan-security
      
      # Parse results
      HIGH_COUNT=$(grep -oP "HIGH:\\s*\\K\\d+" trivy-results.txt | head -1 || echo 0)
      CRIT_COUNT=$(grep -oP "CRITICAL:\\s*\\K\\d+" trivy-results.txt | head -1 || echo 0)
      
      echo "🔢 VULNS: HIGH=$HIGH_COUNT CRITICAL=$CRIT_COUNT"
      
      # FAIL on 1+ CRIT or 2+ HIGH
      if [ "$CRIT_COUNT" -ge 1 ] || [ "$HIGH_COUNT" -ge 2 ]; then
        echo "❌ FAILED: $CRIT_COUNT CRIT / $HIGH_COUNT HIGH"
        exit 1
      fi
      echo "✅ PASSED!"
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
