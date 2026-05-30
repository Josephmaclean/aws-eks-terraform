variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster runs."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used by the EKS control plane and node groups."
  type        = list(string)
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is reachable from the public internet."
  type        = bool
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint when enabled."
  type        = list(string)
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS API endpoint is reachable from inside the VPC."
  type        = bool
}

variable "primary_node_group_instance_types" {
  description = "Instance types for the primary managed node group."
  type        = list(string)
}

variable "primary_node_group_min_size" {
  description = "Minimum size for the primary managed node group."
  type        = number
}

variable "primary_node_group_desired_size" {
  description = "Desired size for the primary managed node group."
  type        = number
}

variable "primary_node_group_max_size" {
  description = "Maximum size for the primary managed node group."
  type        = number
}

variable "ml_node_group_instance_types" {
  description = "Instance types for the ML managed node group."
  type        = list(string)
}

variable "ml_node_group_min_size" {
  description = "Minimum size for the ML managed node group."
  type        = number
}

variable "ml_node_group_desired_size" {
  description = "Desired size for the ML managed node group."
  type        = number
}

variable "ml_node_group_max_size" {
  description = "Maximum size for the ML managed node group."
  type        = number
}

variable "ml_node_group_ami_type" {
  description = "AMI type for the ML managed node group."
  type        = string
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace where Karpenter will run."
  type        = string
}

variable "karpenter_service_account_name" {
  description = "Karpenter controller service account name."
  type        = string
}

variable "karpenter_interruption_queue_retention" {
  description = "Karpenter interruption queue message retention in seconds."
  type        = number
}

variable "aws_load_balancer_controller_namespace" {
  description = "Kubernetes namespace where AWS Load Balancer Controller will run."
  type        = string
}

variable "aws_load_balancer_controller_service_account_name" {
  description = "AWS Load Balancer Controller service account name."
  type        = string
}
