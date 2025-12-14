# Zero Trust Azure Container Registry Infrastructure
# Modular Terraform implementation using best practices

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.56"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend can be configured with backend.conf file
  # For local development, comment out backend block
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {}

# Local variables for naming and tagging
locals {
  environment = var.environment
  location    = var.location

  # Naming convention: [company]-[environment]-[service]-[region]
  naming_prefix = "${var.company_prefix}-${local.environment}"

  # Common tags for all resources
  common_tags = {
    Environment    = local.environment
    Project        = "Zero-Trust-ACR"
    Owner          = var.owner
    CostCenter     = var.cost_center
    ManagedBy      = "Terraform"
    LastModified   = timestamp()
    Compliance     = "ISO27001,SOC2,DORA"
    Classification = "Internal"
  }
}

# Data sources for existing Azure resources
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Resource Groups
resource "azurerm_resource_group" "management" {
  name     = "${local.naming_prefix}-management-rg"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "network" {
  name     = "${local.naming_prefix}-network-rg"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "acr" {
  name     = "${local.naming_prefix}-acr-rg"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "aks" {
  name     = "${local.naming_prefix}-aks-rg"
  location = local.location
  tags     = local.common_tags
}

# Network Module
module "network" {
  source = "./modules/network"

  location                    = local.location
  naming_prefix               = local.naming_prefix
  network_resource_group_name = azurerm_resource_group.network.name
  common_tags                 = local.common_tags

  # VNet CIDR blocks
  hub_vnet_cidr  = var.hub_vnet_cidr
  aks_vnet_cidr  = var.aks_vnet_cidr
  cicd_vnet_cidr = var.cicd_vnet_cidr

  # Subnet configurations can be customized via variables
  hub_firewall_subnet          = var.hub_firewall_subnet
  hub_gateway_subnet           = var.hub_gateway_subnet
  hub_bastion_subnet           = var.hub_bastion_subnet
  hub_private_endpoints_subnet = var.hub_private_endpoints_subnet

  aks_system_pool_subnet   = var.aks_system_pool_subnet
  aks_user_pool_subnet     = var.aks_user_pool_subnet
  aks_gpu_pool_subnet      = var.aks_gpu_pool_subnet
  aks_private_link_subnet  = var.aks_private_link_subnet
  aks_virtual_nodes_subnet = var.aks_virtual_nodes_subnet

  cicd_build_agents_subnet      = var.cicd_build_agents_subnet
  cicd_private_endpoints_subnet = var.cicd_private_endpoints_subnet
}

# Management Module
module "management" {
  source = "./modules/management"

  location            = local.location
  naming_prefix       = local.naming_prefix
  resource_group_name = azurerm_resource_group.management.name
  common_tags         = local.common_tags

  log_retention_days              = var.log_retention_days
  hub_vnet_id                     = module.network.hub_vnet_id
  hub_private_endpoints_subnet_id = module.network.hub_private_endpoints_subnet_id
}

# ACR Module
module "acr" {
  source = "./modules/acr"

  location            = local.location
  naming_prefix       = local.naming_prefix
  resource_group_name = azurerm_resource_group.acr.name
  common_tags         = local.common_tags

  log_analytics_workspace_id      = module.management.log_analytics_workspace_id
  key_vault_id                    = module.management.key_vault_id
  hub_private_endpoints_subnet_id = module.network.hub_private_endpoints_subnet_id
  acr_private_dns_zone_id         = module.network.acr_private_dns_zone_id

  # ACR configuration
  retention_days_untagged   = var.retention_days_untagged
  enable_zone_redundancy    = var.enable_zone_redundancy
  geo_replication_locations = var.geo_replication_locations
  cmk_enabled               = var.cmk_enabled
}

# AKS Module
module "aks" {
  source = "./modules/aks"

  location            = local.location
  naming_prefix       = local.naming_prefix
  resource_group_name = azurerm_resource_group.aks.name
  common_tags         = local.common_tags

  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  acr_id                     = module.acr.acr_id

  # Network configuration
  system_pool_subnet_id     = module.network.aks_system_pool_subnet_id
  user_pool_subnet_id       = module.network.aks_user_pool_subnet_id
  private_link_subnet_id    = module.network.aks_private_link_subnet_id
  acr_private_dns_zone_id   = module.network.acr_private_dns_zone_id
  private_dns_zone_id       = ""

  # AKS configuration
  kubernetes_version    = var.kubernetes_version
  system_node_count     = var.system_node_count
  user_node_count_min   = var.user_node_count_min
  user_node_count_max   = var.user_node_count_max
  node_vm_size          = var.node_vm_size
  enable_auto_scaling   = var.enable_auto_scaling
  enable_network_policy = var.enable_network_policy

  # Security features
  enable_azure_policy            = var.enable_azure_policy
  enable_secret_store_csi        = var.enable_secret_store_csi
  enable_workload_identity       = var.enable_workload_identity
  enable_oidc_issuer             = var.enable_oidc_issuer
  enable_defender_for_containers = var.enable_defender_for_containers
  enable_image_cleaner           = var.enable_image_cleaner
  enable_gpu_nodes               = var.enable_gpu_nodes

  # Monitoring
  enable_container_insights = var.enable_container_insights
  enable_prometheus         = var.enable_prometheus

  # Identity
  aad_admin_group_object_ids = var.aad_admin_group_object_id != "" ? [var.aad_admin_group_object_id] : []
  aad_tenant_id              = var.aad_tenant_id

  # Advanced configuration
  max_pods_per_node  = var.max_pods_per_node
  load_balancer_sku  = var.load_balancer_sku
  outbound_type      = var.outbound_type
  maintenance_window = var.maintenance_window
}