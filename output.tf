output "ubuntu_ami" {
  value = "${data.aws_ami.ubuntu.id} ${data.aws_ami.ubuntu.name}"
}

output "ansible_sg" {
  value = aws_security_group.ansible-sg.id
}

output "controller_public_ip" {
  value = aws_instance.ansible_controller.public_ip
}

output "managed_public_ip" {
  value = aws_instance.ansible_managed.public_ip
}