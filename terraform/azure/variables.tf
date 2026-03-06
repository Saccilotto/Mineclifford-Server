variable "resource_group_name" {
  default = "mineclifford"
}

variable "location" {
  description = "Azure region where resources will be created"
  default = "East US 2"
}

variable "vnet_name" {
  default = "mineclifford-vnet"
}

variable "address_space" {
  default = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "Name of the subnet"
  type    = string
  default = "mineclifford-subnet"
}

variable "subnet_prefixes" {
  description = "Address prefixes for the subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
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
  description = "Azure VM size for standalone instances"
  type        = string
  default     = "Standard_B2s"
}

variable "disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
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

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}