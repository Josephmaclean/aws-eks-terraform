variable "name" {
  description = "Name prefix for bastion resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the bastion security group."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID where the bastion host runs."
  type        = string
}

variable "instance_type" {
  description = "Bastion EC2 instance type."
  type        = string
}

variable "kubectl_version" {
  description = "kubectl version to install."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used by helper scripts."
  type        = string
}

variable "aws_region" {
  description = "AWS region used by helper scripts."
  type        = string
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs this bastion can read."
  type        = list(string)
  default     = []
}
