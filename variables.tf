variable "aws_region" {
  description = "AWS region to deploy the VPC into."
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "AWS shared config profile used by the provider."
  type        = string
  default     = "terraform"
}

variable "name" {
  description = "Name prefix used for all infrastructure resources."
  type        = string
  default     = "private-eks"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use. Leave empty to use the first two available AZs in the selected region."
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Must match the number of selected availability zones."
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "firewall_subnet_cidrs" {
  description = "CIDR blocks for AWS Network Firewall endpoint subnets. Must match the number of selected availability zones."
  type        = list(string)
  default     = ["10.0.64.0/28", "10.0.64.16/28"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets. Must match the number of selected availability zones."
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20"]
}

variable "tags" {
  description = "Default tags applied to all supported AWS resources."
  type        = map(string)
  default = {
    Project     = "private-eks"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "private-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.35"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is reachable from the public internet."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint when enabled."
  type        = list(string)
  default     = []
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS API endpoint is reachable from inside the VPC."
  type        = bool
  default     = true
}

variable "primary_node_group_instance_types" {
  description = "Instance types for the primary managed node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "primary_node_group_min_size" {
  description = "Minimum size for the primary managed node group."
  type        = number
  default     = 1
}

variable "primary_node_group_desired_size" {
  description = "Desired size for the primary managed node group."
  type        = number
  default     = 1
}

variable "primary_node_group_max_size" {
  description = "Maximum size for the primary managed node group."
  type        = number
  default     = 4
}

variable "ml_node_group_instance_types" {
  description = "Instance types for the ML managed node group."
  type        = list(string)
  default     = ["g5.xlarge"]
}

variable "ml_node_group_min_size" {
  description = "Minimum size for the ML managed node group."
  type        = number
  default     = 0
}

variable "ml_node_group_desired_size" {
  description = "Desired size for the ML managed node group."
  type        = number
  default     = 0
}

variable "ml_node_group_max_size" {
  description = "Maximum size for the ML managed node group."
  type        = number
  default     = 2
}

variable "ml_node_group_ami_type" {
  description = "AMI type for the ML managed node group. GPU workloads should use an EKS GPU AMI type."
  type        = string
  default     = "AL2023_x86_64_NVIDIA"
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace where Karpenter will run."
  type        = string
  default     = "kube-system"
}

variable "karpenter_service_account_name" {
  description = "Karpenter controller service account name."
  type        = string
  default     = "karpenter"
}

variable "karpenter_interruption_queue_retention" {
  description = "Karpenter interruption queue message retention in seconds."
  type        = number
  default     = 300
}
