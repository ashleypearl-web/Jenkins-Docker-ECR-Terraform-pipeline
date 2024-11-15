pipeline {
    agent { label 'jenkins-slave-ubuntu' }

    tools {
        maven "Maven3.9"  
        jdk "JDK17" 
        terraform 'terraform'  // Ensure Terraform is installed and configured
    }      

    }

    environment {
        registryCredential = 'ecr:us-east-1:awscreds'
        imageName = "816069136612.dkr.ecr.us-east-1.amazonaws.com/ashleysrepo"
        ashleyRegistry = "https://816069136612.dkr.ecr.us-east-1.amazonaws.com"
        ECR_REPO = "816069136612.dkr.ecr.us-east-1.amazonaws.com/ashleysrepo"
        IMAGE_NAME = "my-nginx-app"
        TAG = "${BUILD_NUMBER}"
        SSH_KEY = credentials('Jenkins-ssh-keypair')  // Jenkins credentials for SSH key
        targetHost = ''  // Initialize targetHost variable
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
                    dir("${TERRAFORM_DIR}") {
                        // Initialize Terraform
                        sh 'terraform init'
                        
                        // Apply Terraform to create infrastructure
                        sh 'terraform apply -auto-approve'

                        // Capture the output from Terraform (e.g., EC2 instance IP)
                        def devIp = sh(script: 'terraform output dev_public_ip', returnStdout: true).trim()
                        echo "Dev Instance Public IP: ${devIp}"

                        // Set the IP based on environment
                        if (env.BRANCH_NAME == 'dev') {
                            targetHost = devIp
                        } else {
                            echo "Not on dev branch. Skipping targetHost assignment."
                        }
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Build the Docker image based on the Dockerfile
                    docker.build(IMAGE_NAME, ".")
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

        stage('Build and Push Docker Image') {
            steps {
                script {
                    // Build the Docker image from Dockerfile located in the current directory
                    def dockerImage = docker.build(IMAGE_NAME, ".")
                    
                    // Push the Docker image to AWS ECR registry
                    docker.withRegistry(ashleyRegistry, registryCredential) {
                        dockerImage.push(TAG)  // Push with build number tag
                        dockerImage.push('latest') // Push with 'latest' tag
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
                    recipientProviders: [[$class: 'DevelopersRecipientProvider']],
                    to: "m.ehtasham.azhar@gmail.com, tamfuhashley@gmail.com"
                )
            }
        }

        stage('Container Security Scan - Trivy') {
            steps {
                script {
                    sh 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image ${ECR_REPO}:${TAG}'
                }
            }
        }

        stage('Deploy to Environment') {
            steps {
                script {
                    // Assuming targetHost is set from the previous stage
                    sh """
                    ssh -i ${SSH_KEY} ec2-user@${targetHost} << EOF
                    docker pull ${ECR_REPO}:${TAG}
                    docker stop ${IMAGE_NAME} || true
                    docker rm ${IMAGE_NAME} || true
                    docker run -d --name ${IMAGE_NAME} -p 80:80 ${ECR_REPO}:${TAG}
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
