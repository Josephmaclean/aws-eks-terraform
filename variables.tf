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
  description = "Whether the EKS API endpoint is reachable from outside the VPC."
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

variable "enable_argocd" {
  description = "Whether to install Argo CD with the local Terraform Helm provider. Keep false when using the bastion bootstrap path."
  type        = bool
  default     = false
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD will be installed."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
  default     = "9.5.17"
}

variable "argocd_server_service_type" {
  description = "Kubernetes Service type for argocd-server."
  type        = string
  default     = "ClusterIP"
}

variable "argocd_values" {
  description = "Additional values merged into the Argo CD Helm chart."
  type        = any
  default     = {}
}

variable "enable_bastion" {
  description = "Whether to create a private SSM bastion/admin host with kubectl and helm."
  type        = bool
  default     = true
}

variable "bastion_instance_type" {
  description = "Instance type for the private SSM bastion/admin host."
  type        = string
  default     = "t3.micro"
}

variable "kubectl_version" {
  description = "kubectl version installed on the bastion host."
  type        = string
  default     = "v1.35.0"
}

variable "enable_bastion_argocd_bootstrap" {
  description = "Whether to install Argo CD from the bastion host using SSM after the EKS cluster is ready."
  type        = bool
  default     = true
}

variable "argocd_bootstrap_revision" {
  description = "Bump this value to force the SSM Argo CD bootstrap association to rerun."
  type        = string
  default     = "1"
}

variable "argocd_repo_secret_id" {
  description = "AWS Secrets Manager secret ID or ARN containing Argo CD Git repository credentials as JSON. Defaults to <name>/github/repo when empty."
  type        = string
  default     = ""
}

variable "argocd_repo_url" {
  description = "Git repository URL for the Argo CD root Application. If empty, the bootstrap reads argocd_repo_url_key from the Secrets Manager secret."
  type        = string
  default     = ""
}

variable "argocd_repo_url_key" {
  description = "JSON key in argocd_repo_secret_id that contains the Git repository URL."
  type        = string
  default     = "repo_url"
}

variable "argocd_repo_username_key" {
  description = "JSON key in argocd_repo_secret_id that contains the Git username."
  type        = string
  default     = "github_username"
}

variable "argocd_repo_password_key" {
  description = "JSON key in argocd_repo_secret_id that contains the Git token or password."
  type        = string
  default     = "github_token"
}

variable "argocd_repo_secret_arn" {
  description = "Optional Secrets Manager secret ARN for least-privilege IAM. Use * when argocd_repo_secret_id is a name or partial ARN."
  type        = string
  default     = "*"
}

variable "argocd_root_app_name" {
  description = "Name of the Argo CD root Application."
  type        = string
  default     = "root"
}

variable "argocd_root_app_path" {
  description = "Path inside the Git repository used by the Argo CD root Application when generating an Application manifest."
  type        = string
  default     = "."
}

variable "argocd_root_app_manifest_path" {
  description = "Path to the root Application manifest inside the Git repository. When set, bootstrap applies this manifest instead of generating one."
  type        = string
  default     = "root-app.yaml"
}

variable "argocd_root_app_target_revision" {
  description = "Git target revision used by the Argo CD root Application."
  type        = string
  default     = "HEAD"
}

variable "argocd_root_app_destination_namespace" {
  description = "Destination namespace used by the Argo CD root Application."
  type        = string
  default     = "argocd"
}
