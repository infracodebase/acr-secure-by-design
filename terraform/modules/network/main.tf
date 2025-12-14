# Network Module for Zero Trust ACR Infrastructure
# Hub-spoke topology with micro-segmentation

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.56"
    }
  }
}

locals {
  # Subnet configurations
  subnets = {
    # Hub VNet subnets
    hub_firewall          = var.hub_firewall_subnet
    hub_gateway           = var.hub_gateway_subnet
    hub_bastion           = var.hub_bastion_subnet
    hub_private_endpoints = var.hub_private_endpoints_subnet

    # AKS VNet subnets
    aks_system_pool   = var.aks_system_pool_subnet
    aks_user_pool     = var.aks_user_pool_subnet
    aks_gpu_pool      = var.aks_gpu_pool_subnet
    aks_private_link  = var.aks_private_link_subnet
    aks_virtual_nodes = var.aks_virtual_nodes_subnet

    # CI/CD VNet subnets
    cicd_build_agents       = var.cicd_build_agents_subnet
    cicd_private_endpoints  = var.cicd_private_endpoints_subnet
  }
}

# Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "${var.naming_prefix}-hub-vnet"
  address_space       = [var.hub_vnet_cidr]
  location            = var.location
  resource_group_name = var.network_resource_group_name

  tags = merge(var.common_tags, {
    Service = "Network"
    Type    = "Hub"
  })
}

# Hub subnets
resource "azurerm_subnet" "hub_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.subnets.hub_firewall]
}

resource "azurerm_subnet" "hub_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.subnets.hub_gateway]
}

resource "azurerm_subnet" "hub_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.subnets.hub_bastion]
}

resource "azurerm_subnet" "hub_private_endpoints" {
  name                 = "private-endpoints-subnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.subnets.hub_private_endpoints]

  private_endpoint_network_policies_enabled = false
}

# AKS Virtual Network
resource "azurerm_virtual_network" "aks" {
  name                = "${var.naming_prefix}-aks-vnet"
  address_space       = [var.aks_vnet_cidr]
  location            = var.location
  resource_group_name = var.network_resource_group_name

  tags = merge(var.common_tags, {
    Service = "Network"
    Type    = "AKSSpoke"
  })
}

# AKS subnets
resource "azurerm_subnet" "aks_system_pool" {
  name                 = "aks-system-pool-subnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [local.subnets.aks_system_pool]
}

resource "azurerm_subnet" "aks_user_pool" {
  name                 = "aks-user-pool-subnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [local.subnets.aks_user_pool]
}

resource "azurerm_subnet" "aks_private_link" {
  name                 = "aks-private-link-subnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [local.subnets.aks_private_link]

  private_endpoint_network_policies_enabled = false
}

resource "azurerm_subnet" "aks_gpu_pool" {
  count = var.aks_gpu_pool_subnet != "" ? 1 : 0

  name                 = "aks-gpu-pool-subnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [local.subnets.aks_gpu_pool]
}

resource "azurerm_subnet" "aks_virtual_nodes" {
  count = var.aks_virtual_nodes_subnet != "" ? 1 : 0

  name                 = "aks-virtual-nodes-subnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [local.subnets.aks_virtual_nodes]

  delegation {
    name = "aciDelegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# CI/CD Virtual Network
resource "azurerm_virtual_network" "cicd" {
  name                = "${var.naming_prefix}-cicd-vnet"
  address_space       = [var.cicd_vnet_cidr]
  location            = var.location
  resource_group_name = var.network_resource_group_name

  tags = merge(var.common_tags, {
    Service = "Network"
    Type    = "CICDSpoke"
  })
}

# CI/CD subnets
resource "azurerm_subnet" "cicd_build_agents" {
  name                 = "build-agents-subnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.cicd.name
  address_prefixes     = [local.subnets.cicd_build_agents]
}

resource "azurerm_subnet" "cicd_private_endpoints" {
  name                 = "cicd-private-endpoints-subnet"
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = azurerm_virtual_network.cicd.name
  address_prefixes     = [local.subnets.cicd_private_endpoints]

  private_endpoint_network_policies_enabled = false
}

# VNet Peering: Hub to AKS
resource "azurerm_virtual_network_peering" "hub_to_aks" {
  name                      = "hub-to-aks-peering"
  resource_group_name       = var.network_resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.aks.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "aks_to_hub" {
  name                      = "aks-to-hub-peering"
  resource_group_name       = var.network_resource_group_name
  virtual_network_name      = azurerm_virtual_network.aks.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# VNet Peering: Hub to CI/CD
resource "azurerm_virtual_network_peering" "hub_to_cicd" {
  name                      = "hub-to-cicd-peering"
  resource_group_name       = var.network_resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.cicd.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "cicd_to_hub" {
  name                      = "cicd-to-hub-peering"
  resource_group_name       = var.network_resource_group_name
  virtual_network_name      = azurerm_virtual_network.cicd.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Private DNS Zone for ACR
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.network_resource_group_name

  tags = merge(var.common_tags, {
    Service = "DNS"
    Purpose = "ACRPrivateEndpoint"
  })
}

# Link DNS zone to VNets
resource "azurerm_private_dns_zone_virtual_network_link" "acr_hub" {
  name                  = "acr-hub-link"
  resource_group_name   = var.network_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false

  tags = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_aks" {
  name                  = "acr-aks-link"
  resource_group_name   = var.network_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.aks.id
  registration_enabled  = false

  tags = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_cicd" {
  name                  = "acr-cicd-link"
  resource_group_name   = var.network_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.cicd.id
  registration_enabled  = false

  tags = var.common_tags
}

# Network Security Groups for Zero Trust compliance

# NSG for Hub Private Endpoints subnet
resource "azurerm_network_security_group" "hub_private_endpoints" {
  name                = "${var.naming_prefix}-hub-pe-nsg"
  location            = var.location
  resource_group_name = var.network_resource_group_name

  # Allow inbound HTTPS from peered VNets
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = [var.hub_vnet_cidr, var.aks_vnet_cidr, var.cicd_vnet_cidr]
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Service = "Network"
    Purpose = "HubPrivateEndpointsNSG"
  })
}

# Associate NSG with Hub Private Endpoints subnet
resource "azurerm_subnet_network_security_group_association" "hub_private_endpoints" {
  subnet_id                 = azurerm_subnet.hub_private_endpoints.id
  network_security_group_id = azurerm_network_security_group.hub_private_endpoints.id
}

# NSG for AKS System Pool subnet
resource "azurerm_network_security_group" "aks_system_pool" {
  name                = "${var.naming_prefix}-aks-system-nsg"
  location            = var.location
  resource_group_name = var.network_resource_group_name

  # Allow required AKS communication
  security_rule {
    name                       = "AllowAKSNodeCommunication"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = [var.aks_vnet_cidr]
    destination_address_prefix = "*"
  }

  # Allow load balancer probes
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Service = "Network"
    Purpose = "AKSSystemPoolNSG"
  })
}

# Associate NSG with AKS System Pool subnet
resource "azurerm_subnet_network_security_group_association" "aks_system_pool" {
  subnet_id                 = azurerm_subnet.aks_system_pool.id
  network_security_group_id = azurerm_network_security_group.aks_system_pool.id
}

# NSG for AKS User Pool subnet
resource "azurerm_network_security_group" "aks_user_pool" {
  name                = "${var.naming_prefix}-aks-user-nsg"
  location            = var.location
  resource_group_name = var.network_resource_group_name

  # Allow required AKS communication
  security_rule {
    name                       = "AllowAKSNodeCommunication"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = [var.aks_vnet_cidr]
    destination_address_prefix = "*"
  }

  # Allow load balancer probes
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Allow application traffic from Hub VNet
  security_rule {
    name                       = "AllowAppTrafficFromHub"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "8080", "8443"]
    source_address_prefix      = var.hub_vnet_cidr
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Service = "Network"
    Purpose = "AKSUserPoolNSG"
  })
}

# Associate NSG with AKS User Pool subnet
resource "azurerm_subnet_network_security_group_association" "aks_user_pool" {
  subnet_id                 = azurerm_subnet.aks_user_pool.id
  network_security_group_id = azurerm_network_security_group.aks_user_pool.id
}

# NSG for AKS Private Link subnet
resource "azurerm_network_security_group" "aks_private_link" {
  name                = "${var.naming_prefix}-aks-pl-nsg"
  location            = var.location
  resource_group_name = var.network_resource_group_name

  # Allow HTTPS from AKS subnets
  security_rule {
    name                       = "AllowHTTPSFromAKS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = [local.subnets.aks_system_pool, local.subnets.aks_user_pool]
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Service = "Network"
    Purpose = "AKSPrivateLinkNSG"
  })
}

# Associate NSG with AKS Private Link subnet
resource "azurerm_subnet_network_security_group_association" "aks_private_link" {
  subnet_id                 = azurerm_subnet.aks_private_link.id
  network_security_group_id = azurerm_network_security_group.aks_private_link.id
}

# NSG for CI/CD Build Agents subnet
resource "azurerm_network_security_group" "cicd_build_agents" {
  name                = "${var.naming_prefix}-cicd-build-nsg"
  location            = var.location
  resource_group_name = var.network_resource_group_name

  # Allow SSH for management (restricted to Hub VNet)
  security_rule {
    name                       = "AllowSSHFromHub"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.hub_vnet_cidr
    destination_address_prefix = "*"
  }

  # Allow RDP for management (restricted to Hub VNet)
  security_rule {
    name                       = "AllowRDPFromHub"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.hub_vnet_cidr
    destination_address_prefix = "*"
  }

  # Allow build agent communication
  security_rule {
    name                       = "AllowBuildAgentCommunication"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "9090"]
    source_address_prefix      = var.cicd_vnet_cidr
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Service = "Network"
    Purpose = "CICDBuildAgentsNSG"
  })
}

# Associate NSG with CI/CD Build Agents subnet
resource "azurerm_subnet_network_security_group_association" "cicd_build_agents" {
  subnet_id                 = azurerm_subnet.cicd_build_agents.id
  network_security_group_id = azurerm_network_security_group.cicd_build_agents.id
}

# NSG for CI/CD Private Endpoints subnet
resource "azurerm_network_security_group" "cicd_private_endpoints" {
  name                = "${var.naming_prefix}-cicd-pe-nsg"
  location            = var.location
  resource_group_name = var.network_resource_group_name

  # Allow HTTPS from CI/CD build agents
  security_rule {
    name                       = "AllowHTTPSFromBuildAgents"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = local.subnets.cicd_build_agents
    destination_address_prefix = "*"
  }

  # Allow HTTPS from Hub VNet
  security_rule {
    name                       = "AllowHTTPSFromHub"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.hub_vnet_cidr
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Service = "Network"
    Purpose = "CICDPrivateEndpointsNSG"
  })
}

# Associate NSG with CI/CD Private Endpoints subnet
resource "azurerm_subnet_network_security_group_association" "cicd_private_endpoints" {
  subnet_id                 = azurerm_subnet.cicd_private_endpoints.id
  network_security_group_id = azurerm_network_security_group.cicd_private_endpoints.id
}

# NSG for AKS GPU Pool subnet (conditional)
resource "azurerm_network_security_group" "aks_gpu_pool" {
  count = var.aks_gpu_pool_subnet != "" ? 1 : 0

  name                = "${var.naming_prefix}-aks-gpu-nsg"
  location            = var.location
  resource_group_name = var.network_resource_group_name

  # Allow required AKS communication
  security_rule {
    name                       = "AllowAKSNodeCommunication"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = [var.aks_vnet_cidr]
    destination_address_prefix = "*"
  }

  # Allow load balancer probes
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Allow GPU workload ports
  security_rule {
    name                       = "AllowGPUWorkloads"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["2379", "2380", "6443", "10250", "10255"]
    source_address_prefixes    = [var.aks_vnet_cidr, var.hub_vnet_cidr]
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Service = "Network"
    Purpose = "AKSGPUPoolNSG"
  })
}

# Associate NSG with AKS GPU Pool subnet (conditional)
resource "azurerm_subnet_network_security_group_association" "aks_gpu_pool" {
  count = var.aks_gpu_pool_subnet != "" ? 1 : 0

  subnet_id                 = azurerm_subnet.aks_gpu_pool[0].id
  network_security_group_id = azurerm_network_security_group.aks_gpu_pool[0].id
}

# NSG for AKS Virtual Nodes subnet (conditional)
resource "azurerm_network_security_group" "aks_virtual_nodes" {
  count = var.aks_virtual_nodes_subnet != "" ? 1 : 0

  name                = "${var.naming_prefix}-aks-vn-nsg"
  location            = var.location
  resource_group_name = var.network_resource_group_name

  # Allow Azure Container Instances communication
  security_rule {
    name                       = "AllowACICommunication"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureContainerInstance"
    destination_address_prefix = "*"
  }

  # Allow AKS control plane communication
  security_rule {
    name                       = "AllowAKSControlPlane"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "6443", "10250"]
    source_address_prefixes    = [var.aks_vnet_cidr]
    destination_address_prefix = "*"
  }

  # Allow load balancer probes
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Service = "Network"
    Purpose = "AKSVirtualNodesNSG"
  })
}

# Associate NSG with AKS Virtual Nodes subnet (conditional)
resource "azurerm_subnet_network_security_group_association" "aks_virtual_nodes" {
  count = var.aks_virtual_nodes_subnet != "" ? 1 : 0

  subnet_id                 = azurerm_subnet.aks_virtual_nodes[0].id
  network_security_group_id = azurerm_network_security_group.aks_virtual_nodes[0].id
}