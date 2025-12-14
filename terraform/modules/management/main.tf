# Management Module for Zero Trust ACR Infrastructure
# Centralized logging, monitoring, and secrets management with OWASP compliance

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.56"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Generate unique Key Vault name
resource "random_string" "keyvault_suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  key_vault_name = "${replace(var.naming_prefix, "-", "")}kv${random_string.keyvault_suffix.result}"
}

# Log Analytics Workspace for centralized logging - OWASP: comprehensive audit logging
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.naming_prefix}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  # Security configuration
  daily_quota_gb                     = var.daily_quota_gb
  internet_ingestion_enabled         = false # Zero Trust: no internet access
  internet_query_enabled            = false # Zero Trust: no internet access
  reservation_capacity_in_gb_per_day = var.reservation_capacity_gb

  tags = merge(var.common_tags, {
    Service = "Logging"
    Purpose = "CentralizedAuditLogging"
  })
}

# Application Insights for application monitoring
resource "azurerm_application_insights" "main" {
  name                = "${var.naming_prefix}-appinsights"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "other"

  # Security configuration - OWASP: secure monitoring
  internet_ingestion_enabled = false
  internet_query_enabled    = false
  force_customer_storage_for_profiler = true

  tags = merge(var.common_tags, {
    Service = "Monitoring"
    Purpose = "ApplicationInsights"
  })
}

# Key Vault for secrets management - OWASP: secure credentials storage
resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"

  # Security configuration - OWASP: comprehensive security
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false  # OWASP: disable unnecessary features
  enabled_for_template_deployment = false  # OWASP: disable unnecessary features
  purge_protection_enabled        = true   # OWASP: prevent accidental deletion
  soft_delete_retention_days      = 90

  # Network access restrictions - Zero Trust
  public_network_access_enabled = false
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
    virtual_network_subnet_ids = []
  }

  # RBAC for fine-grained access control
  enable_rbac_authorization = true

  tags = merge(var.common_tags, {
    Service = "KeyVault"
    Purpose = "SecretsManagement"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# Key Vault Private Endpoint for Zero Trust access
resource "azurerm_private_endpoint" "key_vault" {
  name                = "${var.naming_prefix}-kv-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id          = var.hub_private_endpoints_subnet_id

  private_service_connection {
    name                           = "${var.naming_prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }

  tags = var.common_tags
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name

  tags = merge(var.common_tags, {
    Service = "DNS"
    Purpose = "KeyVaultPrivateEndpoint"
  })
}

# Link Key Vault DNS zone to Hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault_hub" {
  name                  = "kv-hub-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = false

  tags = var.common_tags
}

# Log Analytics Private Endpoint for secure access
resource "azurerm_private_endpoint" "log_analytics" {
  count = var.enable_private_monitoring ? 1 : 0

  name                = "${var.naming_prefix}-logs-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id          = var.hub_private_endpoints_subnet_id

  private_service_connection {
    name                           = "${var.naming_prefix}-logs-psc"
    private_connection_resource_id = azurerm_monitor_private_link_scope.main[0].id
    is_manual_connection           = false
    subresource_names              = ["azuremonitor"]
  }

  tags = var.common_tags
}

# Azure Monitor Private Link Scope for secure monitoring
resource "azurerm_monitor_private_link_scope" "main" {
  count = var.enable_private_monitoring ? 1 : 0

  name                = "${var.naming_prefix}-monitor-pls"
  resource_group_name = var.resource_group_name

  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"

  tags = var.common_tags
}

# Connect Log Analytics to Private Link Scope
resource "azurerm_monitor_private_link_scoped_service" "log_analytics" {
  count = var.enable_private_monitoring ? 1 : 0

  name                = "logs-scoped-service"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main[0].name
  linked_resource_id  = azurerm_log_analytics_workspace.main.id
}

# Connect Application Insights to Private Link Scope
resource "azurerm_monitor_private_link_scoped_service" "app_insights" {
  count = var.enable_private_monitoring ? 1 : 0

  name                = "appinsights-scoped-service"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main[0].name
  linked_resource_id  = azurerm_application_insights.main.id
}

# Customer-managed encryption key for ACR
resource "azurerm_key_vault_key" "acr_encryption" {
  name         = "acr-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA-HSM"  # HSM-backed key for enhanced security
  key_size     = 2048

  # Set expiration date for security best practices (1 year from creation)
  expiration_date = timeadd(timestamp(), "8760h") # 365 days

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  # Rotation policy for automatic key rotation
  rotation_policy {
    automatic {
      time_before_expiry = "P30D" # Rotate 30 days before expiry
    }
    expire_after         = "P1Y"  # Expire after 1 year
    notify_before_expiry = "P30D" # Notify 30 days before expiry
  }

  tags = merge(var.common_tags, {
    Purpose = "ACREncryption"
  })

  depends_on = [azurerm_key_vault.main]
}

# Content trust signing key for ACR
resource "azurerm_key_vault_key" "content_trust" {
  name         = "acr-content-trust-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA-HSM"  # HSM-backed key for enhanced security
  key_size     = 2048

  # Set expiration date for security best practices (1 year from creation)
  expiration_date = timeadd(timestamp(), "8760h") # 365 days

  key_opts = [
    "sign",
    "verify",
  ]

  # Rotation policy for automatic key rotation
  rotation_policy {
    automatic {
      time_before_expiry = "P30D" # Rotate 30 days before expiry
    }
    expire_after         = "P1Y"  # Expire after 1 year
    notify_before_expiry = "P30D" # Notify 30 days before expiry
  }

  tags = merge(var.common_tags, {
    Purpose = "ContentTrust"
  })

  depends_on = [azurerm_key_vault.main]
}

# Diagnostic settings for Key Vault - OWASP: audit logging
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "kv-diagnostics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
  }
}

# Customer-managed encryption key for storage account
resource "azurerm_key_vault_key" "storage_encryption" {
  count = var.enable_compliance_storage ? 1 : 0

  name         = "storage-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA-HSM"  # HSM-backed key for enhanced security
  key_size     = 2048

  # Set expiration date for security best practices (1 year from creation)
  expiration_date = timeadd(timestamp(), "8760h") # 365 days

  key_opts = [
    "decrypt",
    "encrypt",
    "unwrapKey",
    "wrapKey",
  ]

  # Rotation policy for automatic key rotation
  rotation_policy {
    automatic {
      time_before_expiry = "P30D" # Rotate 30 days before expiry
    }
    expire_after         = "P1Y"  # Expire after 1 year
    notify_before_expiry = "P30D" # Notify 30 days before expiry
  }

  tags = merge(var.common_tags, {
    Purpose = "StorageEncryption"
  })

  depends_on = [azurerm_key_vault.main]
}

# Storage Account for backup and compliance
resource "azurerm_storage_account" "compliance" {
  count = var.enable_compliance_storage ? 1 : 0

  name                = "${replace(var.naming_prefix, "-", "")}compliance${random_string.storage_suffix[0].result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  account_tier        = "Standard"
  account_replication_type = var.storage_replication_type

  # Security configuration - OWASP compliance
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false  # Disable shared key access for enhanced security

  # Advanced security features
  infrastructure_encryption_enabled = true

  # Customer-managed encryption
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage_encryption[0].id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage[0].id
  }

  # SAS policy configuration for security
  sas_policy {
    expiration_period = "1.00:00:00"  # 1 day SAS expiration
    expiration_action = "Log"
  }

  blob_properties {
    versioning_enabled  = true
    delete_retention_policy {
      days = var.backup_retention_days
    }
    container_delete_retention_policy {
      days = var.backup_retention_days
    }
  }

  # Queue properties for logging compliance
  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = var.backup_retention_days
    }
  }

  tags = merge(var.common_tags, {
    Service = "Storage"
    Purpose = "ComplianceBackup"
  })

  depends_on = [
    azurerm_key_vault_key.storage_encryption,
    azurerm_user_assigned_identity.storage
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage[0].id]
  }
}

resource "random_string" "storage_suffix" {
  count = var.enable_compliance_storage ? 1 : 0

  length  = 4
  special = false
  upper   = false
}

# User-assigned identity for storage account encryption
resource "azurerm_user_assigned_identity" "storage" {
  count = var.enable_compliance_storage ? 1 : 0

  name                = "${var.naming_prefix}-storage-identity"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.common_tags, {
    Purpose = "StorageEncryption"
  })
}

# Key Vault access policy for storage identity
resource "azurerm_key_vault_access_policy" "storage" {
  count = var.enable_compliance_storage ? 1 : 0

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.storage[0].principal_id

  key_permissions = [
    "Get",
    "UnwrapKey",
    "WrapKey"
  ]

  depends_on = [azurerm_user_assigned_identity.storage]
}

# Storage Account Private Endpoint for Zero Trust access
resource "azurerm_private_endpoint" "storage" {
  count = var.enable_compliance_storage ? 1 : 0

  name                = "${var.naming_prefix}-storage-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id          = var.hub_private_endpoints_subnet_id

  private_service_connection {
    name                           = "${var.naming_prefix}-storage-psc"
    private_connection_resource_id = azurerm_storage_account.compliance[0].id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage[0].id]
  }

  tags = var.common_tags
}

# Private DNS Zone for Storage Account
resource "azurerm_private_dns_zone" "storage" {
  count = var.enable_compliance_storage ? 1 : 0

  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name

  tags = merge(var.common_tags, {
    Service = "DNS"
    Purpose = "StoragePrivateEndpoint"
  })
}

# Link Storage DNS zone to Hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage_hub" {
  count = var.enable_compliance_storage ? 1 : 0

  name                  = "storage-hub-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage[0].name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = false

  tags = var.common_tags
}

# Diagnostic settings for Storage Account - OWASP: audit logging
resource "azurerm_monitor_diagnostic_setting" "storage" {
  count = var.enable_compliance_storage ? 1 : 0

  name                       = "storage-diagnostics"
  target_resource_id         = azurerm_storage_account.compliance[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "audit"
  }

  metric {
    category = "AllMetrics"
  }
}

# Budget for cost control - OWASP: resource management
resource "azurerm_consumption_budget_resource_group" "main" {
  count = var.enable_budget_alerts ? 1 : 0

  name              = "${var.naming_prefix}-budget"
  resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  amount     = var.budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("2006-01-01T15:04:05Z", timestamp())
    end_date   = formatdate("2006-01-01T15:04:05Z", timeadd(timestamp(), "8760h")) # 1 year
  }

  dynamic "notification" {
    for_each = var.budget_notifications
    content {
      enabled        = notification.value.enabled
      threshold      = notification.value.threshold
      operator       = notification.value.operator
      threshold_type = notification.value.threshold_type
      contact_emails = notification.value.contact_emails
    }
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}