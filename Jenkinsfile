pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-devsecops').accessKey
        AWS_SECRET_ACCESS_KEY = credentials('aws-devsecops').secretKey
        AWS_DEFAULT_REGION    = 'ap-south-1'
        TF_IN_AUTOMATION      = 'true'
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
                sh '''
                  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                  trivy config --exit-code 1 --no-progress --severity HIGH,CRITICAL ./terraform || true
                  trivy config --exit-code 0 --no-progress --format json --output trivy-report.json ./terraform || true
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh '''
                      curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
                      apt-get update && apt-get install -y software-properties-common
                      apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
                      apt-get update && apt-get install -y terraform

                      terraform init
                      terraform plan -out=tfplan
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
        }
    }
}
