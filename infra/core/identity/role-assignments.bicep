@description('Storage Account ID')
param storageAccountId string

@description('Application Insights ID')
param applicationInsightsId string

@description('Principal ID of the managed identity')
param principalId string

// Role definition IDs
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var storageTableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var monitoringMetricsPublisherRoleId = '3913510d-42f4-4e42-8a64-420c390055eb'

// Reference existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: last(split(storageAccountId, '/'))
}

// Reference existing Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: last(split(applicationInsightsId, '/'))
}

// Role assignment: Storage Blob Data Owner
resource storageBlobDataOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storageAccount.id, principalId, 'Storage Blob Data Owner')
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Storage Blob Data Contributor
resource storageBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storageAccount.id, principalId, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Storage Queue Data Contributor
resource storageQueueDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storageAccount.id, principalId, 'Storage Queue Data Contributor')
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Storage Table Data Contributor
resource storageTableDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storageAccount.id, principalId, 'Storage Table Data Contributor')
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageTableDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Monitoring Metrics Publisher for Application Insights
resource monitoringMetricsPublisherRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, principalId, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherRoleId)
    principalType: 'ServicePrincipal'
  }
}
