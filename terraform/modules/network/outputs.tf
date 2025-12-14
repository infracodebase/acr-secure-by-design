# Network Module Outputs

# VNet outputs
output "hub_vnet_id" {
  description = "ID of the Hub Virtual Network"
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the Hub Virtual Network"
  value       = azurerm_virtual_network.hub.name
}

output "aks_vnet_id" {
  description = "ID of the AKS Virtual Network"
  value       = azurerm_virtual_network.aks.id
}

output "aks_vnet_name" {
  description = "Name of the AKS Virtual Network"
  value       = azurerm_virtual_network.aks.name
}

output "cicd_vnet_id" {
  description = "ID of the CI/CD Virtual Network"
  value       = azurerm_virtual_network.cicd.id
}

output "cicd_vnet_name" {
  description = "Name of the CI/CD Virtual Network"
  value       = azurerm_virtual_network.cicd.name
}

# Hub subnet outputs
output "hub_firewall_subnet_id" {
  description = "ID of the Hub Firewall subnet"
  value       = azurerm_subnet.hub_firewall.id
}

output "hub_gateway_subnet_id" {
  description = "ID of the Hub Gateway subnet"
  value       = azurerm_subnet.hub_gateway.id
}

output "hub_bastion_subnet_id" {
  description = "ID of the Hub Bastion subnet"
  value       = azurerm_subnet.hub_bastion.id
}

output "hub_private_endpoints_subnet_id" {
  description = "ID of the Hub Private Endpoints subnet"
  value       = azurerm_subnet.hub_private_endpoints.id
}

# AKS subnet outputs
output "aks_system_pool_subnet_id" {
  description = "ID of the AKS System Pool subnet"
  value       = azurerm_subnet.aks_system_pool.id
}

output "aks_user_pool_subnet_id" {
  description = "ID of the AKS User Pool subnet"
  value       = azurerm_subnet.aks_user_pool.id
}

output "aks_private_link_subnet_id" {
  description = "ID of the AKS Private Link subnet"
  value       = azurerm_subnet.aks_private_link.id
}

# CI/CD subnet outputs
output "cicd_build_agents_subnet_id" {
  description = "ID of the CI/CD Build Agents subnet"
  value       = azurerm_subnet.cicd_build_agents.id
}

output "cicd_private_endpoints_subnet_id" {
  description = "ID of the CI/CD Private Endpoints subnet"
  value       = azurerm_subnet.cicd_private_endpoints.id
}

# DNS outputs
output "acr_private_dns_zone_id" {
  description = "ID of the ACR Private DNS Zone"
  value       = azurerm_private_dns_zone.acr.id
}

output "acr_private_dns_zone_name" {
  description = "Name of the ACR Private DNS Zone"
  value       = azurerm_private_dns_zone.acr.name
}