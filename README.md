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
├── output.tf     # Values printed after apply (IP addresses, etc.)
└── README.md
```

---

## Step-by-Step Instructions

### Step 1: Choose your AWS region

Pick the AWS region **closest to you**. Resources there respond faster when you connect to them. Some examples:

| Location           | Region code      |
| ------------------ | ---------------- |
| US East (Virginia) | `us-east-1`      |
| US West (Oregon)   | `us-west-2`      |
| Europe (Ireland)   | `eu-west-1`      |
| Europe (London)    | `eu-west-2`      |
| Europe (Frankfurt) | `eu-central-1`   |
| Africa (Cape Town) | `af-south-1`     |
| Asia (Singapore)   | `ap-southeast-1` |

See the full list in the [AWS Regions documentation](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html).

> **Note:** some regions, such as `af-south-1`, are disabled by default and must be enabled in your AWS account first. Your company or sandbox account may also allow only certain regions.

**Use the same region in every step below.** Key pairs and instances belong to a single region.

### Step 2: Create a key pair (`.pem` file) in AWS

You need a key pair to SSH into the instances. **Terraform does not create it for you.** Create it yourself in AWS, in the region you chose in Step 1.

**Option A: AWS Console**

1. Open the **EC2** console and select your region in the top-right corner.
2. Go to **Network & Security → Key Pairs → Create key pair**.
3. Fill in:
   - **Name:** `ansible-key-pair`
   - **Key pair type:** RSA
   - **Private key file format:** `.pem`
4. Click **Create key pair**. The `ansible-key-pair.pem` file downloads automatically.
5. Move the file into this project folder.

**Option B: AWS CLI** (Git Bash, macOS or Linux terminal). Replace `<your-region>`:

```bash
aws ec2 create-key-pair --key-name ansible-key-pair --region <your-region> \
  --query "KeyMaterial" --output text > ansible-key-pair.pem
chmod 400 ansible-key-pair.pem
```

Check that the file isn't empty:

```bash
head -1 ansible-key-pair.pem   # should print -----BEGIN RSA PRIVATE KEY-----
```

> **Important**
> - AWS gives you the private key **only once**. If you lose the `.pem` file, you cannot download it again. You'll need to create a new key pair and recreate the instances.
> - **Never commit `.pem` files to Git.** `.gitignore` in this project already excludes `*.pem`.

### Step 3: Configure the AWS provider

Open `provider.tf` and set **your** region from Step 1:

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
  region = "<your-region>" # e.g. "eu-west-1", the region closest to you
}
```

### Step 4: Define the infrastructure

Add the following to `main.tf`. `key_name` must match the name of the key pair you created in Step 2.

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
  instance_type          = "t3.micro"
  key_name               = "ansible-key-pair" # created in Step 2
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
  instance_type          = "t3.micro"
  key_name               = "ansible-key-pair" # created in Step 2
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  tags = {
    Name = "ansible-manage-node"
  }
}
```

Then add the outputs to `output.tf`:

```hcl
output "controller_public_ip" {
  value = aws_instance.ansible_controller.public_ip
}

output "managed_public_ip" {
  value = aws_instance.ansible_managed.public_ip
}

output "managed_private_ip" {
  value = aws_instance.ansible_managed.private_ip
}
```

### Step 5: Initialize Terraform

This downloads the AWS provider plugin.

```bash
terraform init
```

### Step 6: Format and validate

```bash
terraform fmt
terraform validate
```

### Step 7: Preview the changes

Terraform shows what it will create without changing anything yet.

```bash
terraform plan
```

You should see **3 resources to add**: one security group and two EC2 instances.

### Step 8: Create the infrastructure

```bash
terraform apply
```

Type `yes` when prompted. When it finishes, Terraform prints the instance IP addresses.

### Step 9: Verify Ansible on the controller

SSH into the controller (wait a minute or two for the install script to finish):

```bash
ssh -i ansible-key-pair.pem ubuntu@<controller_public_ip>
ansible --version
```

### Step 10 (optional): Ping the managed node with Ansible

1. Copy your private key to the controller (run this from your own machine):
   ```bash
   scp -i ansible-key-pair.pem ansible-key-pair.pem ubuntu@<controller_public_ip>:~/.ssh/
   ```
2. On the controller, protect the key, trust the managed node's host key, and create an inventory file:
   ```bash
   chmod 400 ~/.ssh/ansible-key-pair.pem
   ssh-keyscan -H <managed_private_ip> >> ~/.ssh/known_hosts
   cat > inventory.ini <<EOF
   [managed]
   managed_node ansible_host=<managed_private_ip> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/ansible-key-pair.pem ansible_python_interpreter=/usr/bin/python3
   EOF
   ```
3. Ping it:
   ```bash
   ansible -i inventory.ini -m ping managed
   ```
   A `"ping": "pong"` reply means Ansible can manage the node.

### Step 11: Clean up

Remove everything so you don't get charged:

```bash
terraform destroy
```

Type `yes` when prompted. The key pair was created outside Terraform, so delete it yourself if you no longer need it:

```bash
aws ec2 delete-key-pair --key-name ansible-key-pair --region <your-region>
```

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

## Troubleshooting

| Error | Fix |
| ----- | --- |
| `InvalidKeyPair.NotFound` | The key pair doesn't exist in the region set in `provider.tf`. Create it in **that** region (Step 2). |
| `UnauthorizedOperation ... service control policy` | Your organisation or sandbox blocks the request. Try `t3.micro`, or ask your admin which regions and instance types are allowed. |
| SSH asks for a password | SSH isn't using your key. Check the `-i ansible-key-pair.pem` path. |
| `Host key verification failed` (Ansible) | Run `ssh-keyscan -H <managed_private_ip> >> ~/.ssh/known_hosts` on the controller. |
| `no such identity: ...pem` (Ansible) | The `.pem` path in `inventory.ini` doesn't match the file on the controller. Check with `ls ~/.ssh`. |
| Can't connect after a stop/start | The public IP changes. Run `terraform apply -refresh-only` and then `terraform output`. |

---

## Tips

- Do **not** commit `terraform.tfstate`, `.terraform/` or `.pem` key files to Git.
- `t3.micro` is Free Tier eligible in many regions. Run `terraform destroy` when you're finished anyway.
- If `ansible --version` fails right after `apply`, the boot script may still be running. Check its progress with `sudo tail -f /var/log/cloud-init-output.log`.
- To leave an SSH session, type `exit`. `sudo shutdown now` **stops** the instance, and you'll have to start it again from AWS.
