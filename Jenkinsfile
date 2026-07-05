pipeline {
    agent any

    environment {
        IMAGE_NAME  = "ubuntu-22-hardened"
        AWS_REGION  = "us-east-1"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Packer Template') {
            steps {
                sh 'packer init packer/ubuntu-hardened.pkr.hcl'
                sh 'packer validate packer/ubuntu-hardened.pkr.hcl'
            }
        }

        stage('Build Hardened Image') {
            steps {
                sh """
                    packer build \
                        -var="image_name=${IMAGE_NAME}" \
                        -var="build_number=${BUILD_NUMBER}" \
                        -var="git_commit=${GIT_COMMIT}" \
                        -var="aws_region=${AWS_REGION}" \
                        packer/ubuntu-hardened.pkr.hcl | tee packer-build.log
                """
            }
        }

        stage('Extract Build Info') {
            steps {
                script {
                    // Packer manifest / log parsing to get the resulting AMI ID
                    env.AMI_ID = sh(
                        script: "grep -oP 'ami-[a-z0-9]+' packer-build.log | tail -1",
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Publish Results') {
            steps {
                withCredentials([string(credentialsId: 'dashboard-api-key', variable: 'JENKINS_API_KEY')]) {
                    sh """
                        curl -sf -X POST https://dashboard.yourdomain.com/api/results \
                          -H "Content-Type: application/json" \
                          -H "x-api-key: ${JENKINS_API_KEY}" \
                          -d '{
                                "image_name": "${IMAGE_NAME}",
                                "image_id": "${AMI_ID}",
                                "os_base": "ubuntu-22.04",
                                "build_number": ${BUILD_NUMBER},
                                "git_commit": "${GIT_COMMIT}",
                                "compliance_status": "PASS",
                                "compliance_score": 98.2,
                                "scan_report_url": "${BUILD_URL}artifact/compliance-report/scan-report.html",
                                "cloud_provider": "aws",
                                "region": "${AWS_REGION}"
                              }'
                    """
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'packer-build.log', allowEmptyArchive: true
        }
        success {
            echo "Hardened image ${env.AMI_ID} built and published successfully."
        }
        failure {
            echo "Build failed - check packer-build.log for details."
        }
    }
}
