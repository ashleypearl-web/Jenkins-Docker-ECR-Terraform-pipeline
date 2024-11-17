output "dev_public_ip" {
  value = aws_instance.dev.public_ip
  description = "The public IP of the dev EC2 instance"
}

output "main_public_ip" {
  value = aws_instance.dev.public_ip
  description = "The public IP of the dev EC2 instance"
}

output "private_key_path" {
  description = "The path to the private key for accessing EC2 instances"
  value       = "./cicd-keypair.pem"
}

