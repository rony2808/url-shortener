# Terraform — AWS deployment

Infrastructure-as-Code for the [URL Shortener](../) project. Provisions a
single EC2 instance inside a custom VPC and runs the Docker Compose stack on it.

## Resources

VPC · public subnet · internet gateway · route table · security group ·
SSH key pair · EC2 instance (`t4g.small`, Docker via cloud-init) · Elastic IP.

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured (`aws configure`) with a dedicated IAM user
- An SSH key pair (`ssh-keygen -t ed25519`)

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then set my_ip
terraform init
terraform plan
terraform apply
```

Outputs: the Elastic IP, the app URL, the instance ID, and an SSH command.
Allow 3–5 minutes after `apply` for the bootstrap script to install Docker and
start the stack.

## Cost-control workflow

The instance is meant to run only during demos. The Elastic IP keeps the public
address stable across stop/start, so the URL never changes.

```bash
aws ec2 start-instances --instance-ids <instance_id>   # before a demo
aws ec2 stop-instances  --instance-ids <instance_id>   # after
```

## Teardown

```bash
terraform destroy
```

## Notes

- `terraform.tfvars` (contains your IP) and `*.tfstate` are gitignored — never
  committed.
- `.terraform.lock.hcl` is committed on purpose: it pins the provider version.
- The AMI is resolved dynamically (latest Ubuntu 24.04 ARM64 from Canonical),
  so no AMI ID is hardcoded.
