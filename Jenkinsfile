pipeline {
    agent { label 'jenkins-slave-ubuntu' }

    tools {
        maven "Maven3.9"  
        jdk "JDK17"   
        terraform "terraform"    
    }

    environment {
        registryCredential = 'ecr:us-east-1:awscreds'  // Jenkins credentials for AWS ECR
        ashleyRegistry = "https://816069136612.dkr.ecr.us-east-1.amazonaws.com"  // ECR Registry URL
        ECR_REPO = "ashleysrepo"  // Name of the repository within ECR
        IMAGE_NAME = "my-nginx-app"  // Local Docker image name (without registry URL)
        TAG = "${BUILD_NUMBER}"  // Docker tag (usually the Jenkins build number)
        SSH_KEY = credentials('Jenkins-ssh-keypair')  // Jenkins credentials for SSH key
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
                    sh 'terraform init'  // Initialize Terraform
                    sh 'terraform apply -auto-approve'  // Apply the Terraform configuration

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

        stage('Build Docker Image') {
            steps {
                script {
                    // Build the Docker image based on the Dockerfile and tag it with the build ID
                    def customImage = docker.build("${ashleyRegistry}/${ECR_REPO}:${env.BUILD_ID}")
                    echo "Built Docker image: ${ashleyRegistry}/${ECR_REPO}:${env.BUILD_ID}"
                    // Save the custom image reference for later stages
                    env.customImage = customImage
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

        stage('Upload App Image') {
            steps {
                script {
                    // Push the image to ECR with build number and latest tags
                    docker.withRegistry(ashleyRegistry, registryCredential) {
                        // Push with the build number tag
                        env.customImage.push("${BUILD_NUMBER}")
                        echo "Pushed Docker image: ${ashleyRegistry}/${ECR_REPO}:${env.BUILD_NUMBER}"

                        // Push with the 'latest' tag
                        env.customImage.push('latest')
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
                    sh 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image ${ashleyRegistry}/${ECR_REPO}:${env.BUILD_ID}'
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
                    docker pull ${ashleyRegistry}/${ECR_REPO}:${env.BUILD_ID}
                    docker stop ${IMAGE_NAME} || true
                    docker rm ${IMAGE_NAME} || true
                    docker run -d --name ${IMAGE_NAME} -p 80:80 ${ashleyRegistry}/${ECR_REPO}:${env.BUILD_ID}
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

