@description('Name of the Storage Account')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('Storage Account SKU')
param sku string = 'Standard_LRS'

@description('Storage Account kind')
param kind string = 'StorageV2'

@description('Minimum TLS version')
param minimumTlsVersion string = 'TLS1_2'

@description('Allow shared key access - set to false for managed identity only access')
param allowSharedKeyAccess bool = false

@description('Name of the deployment container for function app packages')
param deploymentContainerName string = ''

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    minimumTlsVersion: minimumTlsVersion
    allowSharedKeyAccess: allowSharedKeyAccess
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    dnsEndpointType: 'Standard'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob service for containers
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {}
  }
}

// Deployment container for Flex Consumption function app packages
resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = if (!empty(deploymentContainerName)) {
  parent: blobService
  name: deploymentContainerName
  properties: {
    publicAccess: 'None'
  }
}

output id string = storageAccount.id
output name string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
