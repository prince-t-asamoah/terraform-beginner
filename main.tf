data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["099720109477"]

    filter {
      name = "name"
      values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }
}

resource "aws_security_group" "ansible-sg" {
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Controller node: Ansible is installed at boot
resource "aws_instance" "ansible_controller" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.micro"
    key_name = "ansible-key-pair" # Keypair must exist or create it with aws cli
    vpc_security_group_ids = [aws_security_group.ansible-sg.id]

    user_data = <<-EOF
        #!/bin/bash
        apt-get update -y
        apt-get install -y software-properties-common
        add-apt-repository --yes --update ppa:ansible/ansible
        apt-get install -y ansible
    EOF

    tags = {
      Name = "ansible-controller-node"
    }
}

# Managed node: configure by Ansible from the controller
resource "aws_instance" "ansible_managed" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name = "ansible-key-pair"
  vpc_security_group_ids = [aws_security_group.ansible-sg.id]

  tags = {
    Name = "ansible-manage-node"
  }
}