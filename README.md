# Terraform Beginner: Two Ubuntu EC2 Instances for Ansible

A hands-on project for people who are new to **Infrastructure as Code (IaC)** with **Terraform**.

You will use Terraform to create two Ubuntu EC2 instances on AWS:

| Instance name             | Role                                                    |
| ------------------------- | ------------------------------------------------------- |
| `ansible-controller-node` | Has **Ansible installed**. You run playbooks from here. |
| `ansible-manage-node`     | The managed node that Ansible configures.               |

Along the way you will learn the basic Terraform workflow: `init`, `plan`, `apply` and `destroy`.

---

## Prerequisites

1. An **AWS account**.
2. The **AWS CLI**, configured with your credentials:
   ```bash
   aws configure
   ```
3. **Terraform** (v1.5 or later): [install guide](https://developer.hashicorp.com/terraform/install)
4. An **EC2 key pair** in your AWS region, so you can SSH into the instances. You can create one in the AWS Console under **EC2 → Key Pairs**.

Check that the tools work:

```bash
terraform -version
aws sts get-caller-identity
```

---

## Project Structure

```
terraform_beginner/
├── provider.tf   # Tells Terraform to use AWS and which region
├── main.tf       # The EC2 instances, security group and Ubuntu AMI lookup
└── README.md
```

---

## Step-by-Step Instructions

### Step 1: Configure the AWS provider

Open `provider.tf` and set your region:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # change to your preferred region
}
```

### Step 2: Define the infrastructure

Add the following to `main.tf`. Replace `my-key-pair` with the name of your EC2 key pair.

```hcl
# Find the latest Ubuntu 24.04 LTS image published by Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Allow SSH in, and all traffic out
resource "aws_security_group" "ansible_sg" {
  name        = "ansible-sg"
  description = "Allow SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # for learning only; restrict to your IP in real projects
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Controller node: Ansible is installed at boot
resource "aws_instance" "ansible_controller" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = "my-key-pair"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

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

# Managed node: configured by Ansible from the controller
resource "aws_instance" "ansible_managed" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = "my-key-pair"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  tags = {
    Name = "ansible-manage-node"
  }
}

output "controller_public_ip" {
  value = aws_instance.ansible_controller.public_ip
}

output "managed_node_public_ip" {
  value = aws_instance.ansible_managed.public_ip
}

output "managed_node_private_ip" {
  value = aws_instance.ansible_managed.private_ip
}
```

### Step 3: Initialize Terraform

This downloads the AWS provider plugin.

```bash
terraform init
```

### Step 4: Format and validate

```bash
terraform fmt
terraform validate
```

### Step 5: Preview the changes

Terraform shows what it will create without changing anything yet.

```bash
terraform plan
```

You should see **3 resources to add**: one security group and two EC2 instances.

### Step 6: Create the infrastructure

```bash
terraform apply
```

Type `yes` when prompted. When it finishes, Terraform prints the instance IP addresses.

### Step 7: Verify Ansible on the controller

SSH into the controller (wait a minute or two for the install script to finish):

```bash
ssh -i /path/to/my-key-pair.pem ubuntu@<controller_public_ip>
ansible --version
```

### Step 8 (optional): Ping the managed node with Ansible

1. Copy your private key to the controller (run this from your own machine):
   ```bash
   scp -i /path/to/my-key-pair.pem /path/to/my-key-pair.pem ubuntu@<controller_public_ip>:~/.ssh/
   ```
2. On the controller, create an inventory file:
   ```bash
   chmod 400 ~/.ssh/my-key-pair.pem
   cat > inventory.ini <<EOF
   [managed]
   <managed_node_private_ip> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/my-key-pair.pem
   EOF
   ```
3. Ping it:
   ```bash
   ansible all -i inventory.ini -m ping
   ```
   A `"ping": "pong"` reply means Ansible can manage the node.

### Step 9: Clean up

Remove everything so you don't get charged:

```bash
terraform destroy
```

Type `yes` when prompted.

---

## Key Terraform Concepts You Practised

| Concept         | Where you saw it                                    |
| --------------- | --------------------------------------------------- |
| **Provider**    | `provider "aws"` connects Terraform to AWS          |
| **Resource**    | `aws_instance`, `aws_security_group`                |
| **Data source** | `data "aws_ami"` looks up the latest Ubuntu image   |
| **Reference**   | `data.aws_ami.ubuntu.id`, `aws_security_group...id` |
| **User data**   | A boot script that installs Ansible                 |
| **Output**      | Prints the instance IPs after `apply`               |
| **State**       | `terraform.tfstate` records what Terraform created  |

---

## Tips

- Do **not** commit `terraform.tfstate`, `.terraform/` or `.pem` key files to Git.
- `t2.micro` is Free Tier eligible in most regions. Run `terraform destroy` when you're finished anyway.
- If `ansible --version` fails right after `apply`, the boot script may still be running. Check its progress with `sudo tail -f /var/log/cloud-init-output.log`.
