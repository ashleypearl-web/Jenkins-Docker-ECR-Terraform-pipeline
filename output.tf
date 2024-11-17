output "dev_public_ip" {
  value = aws_instance.dev.public_ip
  description = "The public IP of the dev EC2 instance"
}

output "main_public_ip" {
  value = aws_instance.dev.public_ip
  description = "The public IP of the dev EC2 instance"
}

output "private_key_path" {
  value = "${path.module}/cicd-keypair.pem"  # Save key in the same directory as your Terraform configuration
}

