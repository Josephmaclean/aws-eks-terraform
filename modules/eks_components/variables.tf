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

variable "aws_region" {
  description = "AWS region where the EKS cluster runs."
  type        = string
}

variable "aws_profile" {
  description = "AWS shared config profile used by local destroy cleanup commands."
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

variable "enable_bastion_bootstrap" {
  description = "Whether to create the SSM document used for bastion-based EKS component bootstrap."
  type        = bool
}

variable "enable_bastion_karpenter_bootstrap" {
  description = "Whether the bastion bootstrap should install Karpenter."
  type        = bool
}

variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version."
  type        = string
}

variable "enable_default_karpenter_nodepools" {
  description = "Whether the bastion bootstrap should apply Karpenter manifests from this module."
  type        = bool
}

variable "aws_load_balancer_controller_namespace" {
  description = "Kubernetes namespace where AWS Load Balancer Controller will run."
  type        = string
}

variable "aws_load_balancer_controller_service_account_name" {
  description = "AWS Load Balancer Controller service account name."
  type        = string
}

variable "enable_bastion_argocd_bootstrap" {
  description = "Whether the bastion bootstrap should install Argo CD."
  type        = bool
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD will be installed."
  type        = string
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
}

variable "argocd_server_service_type" {
  description = "Kubernetes Service type for argocd-server."
  type        = string
}

variable "argocd_repo_secret_id" {
  description = "AWS Secrets Manager secret ID or ARN containing Argo CD Git repository credentials."
  type        = string
}

variable "argocd_repo_url" {
  description = "Git repository URL for the Argo CD root Application."
  type        = string
}

variable "argocd_repo_url_key" {
  description = "JSON key in argocd_repo_secret_id that contains the Git repository URL."
  type        = string
}

variable "argocd_repo_username_key" {
  description = "JSON key in argocd_repo_secret_id that contains the Git username."
  type        = string
}

variable "argocd_repo_password_key" {
  description = "JSON key in argocd_repo_secret_id that contains the Git token or password."
  type        = string
}

variable "argocd_root_app_name" {
  description = "Name of the Argo CD root Application."
  type        = string
}

variable "argocd_root_app_path" {
  description = "Path inside the Git repository used by the generated Argo CD root Application."
  type        = string
}

variable "argocd_root_app_manifest_path" {
  description = "Path to the root Application manifest inside the Git repository."
  type        = string
}

variable "argocd_root_app_target_revision" {
  description = "Git target revision used by the Argo CD root Application."
  type        = string
}

variable "argocd_root_app_destination_namespace" {
  description = "Destination namespace used by the Argo CD root Application."
  type        = string
}
