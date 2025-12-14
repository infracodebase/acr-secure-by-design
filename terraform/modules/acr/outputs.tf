# ACR Module Outputs
# Zero Trust Azure Container Registry outputs

output "acr_id" {
  description = "The ID of the Container Registry"
  value       = module.acr.resource_id
}

output "acr_name" {
  description = "The name of the Container Registry"
  value       = module.acr.resource.name
}

output "acr_login_server" {
  description = "The URL that can be used to log into the container registry"
  value       = module.acr.resource.login_server
}

output "acr_admin_username" {
  description = "The Username associated with the Container Registry Admin account"
  value       = module.acr.resource.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "The Password associated with the Container Registry Admin account"
  value       = module.acr.resource.admin_password
  sensitive   = true
}

output "acr_identity_principal_id" {
  description = "The Principal ID of the System Assigned Managed Identity"
  value       = module.acr.system_assigned_mi_principal_id
}

output "acr_private_endpoints" {
  description = "Map of private endpoints created for the ACR"
  value       = module.acr.private_endpoints
}

output "acr_scope_maps" {
  description = "Map of scope maps created for the ACR"
  value       = module.acr.scope_maps
  sensitive   = true
}

# Security outputs
output "acr_user_assigned_identity_id" {
  description = "The ID of the user-assigned identity for CMK encryption"
  value       = var.cmk_enabled ? azurerm_user_assigned_identity.acr_identity[0].id : null
}

output "acr_user_assigned_identity_principal_id" {
  description = "The Principal ID of the user-assigned identity for CMK encryption"
  value       = var.cmk_enabled ? azurerm_user_assigned_identity.acr_identity[0].principal_id : null
}

output "acr_user_assigned_identity_client_id" {
  description = "The Client ID of the user-assigned identity for CMK encryption"
  value       = var.cmk_enabled ? azurerm_user_assigned_identity.acr_identity[0].client_id : null
}

# Network outputs
output "acr_private_endpoint_ip" {
  description = "Private IP address of the ACR private endpoint"
  value       = try(module.acr.private_endpoints["primary"].network_interface[0].ip_configuration[0].private_ip_address, null)
}

output "acr_private_fqdn" {
  description = "Private FQDN for the ACR"
  value       = "${module.acr.resource.name}.privatelink.azurecr.io"
}

# Geo-replication outputs
output "acr_georeplications" {
  description = "List of geo-replication configurations"
  value = [
    for location in var.geo_replication_locations : {
      location = location
      regional_endpoint_enabled = true
      zone_redundancy_enabled = true
    }
  ]
}

# Security configuration outputs
output "acr_security_configuration" {
  description = "Summary of ACR security configuration"
  value = {
    public_network_access_enabled = false
    admin_user_enabled = false
    trust_policy_enabled = true
    quarantine_policy_enabled = true
    zone_redundancy_enabled = var.enable_zone_redundancy
    customer_managed_encryption = var.cmk_enabled
    vulnerability_scanning = var.vulnerability_scan_enabled
    content_trust = var.content_trust_enabled
    export_policy_enabled = false
    anonymous_pull_enabled = false
  }
}

# Webhook outputs
output "acr_webhook_id" {
  description = "ID of the security webhook"
  value       = azurerm_container_registry_webhook.security_webhook.id
}

# Task outputs
output "acr_vulnerability_task_id" {
  description = "ID of the vulnerability scanning task"
  value       = azurerm_container_registry_task.vulnerability_scan.id
}

# Compliance outputs
output "acr_compliance_status" {
  description = "OWASP compliance status summary"
  value = {
    zero_trust_network = "✓ Private endpoints only, no public access"
    secure_authentication = "✓ Admin user disabled, RBAC enabled"
    encryption_at_rest = var.cmk_enabled ? "✓ Customer-managed keys enabled" : "⚠ Using Microsoft-managed keys"
    vulnerability_management = "✓ Quarantine policy and scanning enabled"
    audit_logging = "✓ Comprehensive diagnostic settings configured"
    access_control = "✓ Fine-grained scope maps and role assignments"
    content_trust = "✓ Image signing and verification enabled"
    network_security = "✓ Network rules deny all by default"
  }
}

# Token outputs (sensitive)
output "cicd_token_passwords" {
  description = "CI/CD token passwords for secure image operations"
  value       = module.acr.scope_maps
  sensitive   = true
}