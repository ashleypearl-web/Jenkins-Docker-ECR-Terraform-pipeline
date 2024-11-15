output "dev_public_ip" {
  value = aws_instance.dev.public_ip
  description = "The public IP of the dev EC2 instance"
}