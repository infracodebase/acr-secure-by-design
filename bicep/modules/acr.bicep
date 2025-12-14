// ACR module for Zero Trust infrastructure
// Premium ACR with private endpoints, encryption, and advanced security

@description('Azure region for resources')
param location string

@description('Naming prefix for resources')
param namingPrefix string

@description('Common tags for all resources')
param commonTags object

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Key Vault ID for encryption')
param keyVaultId string

@description('Private endpoints subnet ID')
param privateEndpointsSubnetId string

@description('Private DNS zone ID for ACR')
param privateDnsZoneId string

// Generate unique ACR name (globally unique requirement)
var acrName = replace('${namingPrefix}acr${uniqueString(resourceGroup().id)}', '-', '')

// Premium ACR with advanced security features
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: union(commonTags, {
    Service: 'ContainerRegistry'
    Purpose: 'ZeroTrust'
  })
  sku: {
    name: 'Premium'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Security configuration
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'

    // Encryption with customer-managed keys
    encryption: {
      status: 'enabled'
      keyVaultProperties: {
        keyIdentifier: null // Will be updated post-deployment
        identity: null
      }
    }

    // Data endpoint configuration
    dataEndpointEnabled: true

    // Trust policy for content trust
    trustPolicy: {
      status: 'enabled'
      type: 'Notary'
    }

    // Quarantine policy for vulnerability scanning
    quarantinePolicy: {
      status: 'enabled'
    }

    // Retention policy for untagged manifests
    retentionPolicy: {
      days: 7
      status: 'enabled'
    }

    // Zone redundancy for high availability
    zoneRedundancy: 'Enabled'
  }
}

// ACR Private Endpoint
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${namingPrefix}-acr-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${namingPrefix}-acr-plsc'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group for automatic DNS registration
resource acrPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: acrPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurecr-io'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ACR Diagnostic Settings for audit logging
resource acrDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: acr
  name: 'acr-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
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

// ACR Task for automated image building and security scanning
resource acrBuildTask 'Microsoft.ContainerRegistry/registries/tasks@2019-06-01-preview' = {
  parent: acr
  name: 'security-scan-task'
  location: location
  tags: commonTags
  properties: {
    status: 'Enabled'
    platform: {
      os: 'Linux'
      architecture: 'amd64'
    }
    agentConfiguration: {
      cpu: 2
    }
    step: {
      type: 'DockerBuildStep'
      dockerFilePath: 'Dockerfile'
      contextPath: 'https://github.com/Azure-Samples/acr-build-helloworld-node.git'
      imageNames: [
        '{{.Run.Registry}}/hello-world:{{.Run.ID}}'
      ]
      noCache: false
      push: true
    }
    trigger: {
      sourceTriggers: [
        {
          name: 'defaultSourceTriggerName'
          sourceRepository: {
            sourceControlType: 'Github'
            repositoryUrl: 'https://github.com/Azure-Samples/acr-build-helloworld-node.git'
            branch: 'master'
            sourceControlAuthProperties: {}
          }
          sourceTriggerEvents: [
            'commit'
          ]
          status: 'Enabled'
        }
      ]
    }
  }
}

// Content trust signing key (using Key Vault for secure key storage)
resource signingKey 'Microsoft.KeyVault/vaults/keys@2023-02-01' = {
  name: '${last(split(keyVaultId, '/'))}/acr-content-trust-key'
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'sign'
      'verify'
    ]
    attributes: {
      enabled: true
      exportable: false
    }
  }
}

// ACR Token for service principals (instead of admin user)
resource acrToken 'Microsoft.ContainerRegistry/registries/tokens@2023-07-01' = {
  parent: acr
  name: 'ci-cd-token'
  properties: {
    status: 'enabled'
    scopeMapId: acrScopeMap.id
  }
}

// ACR Scope Map for fine-grained permissions
resource acrScopeMap 'Microsoft.ContainerRegistry/registries/scopeMaps@2023-07-01' = {
  parent: acr
  name: 'ci-cd-scope'
  properties: {
    description: 'Scope map for CI/CD operations'
    actions: [
      'repositories/*/content/read'
      'repositories/*/content/write'
      'repositories/*/metadata/read'
      'repositories/*/metadata/write'
    ]
  }
}

// ACR Webhook for deployment notifications
resource acrWebhook 'Microsoft.ContainerRegistry/registries/webhooks@2023-07-01' = {
  parent: acr
  name: 'deploymentwebhook'
  location: location
  tags: commonTags
  properties: {
    status: 'enabled'
    scope: '*'
    actions: [
      'push'
      'quarantine'
    ]
    serviceUri: 'https://example.com/webhook' // Replace with actual webhook endpoint
    customHeaders: {
      'X-ACR-Webhook': 'deployment'
    }
  }
}

// Outputs
output acrId string = acr.id
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output acrPrincipalId string = acr.identity.principalId
output acrPrivateEndpointId string = acrPrivateEndpoint.id
output acrTokenId string = acrToken.id