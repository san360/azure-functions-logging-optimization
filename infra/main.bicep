targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters
@description('Name of the resource group. Defaults to rg-{environmentName}')
param resourceGroupName string = ''

@description('Name of the Function App. Defaults to func-{environmentName}')
param functionAppName string = ''

@description('Name of the App Service Plan. Defaults to asp-{environmentName}')
param appServicePlanName string = ''

@description('Name of the Storage Account. Defaults to st{environmentName}')
param storageAccountName string = ''

@description('Name of the Log Analytics Workspace. Defaults to law-{environmentName}')
param logAnalyticsName string = ''

@description('Name of the Application Insights. Defaults to appi-{environmentName}')
param applicationInsightsName string = ''

@description('Name of the User-Assigned Managed Identity. Defaults to uai-{environmentName}')
param userAssignedIdentityName string = ''

// Logging Configuration Parameters
@description('Default log level for the function app')
@allowed(['Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical', 'None'])
param defaultLogLevel string = 'Warning'

@description('Log level for Host.Results category')
@allowed(['Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical', 'None'])
param hostResultsLogLevel string = 'Information'

@description('Log level for Host.Aggregator category')
@allowed(['Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical', 'None'])
param hostAggregatorLogLevel string = 'Trace'

@description('Log level for Function category')
@allowed(['Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical', 'None'])
param functionLogLevel string = 'Information'

@description('Enable Application Insights sampling')
param enableSampling bool = true

@description('Maximum telemetry items per second (when sampling is enabled)')
param maxTelemetryItemsPerSecond int = 5

@description('Types to exclude from sampling (semicolon separated). E.g., "Request;Exception"')
param samplingExcludedTypes string = 'Request;Exception'

@description('Enable dependency tracking')
param enableDependencyTracking bool = true

@description('Enable scale controller logs')
param enableScaleControllerLogs bool = false

// Flex Consumption parameters
@description('Maximum instance count for Flex Consumption plan')
param maximumInstanceCount int = 100

@description('Instance memory in MB for Flex Consumption plan')
@allowed([2048, 4096])
param instanceMemoryMB int = 2048

// Abbreviations for resource naming
var abbrs = {
  resourceGroup: 'rg-'
  storageAccount: 'st'
  appServicePlan: 'asp-'
  functionApp: 'func-'
  logAnalyticsWorkspace: 'law-'
  applicationInsights: 'appi-'
  userAssignedIdentity: 'uai-'
}

// Unique token for naming
var uniqueToken = toLower(uniqueString(subscription().id, environmentName, location))

// Resource names
var _resourceGroupName = !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourceGroup}${environmentName}'
var _storageAccountName = !empty(storageAccountName) ? storageAccountName : '${abbrs.storageAccount}${replace(environmentName, '-', '')}${take(uniqueToken, 8)}'
var _appServicePlanName = !empty(appServicePlanName) ? appServicePlanName : '${abbrs.appServicePlan}${environmentName}'
var _functionAppName = !empty(functionAppName) ? functionAppName : '${abbrs.functionApp}${environmentName}'
var _logAnalyticsName = !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.logAnalyticsWorkspace}${environmentName}'
var _applicationInsightsName = !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.applicationInsights}${environmentName}'
var _userAssignedIdentityName = !empty(userAssignedIdentityName) ? userAssignedIdentityName : '${abbrs.userAssignedIdentity}${environmentName}'

// Deployment container name for Flex Consumption
var deploymentContainerName = 'app-package-${take(_functionAppName, 32)}-${take(uniqueToken, 7)}'

// Tags for all resources
var tags = {
  'azd-env-name': environmentName
  'logging-optimization-sample': 'true'
}

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: _resourceGroupName
  location: location
  tags: tags
}

// Log Analytics Workspace
module logAnalytics './core/monitor/log-analytics.bicep' = {
  name: 'logAnalytics'
  scope: rg
  params: {
    name: _logAnalyticsName
    location: location
    tags: tags
  }
}

// Application Insights
module applicationInsights './core/monitor/application-insights.bicep' = {
  name: 'applicationInsights'
  scope: rg
  params: {
    name: _applicationInsightsName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Storage Account with deployment container
module storageAccount './core/storage/storage-account.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    name: _storageAccountName
    location: location
    tags: tags
    allowSharedKeyAccess: false
    deploymentContainerName: deploymentContainerName
  }
}

// User-Assigned Managed Identity
module userAssignedIdentity './core/identity/user-assigned-identity.bicep' = {
  name: 'userAssignedIdentity'
  scope: rg
  params: {
    name: _userAssignedIdentityName
    location: location
    tags: tags
  }
}

// Role Assignments for Managed Identity
module roleAssignments './core/identity/role-assignments.bicep' = {
  name: 'roleAssignments'
  scope: rg
  params: {
    storageAccountId: storageAccount.outputs.id
    applicationInsightsId: applicationInsights.outputs.id
    principalId: userAssignedIdentity.outputs.principalId
  }
  dependsOn: [
    storageAccount
    applicationInsights
    userAssignedIdentity
  ]
}

// App Service Plan (Flex Consumption)
module appServicePlan './core/host/app-service-plan.bicep' = {
  name: 'appServicePlan'
  scope: rg
  params: {
    name: _appServicePlanName
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
  }
}

// Function App with configurable logging (Flex Consumption)
module functionApp './core/host/function-app.bicep' = {
  name: 'functionApp'
  scope: rg
  params: {
    name: _functionAppName
    location: location
    tags: union(tags, { 'azd-service-name': 'api' })
    appServicePlanId: appServicePlan.outputs.id
    storageAccountName: storageAccount.outputs.name
    storageBlobEndpoint: storageAccount.outputs.blobEndpoint
    deploymentContainerName: deploymentContainerName
    userAssignedIdentityId: userAssignedIdentity.outputs.id
    userAssignedIdentityClientId: userAssignedIdentity.outputs.clientId
    applicationInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    // Logging configuration
    defaultLogLevel: defaultLogLevel
    hostResultsLogLevel: hostResultsLogLevel
    hostAggregatorLogLevel: hostAggregatorLogLevel
    functionLogLevel: functionLogLevel
    enableSampling: enableSampling
    maxTelemetryItemsPerSecond: maxTelemetryItemsPerSecond
    samplingExcludedTypes: samplingExcludedTypes
    enableDependencyTracking: enableDependencyTracking
    enableScaleControllerLogs: enableScaleControllerLogs
    // Flex Consumption configuration
    maximumInstanceCount: maximumInstanceCount
    instanceMemoryMB: instanceMemoryMB
  }
  dependsOn: [
    roleAssignments
  ]
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_FUNCTION_APP_NAME string = functionApp.outputs.name
output AZURE_FUNCTION_APP_URL string = functionApp.outputs.uri
output AZURE_APPLICATION_INSIGHTS_NAME string = applicationInsights.outputs.name
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.outputs.name
output AZURE_STORAGE_ACCOUNT_NAME string = storageAccount.outputs.name
output AZURE_USER_ASSIGNED_IDENTITY_NAME string = userAssignedIdentity.outputs.name
