terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use the VPC ID from SSM parameter store created in aft-global-customizations
data "aws_ssm_parameter" "vpc_id" {
  name = "/network/vpc_id"
}

data "aws_vpc" "selected" {
  id = data.aws_ssm_parameter.vpc_id.value
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    Name = "*-private"
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "ansible-sg"
  description = "Security group for SSM and internal access"
  vpc_id      = data.aws_vpc.selected.id

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ansible-node-role"

  assume_role_policy = file("${path.module}/iam/trust-policy.json")
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ansible-node-profile"
  role = aws_iam_role.ec2_role.name
}

module "ec2_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  count = var.instance_count

  name = "ansible-node-${count.index}"

  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  monitoring             = true
  vpc_security_group_ids = [module.security_group.security_group_id]
  subnet_id              = element(data.aws_subnets.private.ids, count.index)
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOT
    #!/bin/bash
    amazon-linux-extras install ansible2 -y
  EOT

  tags = {
    Terraform      = "true"
    Environment    = "dev"
    AnsibleManaged = "true"
  }
}
