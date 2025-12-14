# AKS Module Variables
# Zero Trust Azure Kubernetes Service configuration

variable "location" {
  description = "Azure region for AKS resources"
  type        = string
}

variable "naming_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for AKS"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# Kubernetes configuration
variable "kubernetes_version" {
  description = "Kubernetes version to use"
  type        = string
  default     = "1.29"

  validation {
    condition     = can(regex("^\\d+\\.\\d+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format 'major.minor' (e.g., '1.29')."
  }
}

# Network configuration
variable "system_pool_subnet_id" {
  description = "Subnet ID for AKS system node pool"
  type        = string
}

variable "user_pool_subnet_id" {
  description = "Subnet ID for AKS user node pool"
  type        = string
}

variable "private_link_subnet_id" {
  description = "Subnet ID for AKS private endpoints"
  type        = string
}

variable "pod_cidr" {
  description = "CIDR block for pods"
  type        = string
  default     = "192.168.0.0/16"

  validation {
    condition     = can(cidrhost(var.pod_cidr, 0))
    error_message = "Pod CIDR must be a valid CIDR block."
  }
}

variable "service_cidr" {
  description = "CIDR block for services"
  type        = string
  default     = "10.100.0.0/16"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "Service CIDR must be a valid CIDR block."
  }
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.100.0.10"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.dns_service_ip))
    error_message = "DNS service IP must be a valid IPv4 address."
  }
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for private AKS cluster"
  type        = string
}

variable "acr_private_dns_zone_id" {
  description = "Private DNS zone ID for ACR integration"
  type        = string
}

# Node pool configuration
variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "system_node_count" {
  description = "Number of nodes in system pool"
  type        = number
  default     = 3

  validation {
    condition     = var.system_node_count >= 1 && var.system_node_count <= 1000
    error_message = "System node count must be between 1 and 1000."
  }
}

variable "user_node_count_min" {
  description = "Minimum number of nodes in user pool"
  type        = number
  default     = 2

  validation {
    condition     = var.user_node_count_min >= 0 && var.user_node_count_min <= 1000
    error_message = "User node minimum count must be between 0 and 1000."
  }
}

variable "user_node_count_max" {
  description = "Maximum number of nodes in user pool"
  type        = number
  default     = 20

  validation {
    condition     = var.user_node_count_max >= 0 && var.user_node_count_max <= 1000
    error_message = "User node maximum count must be between 0 and 1000."
  }
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "os_sku" {
  description = "OS SKU for nodes"
  type        = string
  default     = "AzureLinux"

  validation {
    condition     = contains(["Ubuntu", "AzureLinux"], var.os_sku)
    error_message = "OS SKU must be either 'Ubuntu' or 'AzureLinux'."
  }
}

variable "os_disk_type" {
  description = "OS disk type for nodes"
  type        = string
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Managed", "Ephemeral", "Premium_LRS", "StandardSSD_LRS", "Standard_LRS"], var.os_disk_type)
    error_message = "OS disk type must be a valid disk type."
  }
}

# GPU configuration
variable "enable_gpu_nodes" {
  description = "Enable GPU node pool for ML workloads"
  type        = bool
  default     = false
}

variable "gpu_vm_size" {
  description = "VM size for GPU nodes"
  type        = string
  default     = "Standard_NC6s_v3"
}

variable "gpu_node_count_min" {
  description = "Minimum number of GPU nodes"
  type        = number
  default     = 0

  validation {
    condition     = var.gpu_node_count_min >= 0 && var.gpu_node_count_min <= 1000
    error_message = "GPU node minimum count must be between 0 and 1000."
  }
}

variable "gpu_node_count_max" {
  description = "Maximum number of GPU nodes"
  type        = number
  default     = 5

  validation {
    condition     = var.gpu_node_count_max >= 0 && var.gpu_node_count_max <= 1000
    error_message = "GPU node maximum count must be between 0 and 1000."
  }
}

# Network policy and security
variable "enable_network_policy" {
  description = "Network policy to use (calico, cilium, or none)"
  type        = string
  default     = "cilium"

  validation {
    condition     = contains(["calico", "cilium", "none"], var.enable_network_policy)
    error_message = "Network policy must be 'calico', 'cilium', or 'none'."
  }
}

variable "outbound_type" {
  description = "Outbound traffic type for AKS cluster"
  type        = string
  default     = "userDefinedRouting"

  validation {
    condition = contains([
      "loadBalancer",
      "userDefinedRouting",
      "managedNATGateway",
      "userAssignedNATGateway"
    ], var.outbound_type)
    error_message = "Outbound type must be a valid option."
  }
}

# Security features
variable "enable_azure_policy" {
  description = "Enable Azure Policy addon for compliance"
  type        = bool
  default     = true
}

variable "enable_secret_store_csi" {
  description = "Enable Key Vault secrets store CSI driver"
  type        = bool
  default     = true
}

variable "enable_workload_identity" {
  description = "Enable workload identity for secure pod authentication"
  type        = bool
  default     = true
}

variable "enable_oidc_issuer" {
  description = "Enable OIDC issuer for workload identity"
  type        = bool
  default     = true
}

variable "enable_defender_for_containers" {
  description = "Enable Microsoft Defender for Containers"
  type        = bool
  default     = true
}

variable "enable_image_cleaner" {
  description = "Enable automatic cleanup of unused images"
  type        = bool
  default     = true
}

# Monitoring configuration
variable "enable_container_insights" {
  description = "Enable Container Insights monitoring"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for monitoring"
  type        = string
}

# Identity configuration
variable "enable_azure_rbac" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

variable "aad_tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = ""
}

variable "aad_admin_group_object_ids" {
  description = "List of Azure AD group object IDs with admin access"
  type        = list(string)
  default     = []
}

variable "user_assigned_identity_ids" {
  description = "List of user-assigned managed identity IDs"
  type        = list(string)
  default     = []
}

# ACR integration
variable "acr_id" {
  description = "Azure Container Registry ID for integration"
  type        = string
  default     = ""
}

variable "enable_zone_redundancy" {
  description = "Enable zone redundancy for high availability"
  type        = bool
  default     = true
}

# Node labels and taints
variable "node_labels" {
  description = "Kubernetes labels for nodes"
  type        = map(string)
  default = {
    "environment" = "production"
    "security"    = "zero-trust"
  }
}

# Advanced configuration
variable "max_pods_per_node" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 50

  validation {
    condition     = var.max_pods_per_node >= 10 && var.max_pods_per_node <= 250
    error_message = "Max pods per node must be between 10 and 250."
  }
}

variable "load_balancer_sku" {
  description = "Load balancer SKU"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["basic", "standard"], var.load_balancer_sku)
    error_message = "Load balancer SKU must be 'basic' or 'standard'."
  }
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    allowed = list(object({
      day   = string
      hours = list(number)
    }))
    not_allowed = list(object({
      start = string
      end   = string
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

# Backup and disaster recovery
variable "enable_backup" {
  description = "Enable AKS backup (using Velero or similar)"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}