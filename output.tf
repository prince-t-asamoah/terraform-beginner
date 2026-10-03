output "ubuntu_ami" {
  value = "${data.aws_ami.ubuntu.id} ${data.aws_ami.ubuntu.name}"
}

output "ansible_sg" {
  value = aws_security_group.ansible-sg.id
}