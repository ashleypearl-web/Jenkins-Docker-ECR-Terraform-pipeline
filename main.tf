resource "aws_key_pair" "cicd-keypair" {
  key_name   = "cicd-keypair"
  public_key = file("cicd-keypair.pub")
}

resource "aws_instance" "dev" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.cicd-keypair.key_name
  associate_public_ip_address = true

  tags = {
    Name    = "dev-instance"
    Project = "ashleyweb"
  }


}



