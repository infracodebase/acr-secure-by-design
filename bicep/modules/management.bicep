// Management module for Zero Trust ACR infrastructure
// Centralized logging, monitoring, and secrets management

@description('Azure region for resources')
param location string

@description('Naming prefix for resources')
param namingPrefix string

@description('Log Analytics retention in days')
param logRetentionDays int

@description('Common tags for all resources')
param commonTags object

@description('Hub VNet ID for private endpoint integration')
param hubVnetId string

@description('Private endpoints subnet ID')
param privateEndpointsSubnetId string

// Generate unique Key Vault name
var keyVaultName = '${replace(namingPrefix, '-', '')}kv${uniqueString(resourceGroup().id)}'

// Log Analytics Workspace for centralized logging
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namingPrefix}-logs'
  location: location
  tags: union(commonTags, {
    Service: 'Logging'
  })
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 10
    }
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// Application Insights for application monitoring
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${namingPrefix}-appinsights'
  location: location
  tags: union(commonTags, {
    Service: 'Monitoring'
  })
  kind: 'other'
  properties: {
    Application_Type: 'other'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// Key Vault for secrets management
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: union(commonTags, {
    Service: 'KeyVault'
    Purpose: 'ImageSigning'
  })
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'premium'
    }
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// Key Vault Private Endpoint
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${namingPrefix}-kv-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${namingPrefix}-kv-plsc'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// Key Vault Private DNS Zone
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: union(commonTags, {
    Service: 'DNS'
    Purpose: 'KeyVaultPrivateEndpoint'
  })
}

// Link Key Vault DNS zone to Hub VNet
resource keyVaultDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: 'kv-hub-link'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

// Key Vault Private DNS Zone Group
resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

// Log Analytics Private Endpoint
resource logAnalyticsPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${namingPrefix}-logs-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${namingPrefix}-logs-plsc'
        properties: {
          privateLinkServiceId: logAnalyticsWorkspace.id
          groupIds: [
            'azuremonitor'
          ]
        }
      }
    ]
  }
}

// Azure Monitor Private Link Scope for Log Analytics
resource monitorPrivateLinkScope 'Microsoft.Insights/privateLinkScopes@2021-07-01-preview' = {
  name: '${namingPrefix}-monitor-pls'
  location: 'global'
  tags: commonTags
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'PrivateOnly'
    }
  }
}

// Connect Log Analytics to Private Link Scope
resource logAnalyticsScopedResource 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  parent: monitorPrivateLinkScope
  name: 'logs-scoped-resource'
  properties: {
    linkedResourceId: logAnalyticsWorkspace.id
  }
}

// Connect Application Insights to Private Link Scope
resource appInsightsScopedResource 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  parent: monitorPrivateLinkScope
  name: 'appinsights-scoped-resource'
  properties: {
    linkedResourceId: applicationInsights.id
  }
}

// Diagnostic Settings for Key Vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: 'kv-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// Customer Managed Key for encryption
resource encryptionKey 'Microsoft.KeyVault/vaults/keys@2023-02-01' = {
  parent: keyVault
  name: 'acr-encryption-key'
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'encrypt'
      'decrypt'
      'wrapKey'
      'unwrapKey'
    ]
    attributes: {
      enabled: true
      exportable: false
    }
  }
}

// Outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output applicationInsightsId string = applicationInsights.id
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output encryptionKeyId string = encryptionKey.id
output monitorPrivateLinkScopeId string = monitorPrivateLinkScope.id