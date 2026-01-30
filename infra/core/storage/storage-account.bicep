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

@description('Allow shared key access')
param allowSharedKeyAccess bool = true

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

output id string = storageAccount.id
output name string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
