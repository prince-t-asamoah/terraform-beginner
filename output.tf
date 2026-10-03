output "ubuntu_ami" {
  value = "${data.aws_ami.ubuntu.id} ${data.aws_ami.ubuntu.name}"
}