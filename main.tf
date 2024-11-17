# Generate a new SSH key pair locally using Terraform
resource "tls_private_key" "cicd_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create the AWS key pair using the public key
resource "aws_key_pair" "cicd_keypair" {
  key_name   = "cicd-keypair"
  public_key = tls_private_key.cicd_key.public_key_openssh
}

# Output the private key path (use this in Jenkins to copy the private key)
output "private_key_path" {
  value = "${path.module}/cicd-keypair.pem"
}

# Security Group to allow SSH, HTTP, and HTTPS traffic
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = var.vpc_id  # Ensure vpc_id is set

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open SSH to all IPs (be cautious in production)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open HTTP to all IPs
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open HTTPS to all IPs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow outbound traffic to any IP
  }
}

# Provision the EC2 instance
resource "aws_instance" "dev" {
  ami                          = var.ami_id  # Ensure ami_id is set
  instance_type                = var.instance_type  # Ensure instance_type is set
  key_name                     = aws_key_pair.cicd_keypair.key_name
  associate_public_ip_address  = true
  security_groups              = [aws_security_group.web_sg.name]

  tags = {
    Name    = "dev-instance"
    Project = "ashleyweb"
  }
}