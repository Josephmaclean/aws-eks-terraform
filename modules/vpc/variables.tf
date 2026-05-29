variable "name" {
  description = "Name prefix used for VPC resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones to use. Leave empty to use the first two available AZs in the selected region."
  type        = list(string)
  default     = []
}

variable "karpenter_discovery" {
  description = "Value for the karpenter.sh/discovery tag on private subnets."
  type        = string
  default     = ""
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Must match the number of selected availability zones."
  type        = list(string)
}

variable "firewall_subnet_cidrs" {
  description = "CIDR blocks for AWS Network Firewall endpoint subnets. Must match the number of selected availability zones."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets. Must match the number of selected availability zones."
  type        = list(string)
}
