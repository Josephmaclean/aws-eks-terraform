output "instance_id" {
  description = "Bastion EC2 instance ID."
  value       = aws_instance.this.id
}

output "role_arn" {
  description = "Bastion IAM role ARN."
  value       = aws_iam_role.this.arn
}

output "security_group_id" {
  description = "Bastion security group ID."
  value       = aws_security_group.this.id
}
