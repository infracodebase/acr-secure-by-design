// Network module for Zero Trust ACR infrastructure
// Hub-spoke topology with micro-segmentation

@description('Azure region for resources')
param location string

@description('Naming prefix for resources')
param namingPrefix string

@description('Network configuration object')
param networkConfig object

@description('Common tags for all resources')
param commonTags object

// Hub Virtual Network
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${namingPrefix}-hub-vnet'
  location: location
  tags: union(commonTags, {
    Service: 'Network'
    Type: 'Hub'
  })
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkConfig.hubVnetCidr
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

// Hub Subnets
resource hubFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: hubVnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: networkConfig.subnets.hubFirewall
    serviceEndpoints: []
  }
}

resource hubGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: hubVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: networkConfig.subnets.hubGateway
    serviceEndpoints: []
  }
  dependsOn: [hubFirewallSubnet]
}

resource hubBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: hubVnet
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: networkConfig.subnets.hubBastion
    serviceEndpoints: []
  }
  dependsOn: [hubGatewaySubnet]
}

resource hubPrivateEndpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: hubVnet
  name: 'private-endpoints-subnet'
  properties: {
    addressPrefix: networkConfig.subnets.hubPrivateEndpoints
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    serviceEndpoints: []
  }
  dependsOn: [hubBastionSubnet]
}

// AKS Virtual Network
resource aksVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${namingPrefix}-aks-vnet'
  location: location
  tags: union(commonTags, {
    Service: 'Network'
    Type: 'AKSSpoke'
  })
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkConfig.aksVnetCidr
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

// AKS Subnets
resource aksSystemPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: aksVnet
  name: 'aks-system-pool-subnet'
  properties: {
    addressPrefix: networkConfig.subnets.aksSystemPool
    serviceEndpoints: [
      {
        service: 'Microsoft.ContainerRegistry'
        locations: ['*']
      }
      {
        service: 'Microsoft.KeyVault'
        locations: ['*']
      }
    ]
  }
}

resource aksUserPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: aksVnet
  name: 'aks-user-pool-subnet'
  properties: {
    addressPrefix: networkConfig.subnets.aksUserPool
    serviceEndpoints: [
      {
        service: 'Microsoft.ContainerRegistry'
        locations: ['*']
      }
      {
        service: 'Microsoft.Storage'
        locations: ['*']
      }
    ]
  }
  dependsOn: [aksSystemPoolSubnet]
}

resource aksPrivateLinkSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: aksVnet
  name: 'aks-private-link-subnet'
  properties: {
    addressPrefix: networkConfig.subnets.aksPrivateLink
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    serviceEndpoints: []
  }
  dependsOn: [aksUserPoolSubnet]
}

// CI/CD Virtual Network
resource cicdVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${namingPrefix}-cicd-vnet'
  location: location
  tags: union(commonTags, {
    Service: 'Network'
    Type: 'CICDSpoke'
  })
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkConfig.cicdVnetCidr
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

// CI/CD Subnets
resource cicdBuildAgentsSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: cicdVnet
  name: 'build-agents-subnet'
  properties: {
    addressPrefix: networkConfig.subnets.cicdBuildAgents
    serviceEndpoints: [
      {
        service: 'Microsoft.ContainerRegistry'
        locations: ['*']
      }
      {
        service: 'Microsoft.KeyVault'
        locations: ['*']
      }
    ]
  }
}

resource cicdPrivateEndpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: cicdVnet
  name: 'cicd-private-endpoints-subnet'
  properties: {
    addressPrefix: networkConfig.subnets.cicdPrivateEndpoints
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    serviceEndpoints: []
  }
  dependsOn: [cicdBuildAgentsSubnet]
}

// VNet Peering: Hub to AKS
resource hubToAksPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: hubVnet
  name: 'hub-to-aks-peering'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: aksVnet.id
    }
  }
}

resource aksToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: aksVnet
  name: 'aks-to-hub-peering'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
}

// VNet Peering: Hub to CI/CD
resource hubToCicdPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: hubVnet
  name: 'hub-to-cicd-peering'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: cicdVnet.id
    }
  }
}

resource cicdToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: cicdVnet
  name: 'cicd-to-hub-peering'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
}

// Private DNS Zone for ACR
resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: union(commonTags, {
    Service: 'DNS'
    Purpose: 'ACRPrivateEndpoint'
  })
}

// Link DNS zone to VNets
resource acrDnsZoneHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: 'acr-hub-link'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource acrDnsZoneAksLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: 'acr-aks-link'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: aksVnet.id
    }
  }
}

resource acrDnsZoneCicdLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: 'acr-cicd-link'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: cicdVnet.id
    }
  }
}

// Outputs
output hubVnetId string = hubVnet.id
output aksVnetId string = aksVnet.id
output cicdVnetId string = cicdVnet.id

output hubPrivateEndpointsSubnetId string = hubPrivateEndpointsSubnet.id
output aksSystemPoolSubnetId string = aksSystemPoolSubnet.id
output aksUserPoolSubnetId string = aksUserPoolSubnet.id
output aksPrivateLinkSubnetId string = aksPrivateLinkSubnet.id
output cicdBuildAgentsSubnetId string = cicdBuildAgentsSubnet.id
output cicdPrivateEndpointsSubnetId string = cicdPrivateEndpointsSubnet.id

output acrPrivateDnsZoneId string = acrPrivateDnsZone.id