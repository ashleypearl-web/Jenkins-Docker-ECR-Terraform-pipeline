pipeline {
    agent { label 'jenkins-slave-ubuntu' }

    environment {
        registryCredential = 'ecr:us-east-1:awscreds'  // Jenkins credentials for AWS ECR
        ashleyRegistry = "https://816069136612.dkr.ecr.us-east-1.amazonaws.com"  // ECR Registry URL with https://
        IMAGE_NAME = "816069136612.dkr.ecr.us-east-1.amazonaws.com/ashleysrepo"  // Docker image name (without the full registry URL)
        TAG = "${BUILD_NUMBER}"  // Docker tag (usually the Jenkins build number)
        SSH_KEY = credentials('Jenkins-ssh-keypair')  // Jenkins credentials for SSH key
    }

    stages {
        stage('Fetch Code') {
            steps {
                // Fetch the code from GitHub repository
                git branch: 'main', url: 'https://github.com/ashleypearl-web/Jenkins-Docker-ECR-Terraform-pipeline.git'
            }
        }

        stage('Provision EC2 Instances with Terraform') {
            steps {
                script {
                    // Initialize Terraform and apply to provision EC2 instance(s)
                    sh 'terraform init'  // Initialize Terraform
                    sh 'terraform apply -auto-approve'  // Apply the Terraform configuration

                    // Capture the output from Terraform (path to private key and EC2 IP)
                    def devIp = sh(script: 'terraform output dev_public_ip', returnStdout: true).trim()
                    def privateKeyPath = sh(script: 'terraform output private_key_path', returnStdout: true).trim()

                    echo "Dev Instance Public IP: ${devIp}"
                    echo "Private Key Path: ${privateKeyPath}"

                    // Set the TARGET_HOST for both dev and main branch
                    env.TARGET_HOST = devIp

                    // Set the private key path as environment variable for later stages
                    env.PRIVATE_KEY_PATH = privateKeyPath
                }
            }
        }

        stage('Deploy to Environment') {
            steps {
                script {
                    // Ensure PRIVATE_KEY_PATH is set and accessible
                    if (!env.PRIVATE_KEY_PATH) {
                        error "PRIVATE_KEY_PATH is not set. Deployment will not proceed."
                    }

                    // Log and check the private key path
                    echo "Private Key Path: ${env.PRIVATE_KEY_PATH}"

                    // Ensure that the private key exists in the workspace
                    sh """
                        echo "Workspace directory: $(pwd)"
                        echo "Checking if private key exists at path ${env.PRIVATE_KEY_PATH}"
                        ls -al ${env.PRIVATE_KEY_PATH}  # Debugging line to confirm key file location
                        chmod 600 ${env.PRIVATE_KEY_PATH}  # Ensure correct permissions
                    """

                    // SSH into EC2 instance using the private key
                    sh """
                        ssh -i ${env.PRIVATE_KEY_PATH} ubuntu@${env.TARGET_HOST} << EOF
                        docker pull ${ashleyRegistry}/${IMAGE_NAME}:${env.BUILD_NUMBER}
                        docker stop ${IMAGE_NAME} || true
                        docker rm ${IMAGE_NAME} || true
                        docker run -d --name ${IMAGE_NAME} -p 80:80 ${ashleyRegistry}/${IMAGE_NAME}:${env.BUILD_NUMBER}
                        EOF
                    """
                }
            }
        }

        post {
            always {
                cleanWs()  // Clean up workspace after the build
            }
        }
    }
}
