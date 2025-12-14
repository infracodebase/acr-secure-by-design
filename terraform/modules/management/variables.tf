# Management Module Variables
# Zero Trust management infrastructure configuration

variable "location" {
  description = "Azure region for management resources"
  type        = string
}

variable "naming_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the management resource group"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# Network configuration
variable "hub_vnet_id" {
  description = "Hub VNet ID for private endpoint integration"
  type        = string
}

variable "hub_private_endpoints_subnet_id" {
  description = "Subnet ID for private endpoints in hub VNet"
  type        = string
}

# Log Analytics configuration
variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB for Log Analytics (-1 for no limit)"
  type        = number
  default     = 10

  validation {
    condition     = var.daily_quota_gb == -1 || var.daily_quota_gb >= 0.5
    error_message = "Daily quota must be -1 (no limit) or at least 0.5 GB."
  }
}

variable "reservation_capacity_gb" {
  description = "Reservation capacity in GB per day for cost optimization"
  type        = number
  default     = null

  validation {
    condition = var.reservation_capacity_gb == null || (
      var.reservation_capacity_gb >= 100 && var.reservation_capacity_gb <= 5000
    )
    error_message = "Reservation capacity must be null or between 100 and 5000 GB."
  }
}

# Key Vault configuration
variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access Key Vault (emergency access only)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip_range in var.allowed_ip_ranges : can(cidrhost(ip_range, 0))
    ])
    error_message = "All IP ranges must be valid CIDR blocks."
  }
}

# Monitoring configuration
variable "enable_private_monitoring" {
  description = "Enable private monitoring with Azure Monitor Private Link Scope"
  type        = bool
  default     = true
}

# Compliance and backup configuration
variable "enable_compliance_storage" {
  description = "Enable compliance storage account for audit logs backup"
  type        = bool
  default     = true
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be a valid option."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain backups and compliance data"
  type        = number
  default     = 90

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 7 and 365."
  }
}

# Cost management
variable "enable_budget_alerts" {
  description = "Enable budget alerts for cost management"
  type        = bool
  default     = true
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 1000

  validation {
    condition     = var.budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "budget_notifications" {
  description = "Budget notification configuration"
  type = list(object({
    enabled        = bool
    threshold      = number
    operator       = string
    threshold_type = string
    contact_emails = list(string)
  }))
  default = [
    {
      enabled        = true
      threshold      = 80
      operator       = "GreaterThan"
      threshold_type = "Actual"
      contact_emails = []
    },
    {
      enabled        = true
      threshold      = 100
      operator       = "GreaterThan"
      threshold_type = "Forecasted"
      contact_emails = []
    }
  ]
}

# Security configuration
variable "key_vault_firewall_enabled" {
  description = "Enable Key Vault firewall (recommended for Zero Trust)"
  type        = bool
  default     = true
}

variable "enable_advanced_threat_protection" {
  description = "Enable Advanced Threat Protection for storage accounts"
  type        = bool
  default     = true
}

# Data encryption
variable "customer_managed_key_enabled" {
  description = "Enable customer-managed keys for encryption"
  type        = bool
  default     = true
}

# Audit and compliance
variable "enable_activity_log_alerts" {
  description = "Enable activity log alerts for security monitoring"
  type        = bool
  default     = true
}

variable "enable_resource_health_alerts" {
  description = "Enable resource health alerts"
  type        = bool
  default     = true
}

# Workspace configuration
variable "workspace_capping_enabled" {
  description = "Enable daily cap on Log Analytics workspace"
  type        = bool
  default     = true
}

variable "workspace_public_network_access_enabled" {
  description = "Enable public network access to Log Analytics workspace"
  type        = bool
  default     = false
}

# Application Insights configuration
variable "app_insights_sampling_percentage" {
  description = "Sampling percentage for Application Insights"
  type        = number
  default     = 100

  validation {
    condition     = var.app_insights_sampling_percentage > 0 && var.app_insights_sampling_percentage <= 100
    error_message = "Sampling percentage must be between 0 and 100."
  }
}

variable "disable_ip_masking" {
  description = "Disable IP masking in Application Insights (not recommended for GDPR compliance)"
  type        = bool
  default     = false
}