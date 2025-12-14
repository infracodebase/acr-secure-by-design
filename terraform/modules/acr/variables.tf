# ACR Module Variables
# Zero Trust Azure Container Registry configuration

variable "location" {
  description = "Azure region for ACR resources"
  type        = string
}

variable "naming_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for ACR"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# Network configuration
variable "hub_private_endpoints_subnet_id" {
  description = "Subnet ID for ACR private endpoints"
  type        = string
}

variable "acr_private_dns_zone_id" {
  description = "Private DNS zone ID for ACR"
  type        = string
}

# Monitoring and logging
variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID for CMK encryption"
  type        = string
}

# ACR configuration
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

  validation {
    condition = alltrue([
      for location in var.geo_replication_locations : length(location) > 0
    ])
    error_message = "All geo-replication locations must be non-empty strings."
  }
}

variable "cmk_enabled" {
  description = "Enable customer-managed key encryption"
  type        = bool
  default     = true
}

# Security configuration
variable "aks_kubelet_identity_object_id" {
  description = "AKS kubelet identity object ID for ACR pull access"
  type        = string
  default     = ""
}

variable "security_webhook_url" {
  description = "URL for security event webhook notifications"
  type        = string
  default     = "https://example.com/webhook"

  validation {
    condition     = can(regex("^https://", var.security_webhook_url))
    error_message = "Security webhook URL must use HTTPS for secure communication."
  }
}

variable "github_token" {
  description = "GitHub token for ACR tasks (should be provided via environment variable)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "scan_trigger_endpoint" {
  description = "Endpoint URL for vulnerability scan triggers"
  type        = string
  default     = "https://example.com/scan-trigger"

  validation {
    condition     = can(regex("^https://", var.scan_trigger_endpoint))
    error_message = "Scan trigger endpoint must use HTTPS for secure communication."
  }
}

# Advanced security features
variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access ACR (for emergency access)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip_range in var.allowed_ip_ranges : can(cidrhost(ip_range, 0))
    ])
    error_message = "All IP ranges must be valid CIDR blocks."
  }
}

variable "enable_export_policy" {
  description = "Enable export policy for ACR (should be disabled for Zero Trust)"
  type        = bool
  default     = false
}

variable "enable_anonymous_pull" {
  description = "Enable anonymous pull access (should be disabled for Zero Trust)"
  type        = bool
  default     = false
}

variable "vulnerability_scan_enabled" {
  description = "Enable automated vulnerability scanning"
  type        = bool
  default     = true
}

variable "content_trust_enabled" {
  description = "Enable content trust for image signing"
  type        = bool
  default     = true
}

variable "quarantine_policy_enabled" {
  description = "Enable quarantine policy for vulnerable images"
  type        = bool
  default     = true
}

# Network access configuration
variable "trusted_services" {
  description = "List of trusted Azure services allowed to bypass network rules"
  type        = list(string)
  default     = ["AzureServices"]

  validation {
    condition = alltrue([
      for service in var.trusted_services : contains(["None", "AzureServices"], service)
    ])
    error_message = "Trusted services must be 'None' or 'AzureServices'."
  }
}

# Data encryption configuration
variable "encryption_key_source" {
  description = "Source of encryption keys: Microsoft.Keyvault or Microsoft.Storage"
  type        = string
  default     = "Microsoft.Keyvault"

  validation {
    condition     = contains(["Microsoft.Keyvault", "Microsoft.Storage"], var.encryption_key_source)
    error_message = "Encryption key source must be either 'Microsoft.Keyvault' or 'Microsoft.Storage'."
  }
}