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

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    Name = "*-public"
  }
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

# Fetch the route table for the private subnets
data "aws_route_table" "private" {
  subnet_id = element(data.aws_subnets.private.ids, 0)
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
  name                  = "ansible-ssm-role"
  force_detach_policies = true

  assume_role_policy = file("${path.module}/iam/trust-policy.json")
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ansible-ssm-profile"
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

### NAT Gateway Local to Project

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "ansible-project-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = element(data.aws_subnets.public.ids, 0)

  tags = {
    Name = "ansible-project-nat-gw"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = data.aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}
