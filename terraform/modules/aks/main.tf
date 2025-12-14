# AKS Module using Azure Verified Module (AVM)
# Zero Trust Azure Kubernetes Service with comprehensive security

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.56"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Azure Verified Module for Production AKS Pattern
module "aks_production" {
  source  = "Azure/avm-ptn-aks-production/azurerm"
  version = "0.5.0"

  # Basic configuration
  name                = "${var.naming_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Kubernetes configuration
  kubernetes_version = var.kubernetes_version

  # Network configuration for Zero Trust
  network = {
    node_subnet_id = var.system_pool_subnet_id
    pod_cidr       = var.pod_cidr
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  # Private cluster configuration - OWASP: secure network access
  private_dns_zone_id         = var.private_dns_zone_id
  private_dns_zone_id_enabled = true

  # Network policy for Zero Trust micro-segmentation
  network_policy = var.enable_network_policy

  # Outbound traffic control
  outbound_type = var.outbound_type

  # ACR integration with private endpoint
  acr = var.acr_id != "" ? {
    name                          = split("/", var.acr_id)[8] # Extract ACR name from resource ID
    subnet_resource_id            = var.private_link_subnet_id
    private_dns_zone_resource_ids = [var.acr_private_dns_zone_id]
    zone_redundancy_enabled       = var.enable_zone_redundancy
  } : null

  # Managed identity configuration
  managed_identities = {
    user_assigned_resource_ids = var.user_assigned_identity_ids
  }

  # Azure AD integration - OWASP: secure authentication
  rbac_aad_azure_rbac_enabled     = var.enable_azure_rbac
  rbac_aad_tenant_id              = var.aad_tenant_id
  rbac_aad_admin_group_object_ids = var.aad_admin_group_object_ids

  # Default node pool configuration
  default_node_pool_vm_sku = var.node_vm_size
  os_sku                   = var.os_sku
  os_disk_type            = var.os_disk_type

  # Additional node pools for workload separation
  node_pools = {
    # User workload pool
    user_pool = {
      name                 = "userpool"
      vm_size              = var.node_vm_size
      orchestrator_version = var.kubernetes_version
      max_count           = var.user_node_count_max
      min_count           = var.user_node_count_min
      os_sku              = var.os_sku
      os_disk_type        = var.os_disk_type
      mode                = "User"
      labels = merge(var.node_labels, {
        "nodepool-type" = "user"
        "workload"      = "general"
      })
      tags = merge(var.common_tags, {
        NodePool = "User"
        Purpose  = "WorkloadNodes"
      })
    }

    # GPU pool for ML workloads (if enabled)
    gpu_pool = var.enable_gpu_nodes ? {
      name                 = "gpupool"
      vm_size              = var.gpu_vm_size
      orchestrator_version = var.kubernetes_version
      max_count           = var.gpu_node_count_max
      min_count           = var.gpu_node_count_min
      os_sku              = var.os_sku
      os_disk_type        = var.os_disk_type
      mode                = "User"
      labels = merge(var.node_labels, {
        "nodepool-type"    = "gpu"
        "workload"         = "ml"
        "accelerator"      = "nvidia-gpu"
      })
      tags = merge(var.common_tags, {
        NodePool = "GPU"
        Purpose  = "MLWorkloads"
      })
    } : null
  }

  # Prometheus monitoring configuration
  monitor_metrics = var.enable_prometheus ? {
    annotations_allowed = "prometheus.io/scrape,prometheus.io/port,prometheus.io/path"
    labels_allowed      = "app.kubernetes.io/name,app.kubernetes.io/instance"
  } : null

  # Security tags
  tags = merge(var.common_tags, {
    Service       = "Kubernetes"
    Purpose       = "ZeroTrust"
    Compliance    = "OWASP-Top10"
    SecurityLevel = "High"
    NetworkPolicy = var.enable_network_policy
    PrivateCluster = "true"
  })
}

# Additional security configurations not covered by the AVM pattern

# User-assigned identity for AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "${var.naming_prefix}-aks-identity"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.common_tags
}

# Key Vault secrets provider addon configuration
resource "azurerm_kubernetes_cluster_extension" "secrets_provider" {
  count = var.enable_secret_store_csi ? 1 : 0

  name           = "secrets-store-csi"
  cluster_id     = module.aks_production.resource_id
  extension_type = "Microsoft.AzureKeyVaultSecretsProvider"

  configuration_settings = {
    "secrets-store-csi-driver.enableSecretRotation" = "true"
    "secrets-store-csi-driver.rotationPollInterval" = "2h"
  }

  tags = var.common_tags
}

# Azure Policy addon for compliance
resource "azurerm_kubernetes_cluster_extension" "azure_policy" {
  count = var.enable_azure_policy ? 1 : 0

  name           = "azure-policy"
  cluster_id     = module.aks_production.resource_id
  extension_type = "Microsoft.PolicyInsights"

  configuration_settings = {
    "auditInterval"     = "60"
    "constraintViolationsLimit" = "20"
  }

  tags = var.common_tags
}

# Microsoft Defender for Containers
resource "azurerm_kubernetes_cluster_extension" "defender" {
  count = var.enable_defender_for_containers ? 1 : 0

  name           = "microsoft-defender-for-cloud"
  cluster_id     = module.aks_production.resource_id
  extension_type = "Microsoft.AzureDefender.Kubernetes"

  configuration_settings = {
    "logAnalyticsWorkspaceResourceID" = var.log_analytics_workspace_id
  }

  tags = var.common_tags
}

# Diagnostic settings for comprehensive audit logging - OWASP compliance
resource "azurerm_monitor_diagnostic_setting" "aks_diagnostics" {
  name                       = "${var.naming_prefix}-aks-diagnostics"
  target_resource_id         = module.aks_production.resource_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Kubernetes audit logs
  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  # Kubernetes API server logs
  enabled_log {
    category = "kube-apiserver"
  }

  # Kubernetes controller manager logs
  enabled_log {
    category = "kube-controller-manager"
  }

  # Kubernetes scheduler logs
  enabled_log {
    category = "kube-scheduler"
  }

  # Cluster autoscaler logs
  enabled_log {
    category = "cluster-autoscaler"
  }

  # Azure Policy addon logs
  enabled_log {
    category = "guard"
  }

  # Cloud controller manager logs
  enabled_log {
    category = "cloud-controller-manager"
  }

  # CSI driver logs
  enabled_log {
    category = "csi-azuredisk-controller"
  }

  enabled_log {
    category = "csi-azurefile-controller"
  }

  enabled_log {
    category = "csi-snapshot-controller"
  }

  # Metrics
  metric {
    category = "AllMetrics"
  }

  lifecycle {
    ignore_changes = [
      log_analytics_destination_type
    ]
  }
}

# Network Security Group rules for additional security
resource "azurerm_network_security_group" "aks_nsg" {
  name                = "${var.naming_prefix}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Deny all inbound traffic by default (Zero Trust)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow internal cluster communication
  security_rule {
    name                       = "AllowClusterInternal"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.pod_cidr
    destination_address_prefix = var.pod_cidr
  }

  # Allow Azure Load Balancer
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Purpose = "AKSNetworkSecurity"
  })
}

# Associate NSG with AKS subnet
resource "azurerm_subnet_network_security_group_association" "aks_system_nsg" {
  subnet_id                 = var.system_pool_subnet_id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "aks_user_nsg" {
  subnet_id                 = var.user_pool_subnet_id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}