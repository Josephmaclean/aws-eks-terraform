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
