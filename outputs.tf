output "instance_ips" {
  description = "Public IP addresses of the EC2 instances"
  value       = module.ec2_instances[*].public_ip
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = data.aws_vpc.selected.id
}
