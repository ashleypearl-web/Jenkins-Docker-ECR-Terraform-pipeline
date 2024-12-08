pipeline {
    agent { label 'jenkins-slave-ubuntu' }

    tools {
        maven "Maven3.9"  
        jdk "JDK17"   
        terraform "terraform"    
    }

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

                    // Check if the private key exists in the workspace
                    sh "ls -al ./"
                    sh "ls -al ${privateKeyPath}"  // Debug: Check if the private key is in the expected location

                    // Set the TARGET_HOST for both dev and main branch
                    env.TARGET_HOST = devIp

                    // Set the private key path as an environment variable for later stages
                    env.PRIVATE_KEY_PATH = privateKeyPath  // Don't add "./", just use the output as is
                }
            }
        }

        stage('Build') {
            steps {
                // Run Maven install to build the project (skip tests)
                sh 'mvn install -DskipTests'
            }
            post {
                success {
                    echo 'Now Archiving the build artifacts...'
                    archiveArtifacts artifacts: '**/target/*.war'
                }
            }
        }

        stage('Unit Test') {
            steps {
                // Run unit tests using Maven
                sh 'mvn test'
            }
        }

        stage('Checkstyle Analysis') {
            steps {
                // Run Checkstyle analysis using Maven
                sh 'mvn checkstyle:checkstyle'
            }
        }

        stage("SonarQube Code Analysis") {
            environment {
                scannerHome = tool 'sonar6.2'  // Specify the SonarQube scanner version
            }
            steps {
                // Run SonarQube analysis
                withSonarQubeEnv('sonarserver') {
                    sh '''${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=ashleyprofile \
                       -Dsonar.projectName=ashley-repo \
                       -Dsonar.projectVersion=1.0 \
                       -Dsonar.sources=. \
                       -Dsonar.inclusions=**/*.html,**/*.css,**/*.js'''
                }
            }
        }

        stage("Quality Gate") {
            steps {
                // Wait for quality gate to pass before proceeding
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build App Image') {
            steps {
                script {
                    // Build the Docker image with the full registry URL and the image name, including the tag
                    dockerImage = docker.build( IMAGE_NAME + ":$BUILD_NUMBER", ".")
                    echo "Built Docker image: ${ashleyRegistry}/${IMAGE_NAME}:${BUILD_NUMBER}"
                }
            }
        }

        stage('Upload App Image') {
            steps {
                script {
                    // Push the Docker image to ECR with the correct tags (build number and latest)
                    docker.withRegistry(ashleyRegistry, registryCredential) {
                        // Push with the build number tag
                        dockerImage.push("${BUILD_NUMBER}")
                        echo "Pushed Docker image: ${ashleyRegistry}/${IMAGE_NAME}:${BUILD_NUMBER}"

                        // Push with the 'latest' tag
                        dockerImage.push('latest')
                        echo "Pushed Docker image: ${ashleyRegistry}/${IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('Success - Send Email Notification') {
            when {
                branch 'main'
            }
            steps {
                emailext(
                    subject: "Jenkins Job - Docker Image Pushed to ECR Successfully",
                    body: "Hello,\n\nThe Docker image '${env.IMAGE_NAME}:${env.TAG}' has been successfully pushed to ECR.\n\nBest regards,\nJenkins",
                    to: "m.ehtasham.azhar@gmail.com,tamfuhashley@gmail.com",
                    recipientProviders: [[$class: 'DevelopersRecipientProvider']])
            }
        }

        stage('Container Security Scan - Trivy') {
            steps {
                script {
                    sh """
                    #!/bin/bash
                    # Run Trivy security scan
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image ${IMAGE_NAME}:${BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Deploy to Environment') {
            steps {
                script {
                    // Ensure the private key exists in the workspace and has correct permissions
                    if (!env.PRIVATE_KEY_PATH || !fileExists(env.PRIVATE_KEY_PATH)) {
                        error "Private key file does not exist at ${env.PRIVATE_KEY_PATH}. Deployment will not proceed."
                    }

                    // Log and check the private key path
                    echo "Private Key Path: ${env.PRIVATE_KEY_PATH}"

                    // Ensure that the private key has the correct permissions
                    sh """
                        chmod 600 ${env.PRIVATE_KEY_PATH}
                        ls -al ${env.PRIVATE_KEY_PATH}  # Verify permissions and file existence
                    """

                    // SSH into EC2 instance and run the deployment commands
                    sh """
                        ssh -i ${env.PRIVATE_KEY_PATH} ubuntu@${env.TARGET_HOST} << EOF
                            # Authenticate Docker with AWS ECR
                            aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 816069136612.dkr.ecr.us-east-1.amazonaws.com
                            
                            # Pull the image from ECR
                            docker pull ${ashleyRegistry}/${IMAGE_NAME}:${env.BUILD_NUMBER}

                            # Stop and remove any old containers with the same name
                            docker stop ${IMAGE_NAME} || true
                            docker rm ${IMAGE_NAME} || true

                            # Run the new container
                            docker run -d --name ${IMAGE_NAME} -p 80:80 ${ashleyRegistry}/${IMAGE_NAME}:${env.BUILD_NUMBER}
                        EOF
                    """
                }
            }
        }
    }

    post {
        always {
            cleanWs()  // Clean up workspace after the build
        }
    }
}


