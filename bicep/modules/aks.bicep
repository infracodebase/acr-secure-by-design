// AKS module for Zero Trust infrastructure
// Private AKS cluster with advanced security and ACR integration

@description('Azure region for resources')
param location string

@description('Naming prefix for resources')
param namingPrefix string

@description('Common tags for all resources')
param commonTags object

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('ACR ID for integration')
param acrId string

@description('System pool subnet ID')
param systemPoolSubnetId string

@description('User pool subnet ID')
param userPoolSubnetId string

@description('Private link subnet ID')
param privateLinkSubnetId string

// User-assigned managed identity for AKS
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namingPrefix}-aks-identity'
  location: location
  tags: commonTags
}

// Private AKS Cluster with advanced security
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: '${namingPrefix}-aks'
  location: location
  tags: union(commonTags, {
    Service: 'Kubernetes'
    Purpose: 'ZeroTrust'
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }
  properties: {
    // Kubernetes version
    kubernetesVersion: '1.29.0'

    // DNS configuration
    dnsPrefix: '${namingPrefix}-aks'

    // Private cluster configuration
    apiServerAccessProfile: {
      enablePrivateCluster: true
      enablePrivateClusterPublicFQDN: false
      privateDNSZone: 'system'
      disableRunCommand: true
    }

    // Agent pool profiles (system pool)
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: 3
        vmSize: 'Standard_D4s_v3'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        osDiskSizeGB: 128
        osDiskType: 'Premium_LRS'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        vnetSubnetID: systemPoolSubnetId
        enableAutoScaling: true
        minCount: 3
        maxCount: 10
        maxPods: 50
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        enableNodePublicIP: false
        enableEncryptionAtHost: true
        enableUltraSSD: false
        kubeletDiskType: 'OS'
        tags: union(commonTags, {
          NodePool: 'system'
        })
      }
    ]

    // Network configuration
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      serviceCidr: '10.100.0.0/16'
      dnsServiceIP: '10.100.0.10'
      loadBalancerSku: 'standard'
      outboundType: 'userDefinedRouting'
      podCidrs: [
        '10.200.0.0/16'
      ]
      serviceCidrs: [
        '10.100.0.0/16'
      ]
      ipFamilies: [
        'IPv4'
      ]
    }

    // Add-on profiles
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2h'
        }
      }
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      azureDefender: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }

    // Security configuration
    securityProfile: {
      defender: {
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
        securityMonitoring: {
          enabled: true
        }
      }
      workloadIdentity: {
        enabled: true
      }
      imageCleaner: {
        enabled: true
        intervalHours: 24
      }
    }

    // OIDC issuer for workload identity
    oidcIssuerProfile: {
      enabled: true
    }

    // Auto-upgrade configuration
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }

    // Maintenance window
    maintenanceWindow: {
      allowedMaintenanceWindowDays: [
        'Monday'
        'Tuesday'
        'Wednesday'
        'Thursday'
        'Friday'
      ]
      allowedMaintenanceWindowHours: [
        {
          day: 'Monday'
          hours: [
            2
            3
            4
          ]
        }
        {
          day: 'Tuesday'
          hours: [
            2
            3
            4
          ]
        }
        {
          day: 'Wednesday'
          hours: [
            2
            3
            4
          ]
        }
        {
          day: 'Thursday'
          hours: [
            2
            3
            4
          ]
        }
        {
          day: 'Friday'
          hours: [
            2
            3
            4
          ]
        }
      ]
    }

    // Monitoring
    azureMonitorProfile: {
      metrics: {
        enabled: true
      }
    }

    // Disable public cluster access
    publicNetworkAccess: 'Disabled'

    // Enable RBAC
    enableRBAC: true

    // Azure AD integration
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: [] // Add admin group IDs as needed
    }
  }
}

// User node pool for application workloads
resource userNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-10-01' = {
  parent: aksCluster
  name: 'userpool'
  properties: {
    count: 2
    vmSize: 'Standard_D4s_v3'
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    osDiskSizeGB: 128
    osDiskType: 'Premium_LRS'
    osType: 'Linux'
    osSKU: 'Ubuntu'
    vnetSubnetID: userPoolSubnetId
    enableAutoScaling: true
    minCount: 2
    maxCount: 20
    maxPods: 50
    availabilityZones: [
      '1'
      '2'
      '3'
    ]
    enableNodePublicIP: false
    enableEncryptionAtHost: true
    kubeletDiskType: 'OS'
    tags: union(commonTags, {
      NodePool: 'user'
    })
  }
}

// GPU node pool for ML workloads (optional)
resource gpuNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-10-01' = {
  parent: aksCluster
  name: 'gpupool'
  properties: {
    count: 0 // Start with 0, scale as needed
    vmSize: 'Standard_NC6s_v3'
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    osDiskSizeGB: 256
    osDiskType: 'Premium_LRS'
    osType: 'Linux'
    osSKU: 'Ubuntu'
    vnetSubnetID: userPoolSubnetId
    enableAutoScaling: true
    minCount: 0
    maxCount: 5
    maxPods: 30
    availabilityZones: [
      '1'
      '2'
      '3'
    ]
    enableNodePublicIP: false
    enableEncryptionAtHost: true
    kubeletDiskType: 'OS'
    tags: union(commonTags, {
      NodePool: 'gpu'
      Workload: 'ML'
    })
  }
}

// Role assignment for ACR pull access
resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(aksCluster.id, acrId, 'AcrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Diagnostic settings for AKS
resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aksCluster
  name: 'aks-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'kube-audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'kube-audit-admin'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'kube-controller-manager'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'kube-scheduler'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'guard'
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

// Outputs
output aksId string = aksCluster.id
output aksName string = aksCluster.name
output aksFqdn string = aksCluster.properties.fqdn
output aksPrivateFqdn string = aksCluster.properties.privateFQDN
output aksIdentityPrincipalId string = aksIdentity.properties.principalId
output aksIdentityClientId string = aksIdentity.properties.clientId
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL