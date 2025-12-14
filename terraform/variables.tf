# Variables for Zero Trust ACR Infrastructure

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US 2"
}

variable "company_prefix" {
  description = "Company prefix for naming convention"
  type        = string
  validation {
    condition     = length(var.company_prefix) <= 8 && length(var.company_prefix) >= 2
    error_message = "Company prefix must be between 2 and 8 characters."
  }
}

variable "owner" {
  description = "Resource owner for tagging"
  type        = string
}

variable "cost_center" {
  description = "Cost center for resource billing"
  type        = string
}

# Network Configuration
variable "allowed_cidr_ranges" {
  description = "List of CIDR ranges allowed to access ACR (for CI/CD if needed)"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access ACR"
  type        = list(string)
  default     = []
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

# Hub VNet subnet configuration
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

# AKS VNet subnet configuration
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

# CI/CD VNet subnet configuration
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

# ACR Configuration
variable "retention_days_untagged" {
  description = "Number of days to retain untagged manifests"
  type        = number
  default     = 7
  validation {
    condition     = var.retention_days_untagged >= 1 && var.retention_days_untagged <= 365
    error_message = "Retention days must be between 1 and 365."
  }
}

variable "enable_zone_redundancy" {
  description = "Enable zone redundancy for ACR"
  type        = bool
  default     = true
}

variable "geo_replication_locations" {
  description = "List of Azure regions for geo-replication"
  type        = list(string)
  default     = []
}

variable "cmk_enabled" {
  description = "Enable customer-managed keys for ACR encryption"
  type        = bool
  default     = true
}

# Logging Configuration
variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 90
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 30 and 730."
  }
}

# AKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.28"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 3
  validation {
    condition     = var.system_node_count >= 3 && var.system_node_count <= 10
    error_message = "System node count must be between 3 and 10."
  }
}

variable "user_node_count_min" {
  description = "Minimum number of nodes in the user node pool"
  type        = number
  default     = 2
}

variable "user_node_count_max" {
  description = "Maximum number of nodes in the user node pool"
  type        = number
  default     = 20
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for user node pool"
  type        = bool
  default     = true
}

variable "enable_network_policy" {
  description = "Enable Kubernetes network policy (Azure or Calico)"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "calico"], var.enable_network_policy)
    error_message = "Network policy must be either 'azure' or 'calico'."
  }
}

# Security Configuration
variable "enable_pod_security_policy" {
  description = "Enable Pod Security Policy (deprecated - use Pod Security Standards)"
  type        = bool
  default     = false
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = true
}

variable "enable_secret_store_csi" {
  description = "Enable Secret Store CSI driver"
  type        = bool
  default     = true
}

variable "enable_workload_identity" {
  description = "Enable Azure AD Workload Identity"
  type        = bool
  default     = true
}

variable "enable_oidc_issuer" {
  description = "Enable OIDC issuer URL"
  type        = bool
  default     = true
}

# CI/CD Configuration
variable "enable_acr_tasks" {
  description = "Enable ACR Tasks for automated builds"
  type        = bool
  default     = false
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "default_branch" {
  description = "Default git branch for CI/CD triggers"
  type        = string
  default     = "main"
}

# Monitoring Configuration
variable "enable_container_insights" {
  description = "Enable Azure Monitor for containers"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable managed Prometheus monitoring"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable managed Grafana dashboard"
  type        = bool
  default     = true
}

# Advanced Security
variable "enable_defender_for_containers" {
  description = "Enable Microsoft Defender for Containers"
  type        = bool
  default     = true
}

variable "enable_image_cleaner" {
  description = "Enable automated image cleanup"
  type        = bool
  default     = true
}

variable "enable_node_restriction" {
  description = "Enable node restriction admission controller"
  type        = bool
  default     = true
}

variable "enable_gpu_nodes" {
  description = "Enable GPU node pool for ML workloads"
  type        = bool
  default     = false
}

# Backup and DR
variable "enable_backup" {
  description = "Enable backup for AKS cluster"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

# Identity Configuration
variable "aad_admin_group_object_id" {
  description = "Azure AD group object ID for AKS cluster administrators"
  type        = string
  default     = ""
}

variable "aad_tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = ""
}

# Resource Limits
variable "max_pods_per_node" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 30
}

variable "enable_ultra_ssd" {
  description = "Enable Ultra SSD support"
  type        = bool
  default     = false
}

# Load Balancer Configuration
variable "load_balancer_sku" {
  description = "Load balancer SKU (Basic or Standard)"
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["basic", "standard"], lower(var.load_balancer_sku))
    error_message = "Load balancer SKU must be either 'basic' or 'standard'."
  }
}

variable "outbound_type" {
  description = "Outbound routing method (loadBalancer, userDefinedRouting, managedNATGateway)"
  type        = string
  default     = "loadBalancer"
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway"], var.outbound_type)
    error_message = "Outbound type must be one of: loadBalancer, userDefinedRouting, managedNATGateway."
  }
}

# Private Cluster Configuration
variable "private_cluster_enabled" {
  description = "Enable private AKS cluster"
  type        = bool
  default     = true
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for private cluster"
  type        = string
  default     = ""
}

# Maintenance Window
variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    allowed = list(object({
      day   = string
      hours = list(number)
    }))
    not_allowed = list(object({
      end   = string
      start = string
    }))
  })
  default = {
    allowed = [{
      day   = "Sunday"
      hours = [2, 3, 4, 5]
    }]
    not_allowed = []
  }
}