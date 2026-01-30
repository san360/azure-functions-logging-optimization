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

// Abbreviations for resource naming
var abbrs = {
  resourceGroup: 'rg-'
  storageAccount: 'st'
  appServicePlan: 'asp-'
  functionApp: 'func-'
  logAnalyticsWorkspace: 'law-'
  applicationInsights: 'appi-'
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

// Storage Account
module storageAccount './core/storage/storage-account.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    name: _storageAccountName
    location: location
    tags: tags
  }
}

// App Service Plan (Consumption)
module appServicePlan './core/host/app-service-plan.bicep' = {
  name: 'appServicePlan'
  scope: rg
  params: {
    name: _appServicePlanName
    location: location
    tags: tags
    sku: {
      name: 'Y1'
      tier: 'Dynamic'
    }
  }
}

// Function App with configurable logging
module functionApp './core/host/function-app.bicep' = {
  name: 'functionApp'
  scope: rg
  params: {
    name: _functionAppName
    location: location
    tags: union(tags, { 'azd-service-name': 'api' })
    appServicePlanId: appServicePlan.outputs.id
    storageAccountName: storageAccount.outputs.name
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
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
  }
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
