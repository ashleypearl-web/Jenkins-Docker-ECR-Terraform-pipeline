pipeline {
    agent { label 'jenkins-slave-ubuntu' }

    tools {
        maven "Maven3.9"  
        jdk "JDK17"       
    }

    environment {
        registryCredential = 'ecr:us-east-1:awscreds'  // Jenkins credentials for AWS ECR
        ashleyRegistry = "816069136612.dkr.ecr.us-east-1.amazonaws.com"  // ECR Registry URL
        ECR_REPO = "ashleysrepo"  // Name of the repository within ECR
        IMAGE_NAME = "my-nginx-app"  // Local Docker image name (without registry URL)
        TAG = "${BUILD_NUMBER}"  // Docker tag (usually the Jenkins build number)
        SSH_KEY = credentials('Jenkins-ssh-keypair')  // Jenkins credentials for SSH key
        TERRAFORM_DIR = 'terraform'  // Directory where Terraform code is located
        targetHost = ''  // Declare targetHost here to avoid issues
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
                        }
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Build the Docker image based on the Dockerfile
                    def dockerImage = docker.build("${ashleyRegistry}/${ECR_REPO}:${TAG}", ".")
                    echo "Built Docker image: ${ashleyRegistry}/${ECR_REPO}:${TAG}"
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

        stage('Tag and Push Docker Image') {
            steps {
                script {
                    // Tag the image as 'latest'
                    dockerImage.tag("${ashleyRegistry}/${ECR_REPO}:latest")
                    echo "Tagged Docker image as: ${ashleyRegistry}/${ECR_REPO}:latest"

                    // Push the image to AWS ECR registry
                    docker.withRegistry(ashleyRegistry, registryCredential) {
                        // Push with build number tag (e.g., 40)
                        dockerImage.push("${TAG}")
                        echo "Pushed Docker image: ${ashleyRegistry}/${ECR_REPO}:${TAG}"

                        // Push with the 'latest' tag
                        dockerImage.push('latest')
                        echo "Pushed Docker image: ${ashleyRegistry}/${ECR_REPO}:latest"
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
                    sh 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image ${ashleyRegistry}/${ECR_REPO}:${TAG}'
                }
            }
        }

        stage('Deploy to Environment') {
            steps {
                script {
                    // Assuming targetHost is set from the previous stage
                    if (!targetHost) {
                        error "targetHost is not set. Deployment will not proceed."
                    }
                    sh """
                    ssh -i ${SSH_KEY} ec2-user@${targetHost} << EOF
                    docker pull ${ashleyRegistry}/${ECR_REPO}:${TAG}
                    docker stop ${IMAGE_NAME} || true
                    docker rm ${IMAGE_NAME} || true
                    docker run -d --name ${IMAGE_NAME} -p 80:80 ${ashleyRegistry}/${ECR_REPO}:${TAG}
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
