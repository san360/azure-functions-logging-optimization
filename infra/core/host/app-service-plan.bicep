@description('Name of the App Service Plan')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('SKU configuration')
param sku object = {
  name: 'FC1'
  tier: 'FlexConsumption'
}

@description('Kind of the App Service Plan')
param kind string = 'functionapp'

@description('Is reserved (Linux) - Always true for Flex Consumption')
param reserved bool = true

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
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
