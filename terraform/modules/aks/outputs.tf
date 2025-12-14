# AKS Module Outputs
# Zero Trust Azure Kubernetes Service outputs

# Cluster identification
output "aks_id" {
  description = "The ID of the Azure Kubernetes Service cluster"
  value       = module.aks_production.resource_id
}

output "aks_name" {
  description = "The name of the Azure Kubernetes Service cluster"
  value       = "${var.naming_prefix}-aks"
}

output "aks_fqdn" {
  description = "The FQDN of the Azure Kubernetes Service cluster"
  value       = module.aks_production.fqdn
}

output "aks_private_fqdn" {
  description = "The private FQDN of the Azure Kubernetes Service cluster"
  value       = module.aks_production.private_fqdn
}

output "aks_portal_fqdn" {
  description = "The portal FQDN of the Azure Kubernetes Service cluster"
  value       = module.aks_production.portal_fqdn
}

# Kubernetes configuration
output "kube_config" {
  description = "Kubernetes configuration for kubectl access"
  value       = module.aks_production.kube_config
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw Kubernetes configuration"
  value       = module.aks_production.kube_config_raw
  sensitive   = true
}

output "kube_admin_config" {
  description = "Kubernetes admin configuration for cluster admin access"
  value       = module.aks_production.kube_admin_config
  sensitive   = true
}

output "kube_admin_config_raw" {
  description = "Raw Kubernetes admin configuration"
  value       = module.aks_production.kube_admin_config_raw
  sensitive   = true
}

output "kubernetes_version" {
  description = "The current Kubernetes version running on the cluster"
  value       = module.aks_production.current_kubernetes_version
}

# Identity outputs
output "kubelet_identity_object_id" {
  description = "The Object ID of the kubelet managed identity"
  value       = module.aks_production.kubelet_identity_object_id
}

output "kubelet_identity_client_id" {
  description = "The Client ID of the kubelet managed identity"
  value       = module.aks_production.kubelet_identity_client_id
}

output "kubelet_identity_user_assigned_identity_id" {
  description = "The User Assigned Identity ID of the kubelet"
  value       = module.aks_production.kubelet_identity_user_assigned_identity_id
}

output "identity_principal_id" {
  description = "The Principal ID of the managed identity"
  value       = module.aks_production.identity_principal_id
}

output "identity_tenant_id" {
  description = "The Tenant ID of the managed identity"
  value       = module.aks_production.identity_tenant_id
}

# User-assigned identity outputs
output "aks_user_assigned_identity_id" {
  description = "The ID of the user-assigned identity for AKS"
  value       = azurerm_user_assigned_identity.aks_identity.id
}

output "aks_user_assigned_identity_principal_id" {
  description = "The Principal ID of the user-assigned identity for AKS"
  value       = azurerm_user_assigned_identity.aks_identity.principal_id
}

output "aks_user_assigned_identity_client_id" {
  description = "The Client ID of the user-assigned identity for AKS"
  value       = azurerm_user_assigned_identity.aks_identity.client_id
}

# OIDC issuer for workload identity
output "oidc_issuer_url" {
  description = "The OIDC issuer URL for workload identity"
  value       = module.aks_production.oidc_issuer_url
}

# Network configuration
output "network_profile" {
  description = "The network profile of the AKS cluster"
  value       = module.aks_production.network_profile
}

output "load_balancer_profile_effective_outbound_ips" {
  description = "The effective outbound IPs for the load balancer"
  value       = module.aks_production.load_balancer_profile_effective_outbound_ips
}

output "nat_gateway_profile_effective_outbound_ips" {
  description = "The effective outbound IPs for the NAT gateway"
  value       = module.aks_production.nat_gateway_profile_effective_outbound_ips
}

# Node resource group
output "node_resource_group" {
  description = "The auto-generated resource group for cluster nodes"
  value       = module.aks_production.node_resource_group
}

output "node_resource_group_id" {
  description = "The ID of the auto-generated resource group for cluster nodes"
  value       = module.aks_production.node_resource_group_id
}

# Add-on outputs
output "oms_agent_identity_client_id" {
  description = "The Client ID of the OMS Agent managed identity"
  value       = module.aks_production.oms_agent_identity_client_id
}

output "oms_agent_identity_object_id" {
  description = "The Object ID of the OMS Agent managed identity"
  value       = module.aks_production.oms_agent_identity_object_id
}

output "oms_agent_identity_user_assigned_identity_id" {
  description = "The User Assigned Identity ID of the OMS Agent"
  value       = module.aks_production.oms_agent_identity_user_assigned_identity_id
}

output "key_vault_secrets_provider_secret_identity_client_id" {
  description = "The Client ID of the Key Vault Secrets Provider identity"
  value       = module.aks_production.key_vault_secrets_provider_secret_identity_client_id
}

output "key_vault_secrets_provider_secret_identity_object_id" {
  description = "The Object ID of the Key Vault Secrets Provider identity"
  value       = module.aks_production.key_vault_secrets_provider_secret_identity_object_id
}

output "key_vault_secrets_provider_secret_identity_user_assigned_identity_id" {
  description = "The User Assigned Identity ID of the Key Vault Secrets Provider"
  value       = module.aks_production.key_vault_secrets_provider_secret_identity_user_assigned_identity_id
}

# Application Gateway (if enabled)
output "ingress_application_gateway_identity_client_id" {
  description = "The Client ID of the Application Gateway ingress managed identity"
  value       = module.aks_production.ingress_application_gateway_identity_client_id
}

output "ingress_application_gateway_identity_object_id" {
  description = "The Object ID of the Application Gateway ingress managed identity"
  value       = module.aks_production.ingress_application_gateway_identity_object_id
}

output "ingress_application_gateway_identity_user_assigned_identity_id" {
  description = "The User Assigned Identity ID of the Application Gateway ingress"
  value       = module.aks_production.ingress_application_gateway_identity_user_assigned_identity_id
}

# Web App Routing (if enabled)
output "web_app_routing_web_app_routing_identity_client_id" {
  description = "The Client ID of the Web App Routing managed identity"
  value       = module.aks_production.web_app_routing_web_app_routing_identity_client_id
}

output "web_app_routing_web_app_routing_identity_object_id" {
  description = "The Object ID of the Web App Routing managed identity"
  value       = module.aks_production.web_app_routing_web_app_routing_identity_object_id
}

output "web_app_routing_web_app_routing_identity_user_assigned_identity_id" {
  description = "The User Assigned Identity ID of the Web App Routing"
  value       = module.aks_production.web_app_routing_web_app_routing_identity_user_assigned_identity_id
}

# HTTP Application Routing (deprecated but might be present)
output "http_application_routing_zone_name" {
  description = "The zone name for HTTP Application Routing"
  value       = module.aks_production.http_application_routing_zone_name
}

# Security configuration summary
output "aks_security_configuration" {
  description = "Summary of AKS security configuration"
  value = {
    private_cluster_enabled         = true
    network_policy_enabled         = var.enable_network_policy != "none"
    network_policy_type            = var.enable_network_policy
    azure_policy_enabled           = var.enable_azure_policy
    secret_store_csi_enabled       = var.enable_secret_store_csi
    workload_identity_enabled      = var.enable_workload_identity
    oidc_issuer_enabled           = var.enable_oidc_issuer
    defender_for_containers_enabled = var.enable_defender_for_containers
    image_cleaner_enabled         = var.enable_image_cleaner
    azure_rbac_enabled            = var.enable_azure_rbac
    container_insights_enabled    = var.enable_container_insights
    prometheus_monitoring_enabled = var.enable_prometheus
    outbound_type                 = var.outbound_type
    load_balancer_sku            = var.load_balancer_sku
  }
}

# Compliance status
output "aks_compliance_status" {
  description = "OWASP compliance status summary for AKS"
  value = {
    zero_trust_network = "✓ Private cluster with network policies enabled"
    secure_authentication = var.enable_azure_rbac ? "✓ Azure RBAC enabled with AAD integration" : "⚠ Azure RBAC not enabled"
    workload_identity = var.enable_workload_identity ? "✓ Workload identity enabled for secure pod authentication" : "⚠ Workload identity not enabled"
    secrets_management = var.enable_secret_store_csi ? "✓ Key Vault CSI driver enabled" : "⚠ Key Vault CSI driver not enabled"
    policy_enforcement = var.enable_azure_policy ? "✓ Azure Policy addon enabled for compliance" : "⚠ Azure Policy addon not enabled"
    threat_protection = var.enable_defender_for_containers ? "✓ Microsoft Defender for Containers enabled" : "⚠ Microsoft Defender not enabled"
    audit_logging = "✓ Comprehensive audit logging configured"
    network_segmentation = var.enable_network_policy != "none" ? "✓ Network policies configured for micro-segmentation" : "⚠ Network policies not configured"
    container_security = var.enable_image_cleaner ? "✓ Automatic image cleanup enabled" : "⚠ Image cleanup not enabled"
    monitoring = var.enable_container_insights ? "✓ Container Insights and monitoring enabled" : "⚠ Container Insights not enabled"
  }
}

# Network Security Group outputs
output "aks_nsg_id" {
  description = "ID of the Network Security Group for AKS"
  value       = azurerm_network_security_group.aks_nsg.id
}

output "aks_nsg_name" {
  description = "Name of the Network Security Group for AKS"
  value       = azurerm_network_security_group.aks_nsg.name
}

# Extension outputs
output "secrets_provider_extension_id" {
  description = "ID of the Key Vault Secrets Provider extension"
  value       = var.enable_secret_store_csi ? azurerm_kubernetes_cluster_extension.secrets_provider[0].id : null
}

output "azure_policy_extension_id" {
  description = "ID of the Azure Policy extension"
  value       = var.enable_azure_policy ? azurerm_kubernetes_cluster_extension.azure_policy[0].id : null
}

output "defender_extension_id" {
  description = "ID of the Microsoft Defender extension"
  value       = var.enable_defender_for_containers ? azurerm_kubernetes_cluster_extension.defender[0].id : null
}

# Diagnostic settings
output "aks_diagnostic_setting_id" {
  description = "ID of the diagnostic setting for AKS"
  value       = azurerm_monitor_diagnostic_setting.aks_diagnostics.id
}