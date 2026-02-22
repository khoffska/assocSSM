output "instance_private_ips" {
  description = "Private IP addresses of the EC2 instances"
  value       = module.ec2_instances[*].private_ip
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = data.aws_vpc.selected.id
  sensitive   = true
}
