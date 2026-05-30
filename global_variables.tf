variable "aws_region" {
  description = "AWS region to deploy into."
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

variable "tags" {
  description = "Default tags applied to all supported AWS resources."
  type        = map(string)
  default = {
    Project     = "private-eks"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
