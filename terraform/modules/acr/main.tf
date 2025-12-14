# ACR Module using Azure Verified Module (AVM)
# Zero Trust Azure Container Registry with comprehensive security

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

# Generate unique ACR name (globally unique requirement)
locals {
  acr_name = replace("${var.naming_prefix}acr${random_string.acr_suffix.result}", "-", "")
}

resource "random_string" "acr_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Azure Verified Module for Container Registry
module "acr" {
  source  = "Azure/avm-res-containerregistry-registry/azurerm"
  version = "0.5.0"

  # Basic configuration
  name                = local.acr_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Premium" # Premium required for security features

  # Security configuration - OWASP compliant
  public_network_access_enabled = false # Zero Trust: no public access
  admin_enabled                 = false # OWASP: avoid default credentials
  export_policy_enabled         = false # Prevent unauthorized export
  zone_redundancy_enabled       = var.enable_zone_redundancy

  # Content trust and security policies
  enable_trust_policy       = true  # OWASP: secure content verification
  quarantine_policy_enabled = true  # OWASP: prevent malicious content
  retention_policy_in_days  = var.retention_days_untagged

  # Network security
  network_rule_set = {
    default_action = "Deny"
    ip_rule        = [] # No public IP access for Zero Trust
  }
  network_rule_bypass_option = "AzureServices"

  # Data endpoint for performance
  data_endpoint_enabled = true

  # Customer-managed encryption
  customer_managed_key = var.cmk_enabled ? {
    key_vault_resource_id = var.key_vault_id
    key_name              = "acr-encryption-key"
    user_assigned_identity = {
      resource_id = azurerm_user_assigned_identity.acr_identity.id
    }
  } : null

  # Managed identity for secure operations
  managed_identities = {
    system_assigned = true
    user_assigned_resource_ids = var.cmk_enabled ? [
      azurerm_user_assigned_identity.acr_identity.id
    ] : []
  }

  # Geo-replication for high availability
  georeplications = [
    for location in var.geo_replication_locations : {
      location                  = location
      regional_endpoint_enabled = true
      zone_redundancy_enabled   = true
    }
  ]

  # Private endpoint configuration
  private_endpoints = {
    primary = {
      name                          = "${var.naming_prefix}-acr-pe"
      subnet_resource_id            = var.hub_private_endpoints_subnet_id
      private_dns_zone_resource_ids = [var.acr_private_dns_zone_id]

      # Network interface configuration
      network_interface_name = "${var.naming_prefix}-acr-pe-nic"

      tags = var.common_tags
    }
  }

  # Comprehensive diagnostic settings for audit compliance
  diagnostic_settings = {
    audit = {
      name                       = "acr-audit-diagnostics"
      workspace_resource_id      = var.log_analytics_workspace_id
      log_categories             = []
      log_groups                = ["audit", "allLogs"]
      metric_categories         = ["AllMetrics"]
      log_analytics_destination_type = "Dedicated"
    }
  }

  # Scope maps for fine-grained access control - OWASP: secure access management
  scope_maps = {
    readonly = {
      name        = "readonly-scope"
      description = "Read-only access for monitoring and compliance"
      actions = [
        "repositories/*/content/read",
        "repositories/*/metadata/read"
      ]
    }

    cicd_build = {
      name        = "cicd-build-scope"
      description = "CI/CD pipeline access for secure image building"
      actions = [
        "repositories/*/content/read",
        "repositories/*/content/write",
        "repositories/*/metadata/read",
        "repositories/*/metadata/write"
      ]

      registry_tokens = {
        cicd_token = {
          name    = "cicd-secure-token"
          enabled = true
          passwords = {
            password1 = {
              expiry = timeadd(timestamp(), "2160h") # 90 days
            }
          }
        }
      }
    }

    production_deploy = {
      name        = "production-deploy-scope"
      description = "Production deployment access with pull-only permissions"
      actions = [
        "repositories/*/content/read",
        "repositories/*/metadata/read"
      ]
    }
  }

  # Role assignments for secure access - OWASP: principle of least privilege
  role_assignments = {
    acr_pull_aks = {
      role_definition_id_or_name = "AcrPull"
      principal_id               = var.aks_kubelet_identity_object_id
      description               = "AKS kubelet identity pull access"
      principal_type            = "ServicePrincipal"
    }
  }

  # Tags
  tags = merge(var.common_tags, {
    Service     = "ContainerRegistry"
    Purpose     = "ZeroTrust"
    Compliance  = "OWASP-Top10"
    SecurityLevel = "High"
  })
}

# User-assigned identity for CMK encryption
resource "azurerm_user_assigned_identity" "acr_identity" {
  count = var.cmk_enabled ? 1 : 0

  name                = "${var.naming_prefix}-acr-identity"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.common_tags
}

# Key Vault access policy for ACR identity (CMK)
resource "azurerm_key_vault_access_policy" "acr_identity" {
  count = var.cmk_enabled ? 1 : 0

  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.acr_identity[0].principal_id

  key_permissions = [
    "Get",
    "UnwrapKey",
    "WrapKey"
  ]
}

# ACR webhook for security event notifications
resource "azurerm_container_registry_webhook" "security_webhook" {
  name                = "${var.naming_prefix}-security-webhook"
  resource_group_name = var.resource_group_name
  registry_name       = module.acr.resource.name
  location            = var.location

  service_uri = var.security_webhook_url
  status      = "enabled"
  scope       = "*"

  actions = [
    "push",
    "delete",
    "quarantine"
  ]

  custom_headers = {
    "X-ACR-Source" = "zero-trust-acr"
    "X-Security-Level" = "high"
  }

  tags = var.common_tags
}

# Additional security: ACR task for vulnerability scanning
resource "azurerm_container_registry_task" "vulnerability_scan" {
  name                  = "vulnerability-scan-task"
  container_registry_id = module.acr.resource_id

  platform {
    os           = "Linux"
    architecture = "amd64"
  }

  docker_step {
    dockerfile_path      = "Dockerfile.scan"
    context_path        = "https://github.com/Azure/container-scan"
    context_access_token = var.github_token
    image_names         = ["{{.Run.Registry}}/security/vulnerability-scanner:{{.Run.ID}}"]
  }

  base_image_trigger {
    name                        = "defaultBaseimageTriggerName"
    type                       = "Runtime"
    update_trigger_endpoint    = var.scan_trigger_endpoint
    update_trigger_payload_type = "Token"
    status                     = "Enabled"
  }

  tags = merge(var.common_tags, {
    Purpose = "SecurityScanning"
  })
}