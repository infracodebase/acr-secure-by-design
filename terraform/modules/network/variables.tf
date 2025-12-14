# Network Module Variables

variable "location" {
  description = "Azure region for network resources"
  type        = string
}

variable "naming_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "network_resource_group_name" {
  description = "Name of the network resource group"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# VNet CIDR blocks
variable "hub_vnet_cidr" {
  description = "CIDR block for Hub VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_vnet_cidr" {
  description = "CIDR block for AKS VNet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "cicd_vnet_cidr" {
  description = "CIDR block for CI/CD VNet"
  type        = string
  default     = "10.2.0.0/16"
}

# Hub VNet subnet CIDR blocks
variable "hub_firewall_subnet" {
  description = "CIDR block for Hub Firewall subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "hub_gateway_subnet" {
  description = "CIDR block for Hub Gateway subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "hub_bastion_subnet" {
  description = "CIDR block for Hub Bastion subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "hub_private_endpoints_subnet" {
  description = "CIDR block for Hub Private Endpoints subnet"
  type        = string
  default     = "10.0.10.0/24"
}

# AKS VNet subnet CIDR blocks
variable "aks_system_pool_subnet" {
  description = "CIDR block for AKS System Pool subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "aks_user_pool_subnet" {
  description = "CIDR block for AKS User Pool subnet"
  type        = string
  default     = "10.1.2.0/24"
}

variable "aks_gpu_pool_subnet" {
  description = "CIDR block for AKS GPU Pool subnet"
  type        = string
  default     = "10.1.3.0/24"
}

variable "aks_private_link_subnet" {
  description = "CIDR block for AKS Private Link subnet"
  type        = string
  default     = "10.1.10.0/24"
}

variable "aks_virtual_nodes_subnet" {
  description = "CIDR block for AKS Virtual Nodes subnet"
  type        = string
  default     = "10.1.11.0/24"
}

# CI/CD VNet subnet CIDR blocks
variable "cicd_build_agents_subnet" {
  description = "CIDR block for CI/CD Build Agents subnet"
  type        = string
  default     = "10.2.1.0/24"
}

variable "cicd_private_endpoints_subnet" {
  description = "CIDR block for CI/CD Private Endpoints subnet"
  type        = string
  default     = "10.2.10.0/24"
}