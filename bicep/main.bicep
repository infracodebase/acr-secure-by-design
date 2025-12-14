// Zero Trust Azure Container Registry Infrastructure
// Production-ready ACR with private endpoints and AKS integration
// Bicep version using latest Azure CLI features

targetScope = 'subscription'

@description('Environment name (dev, staging, prod)')
param environment string = 'prod'

@description('Azure region for resources')
param location string = 'eastus'

@description('Company prefix for naming')
param companyPrefix string = 'zt'

@description('Owner tag value')
param owner string = 'Infrastructure Team'

@description('Cost center tag value')
param costCenter string = 'IT-001'

@description('Log Analytics retention in days')
param logRetentionDays int = 90

// Variables for naming and configuration
var namingPrefix = '${companyPrefix}-${environment}'
var commonTags = {
  Environment: environment
  Project: 'Zero-Trust-ACR'
  Owner: owner
  CostCenter: costCenter
  ManagedBy: 'Bicep'
  LastModified: utcNow()
  Compliance: 'ISO27001,SOC2,DORA'
  Classification: 'Internal'
}

// Network configuration
var networkConfig = {
  hubVnetCidr: '10.0.0.0/16'
  aksVnetCidr: '10.1.0.0/16'
  cicdVnetCidr: '10.2.0.0/16'
  subnets: {
    hubFirewall: '10.0.1.0/24'
    hubGateway: '10.0.2.0/24'
    hubBastion: '10.0.3.0/24'
    hubPrivateEndpoints: '10.0.10.0/24'
    aksSystemPool: '10.1.1.0/24'
    aksUserPool: '10.1.2.0/24'
    aksPrivateLink: '10.1.10.0/24'
    cicdBuildAgents: '10.2.1.0/24'
    cicdPrivateEndpoints: '10.2.10.0/24'
  }
}

// Resource Groups
resource managementRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${namingPrefix}-management-rg'
  location: location
  tags: union(commonTags, {
    Service: 'Management'
  })
}

resource networkRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${namingPrefix}-network-rg'
  location: location
  tags: union(commonTags, {
    Service: 'Network'
  })
}

resource acrRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${namingPrefix}-acr-rg'
  location: location
  tags: union(commonTags, {
    Service: 'ContainerRegistry'
  })
}

resource aksRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${namingPrefix}-aks-rg'
  location: location
  tags: union(commonTags, {
    Service: 'Kubernetes'
  })
}

// Deploy network infrastructure
module network 'modules/network.bicep' = {
  name: 'network-deployment'
  scope: networkRg
  params: {
    location: location
    namingPrefix: namingPrefix
    networkConfig: networkConfig
    commonTags: commonTags
  }
}

// Deploy management infrastructure
module management 'modules/management.bicep' = {
  name: 'management-deployment'
  scope: managementRg
  params: {
    location: location
    namingPrefix: namingPrefix
    logRetentionDays: logRetentionDays
    commonTags: commonTags
    hubVnetId: network.outputs.hubVnetId
    privateEndpointsSubnetId: network.outputs.hubPrivateEndpointsSubnetId
  }
}

// Deploy ACR infrastructure
module acr 'modules/acr.bicep' = {
  name: 'acr-deployment'
  scope: acrRg
  params: {
    location: location
    namingPrefix: namingPrefix
    commonTags: commonTags
    logAnalyticsWorkspaceId: management.outputs.logAnalyticsWorkspaceId
    keyVaultId: management.outputs.keyVaultId
    privateEndpointsSubnetId: network.outputs.hubPrivateEndpointsSubnetId
    privateDnsZoneId: network.outputs.acrPrivateDnsZoneId
  }
}

// Deploy AKS infrastructure
module aks 'modules/aks.bicep' = {
  name: 'aks-deployment'
  scope: aksRg
  params: {
    location: location
    namingPrefix: namingPrefix
    commonTags: commonTags
    logAnalyticsWorkspaceId: management.outputs.logAnalyticsWorkspaceId
    acrId: acr.outputs.acrId
    systemPoolSubnetId: network.outputs.aksSystemPoolSubnetId
    userPoolSubnetId: network.outputs.aksUserPoolSubnetId
    privateLinkSubnetId: network.outputs.aksPrivateLinkSubnetId
  }
}

// Outputs
output resourceGroupIds object = {
  management: managementRg.id
  network: networkRg.id
  acr: acrRg.id
  aks: aksRg.id
}

output networkIds object = {
  hubVnetId: network.outputs.hubVnetId
  aksVnetId: network.outputs.aksVnetId
  cicdVnetId: network.outputs.cicdVnetId
}

output acrDetails object = {
  acrId: acr.outputs.acrId
  acrName: acr.outputs.acrName
  acrLoginServer: acr.outputs.acrLoginServer
}

output aksDetails object = {
  aksId: aks.outputs.aksId
  aksName: aks.outputs.aksName
  aksFqdn: aks.outputs.aksFqdn
}

output managementDetails object = {
  logAnalyticsWorkspaceId: management.outputs.logAnalyticsWorkspaceId
  keyVaultId: management.outputs.keyVaultId
  applicationInsightsId: management.outputs.applicationInsightsId
}