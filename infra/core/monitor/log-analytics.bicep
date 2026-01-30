@description('Name of the Log Analytics Workspace')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('Retention period in days')
param retentionInDays int = 30

@description('SKU name')
param skuName string = 'PerGB2018'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1 // No cap
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output id string = logAnalyticsWorkspace.id
output name string = logAnalyticsWorkspace.name
output customerId string = logAnalyticsWorkspace.properties.customerId
