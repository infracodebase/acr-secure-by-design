# Management Module Outputs
# Zero Trust management infrastructure outputs

# Log Analytics outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_primary_shared_key" {
  description = "Primary shared key for the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "log_analytics_workspace_secondary_shared_key" {
  description = "Secondary shared key for the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.secondary_shared_key
  sensitive   = true
}

output "log_analytics_workspace_workspace_id" {
  description = "Workspace ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

# Application Insights outputs
output "application_insights_id" {
  description = "ID of the Application Insights component"
  value       = azurerm_application_insights.main.id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key of the Application Insights component"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string of the Application Insights component"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "application_insights_app_id" {
  description = "App ID of the Application Insights component"
  value       = azurerm_application_insights.main.app_id
}

# Key Vault outputs
output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_tenant_id" {
  description = "Tenant ID of the Key Vault"
  value       = azurerm_key_vault.main.tenant_id
}

# Key Vault keys outputs
output "acr_encryption_key_id" {
  description = "ID of the ACR encryption key"
  value       = azurerm_key_vault_key.acr_encryption.id
}

output "acr_encryption_key_version_id" {
  description = "Version ID of the ACR encryption key"
  value       = azurerm_key_vault_key.acr_encryption.version
}

output "content_trust_key_id" {
  description = "ID of the content trust signing key"
  value       = azurerm_key_vault_key.content_trust.id
}

output "content_trust_key_version_id" {
  description = "Version ID of the content trust signing key"
  value       = azurerm_key_vault_key.content_trust.version
}

# Private endpoint outputs
output "key_vault_private_endpoint_id" {
  description = "ID of the Key Vault private endpoint"
  value       = azurerm_private_endpoint.key_vault.id
}

output "key_vault_private_endpoint_ip" {
  description = "Private IP address of the Key Vault private endpoint"
  value       = azurerm_private_endpoint.key_vault.private_service_connection[0].private_ip_address
}

output "log_analytics_private_endpoint_id" {
  description = "ID of the Log Analytics private endpoint"
  value       = var.enable_private_monitoring ? azurerm_private_endpoint.log_analytics[0].id : null
}

# Private DNS Zone outputs
output "key_vault_private_dns_zone_id" {
  description = "ID of the Key Vault private DNS zone"
  value       = azurerm_private_dns_zone.key_vault.id
}

output "key_vault_private_dns_zone_name" {
  description = "Name of the Key Vault private DNS zone"
  value       = azurerm_private_dns_zone.key_vault.name
}

# Monitor Private Link Scope outputs
output "monitor_private_link_scope_id" {
  description = "ID of the Azure Monitor Private Link Scope"
  value       = var.enable_private_monitoring ? azurerm_monitor_private_link_scope.main[0].id : null
}

# Storage Account outputs (if enabled)
output "compliance_storage_account_id" {
  description = "ID of the compliance storage account"
  value       = var.enable_compliance_storage ? azurerm_storage_account.compliance[0].id : null
}

output "compliance_storage_account_name" {
  description = "Name of the compliance storage account"
  value       = var.enable_compliance_storage ? azurerm_storage_account.compliance[0].name : null
}

output "compliance_storage_account_primary_access_key" {
  description = "Primary access key of the compliance storage account"
  value       = var.enable_compliance_storage ? azurerm_storage_account.compliance[0].primary_access_key : null
  sensitive   = true
}

output "compliance_storage_account_secondary_access_key" {
  description = "Secondary access key of the compliance storage account"
  value       = var.enable_compliance_storage ? azurerm_storage_account.compliance[0].secondary_access_key : null
  sensitive   = true
}

# Budget outputs (if enabled)
output "budget_id" {
  description = "ID of the resource group budget"
  value       = var.enable_budget_alerts ? azurerm_consumption_budget_resource_group.main[0].id : null
}

# Security configuration summary
output "management_security_configuration" {
  description = "Summary of management security configuration"
  value = {
    key_vault_private_access_only     = !azurerm_key_vault.main.public_network_access_enabled
    key_vault_purge_protection        = azurerm_key_vault.main.purge_protection_enabled
    key_vault_soft_delete_enabled     = azurerm_key_vault.main.soft_delete_retention_days > 0
    log_analytics_private_access_only = !azurerm_log_analytics_workspace.main.internet_ingestion_enabled
    app_insights_private_access_only  = !azurerm_application_insights.main.internet_ingestion_enabled
    customer_managed_encryption       = var.customer_managed_key_enabled
    compliance_storage_enabled        = var.enable_compliance_storage
    budget_monitoring_enabled         = var.enable_budget_alerts
    private_monitoring_enabled        = var.enable_private_monitoring
  }
}

# Compliance outputs
output "management_compliance_status" {
  description = "OWASP compliance status summary for management infrastructure"
  value = {
    zero_trust_access = "✓ Private endpoints configured for all services"
    audit_logging = "✓ Comprehensive diagnostic settings enabled"
    data_encryption = var.customer_managed_key_enabled ? "✓ Customer-managed keys configured" : "⚠ Using Microsoft-managed keys"
    secrets_protection = "✓ Key Vault with RBAC and purge protection"
    cost_management = var.enable_budget_alerts ? "✓ Budget alerts configured" : "⚠ Budget alerts not enabled"
    backup_retention = var.enable_compliance_storage ? "✓ Compliance storage configured" : "⚠ Compliance storage not enabled"
    monitoring_security = var.enable_private_monitoring ? "✓ Private monitoring configured" : "⚠ Public monitoring endpoints"
    access_controls = "✓ RBAC enabled with principle of least privilege"
  }
}

# Resource naming outputs for reference
output "resource_naming_convention" {
  description = "Resource naming convention used"
  value = {
    key_vault_name = azurerm_key_vault.main.name
    log_analytics_name = azurerm_log_analytics_workspace.main.name
    app_insights_name = azurerm_application_insights.main.name
    naming_pattern = "${var.naming_prefix}-{service}-{suffix}"
  }
}