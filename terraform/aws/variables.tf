variable "project_name" {
  default = "mineclifford"
}

variable "region" {
  default = "sa-east-1"
}

variable "vpc_name" {
  default = "mineclifford-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default = "10.0.0.0/16"
}

variable "subnet_name" {
  type    = string
  default = "mineclifford-subnet"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  default = "10.0.1.0/24"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "server_names" {
  description = "List of server instance names to create"
  type        = list(string)
  default     = ["instance1"]
}

variable "username" {
  default = "ubuntu"
}

variable "instance_type" {
  # t3.medium = 2 vCPU burstable, 4 GB RAM — required for 15-player vanilla Minecraft
  # ~$0.052/hr in sa-east-1; covered by $100 new-account credit for ~80 days
  default = "t3.medium"
}

variable "environment" {
  description = "Deployment environment (production, staging, development, test)"
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
  default     = "minecraft"
}

variable "disk_size_gb" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}