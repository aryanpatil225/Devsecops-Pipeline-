variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "key_name" {
  description = "SSH key pair name (create this in AWS EC2 console first)"
  type        = string
  default     = "devsecops-key"
}
