# Customer name
variable "customer" {
  default = "ap-tf"
}

# Azure region
variable "region" {
  default = "uksouth"
}

# CIDR block for the virtual network
variable "vnet_cidr" {
  default = "10.0.0.0/16"
}

# Name of the public subnet
variable "pubsub_name" {
  default = "dmz"
}

# CIDR for the public subnet
variable "pubsub_cidr" {
  default = "10.0.0.0/24"
}

# Number of private subnets
variable "prisub_count" {
  default = "3"
}

# List of names for the private subnets
variable "prisub_names" {
  default = {
    "0" = "web"
    "1" = "app"
    "2" = "data"
  }
}

# List of CIDRs for the private subnets
variable "prisub_cidrs" {
  default = {
    "0" = "10.0.1.0/24"
    "1" = "10.0.2.0/24"
    "2" = "10.0.3.0/24"
  }
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  default = "~/.ssh/id_rsa"
}

# Update this to create a new storage account
variable "storage_account_version" {
  default = "1"
}
