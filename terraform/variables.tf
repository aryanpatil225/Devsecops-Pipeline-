variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "key_name" {
  description = devops.pem
  type        = string
  default     = "devsecops-key"
}
