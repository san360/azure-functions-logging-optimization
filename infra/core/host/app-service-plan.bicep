@description('Name of the App Service Plan')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('SKU configuration')
param sku object = {
  name: 'Y1'
  tier: 'Dynamic'
}

@description('Kind of the App Service Plan')
param kind string = 'functionapp'

@description('Is reserved (Linux)')
param reserved bool = false

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: sku
  properties: {
    reserved: reserved
  }
}

output id string = appServicePlan.id
output name string = appServicePlan.name
