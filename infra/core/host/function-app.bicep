@description('Name of the Function App')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('App Service Plan ID')
param appServicePlanId string

@description('Storage Account Name')
param storageAccountName string

@description('Application Insights Connection String')
param applicationInsightsConnectionString string

@description('Application Insights Instrumentation Key')
param applicationInsightsInstrumentationKey string

// Logging Configuration Parameters
@description('Default log level')
@allowed(['Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical', 'None'])
param defaultLogLevel string = 'Warning'

@description('Host.Results log level')
@allowed(['Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical', 'None'])
param hostResultsLogLevel string = 'Information'

@description('Host.Aggregator log level')
@allowed(['Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical', 'None'])
param hostAggregatorLogLevel string = 'Trace'

@description('Function log level')
@allowed(['Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical', 'None'])
param functionLogLevel string = 'Information'

@description('Enable sampling')
param enableSampling bool = true

@description('Max telemetry items per second')
param maxTelemetryItemsPerSecond int = 5

@description('Sampling excluded types')
param samplingExcludedTypes string = 'Request;Exception'

@description('Enable dependency tracking')
param enableDependencyTracking bool = true

@description('Enable scale controller logs')
param enableScaleControllerLogs bool = false

@description('Python version')
param pythonVersion string = '3.11'

@description('Functions runtime version')
param functionsRuntimeVersion string = '~4'

// Reference existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Python|${pythonVersion}'
      pythonVersion: pythonVersion
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(name)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionsRuntimeVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsightsInstrumentationKey
        }
        // Logging level overrides via App Settings
        {
          name: 'AzureFunctionsJobHost__logging__logLevel__default'
          value: defaultLogLevel
        }
        {
          name: 'AzureFunctionsJobHost__logging__logLevel__Host.Results'
          value: hostResultsLogLevel
        }
        {
          name: 'AzureFunctionsJobHost__logging__logLevel__Host.Aggregator'
          value: hostAggregatorLogLevel
        }
        {
          name: 'AzureFunctionsJobHost__logging__logLevel__Function'
          value: functionLogLevel
        }
        // Sampling configuration
        {
          name: 'AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__isEnabled'
          value: string(enableSampling)
        }
        {
          name: 'AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__maxTelemetryItemsPerSecond'
          value: string(maxTelemetryItemsPerSecond)
        }
        {
          name: 'AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__excludedTypes'
          value: samplingExcludedTypes
        }
        // Dependency tracking
        {
          name: 'AzureFunctionsJobHost__logging__applicationInsights__enableDependencyTracking'
          value: string(enableDependencyTracking)
        }
        // Scale controller logs
        {
          name: 'SCALE_CONTROLLER_LOGGING_ENABLED'
          value: enableScaleControllerLogs ? 'AppInsights:Verbose' : ''
        }
        // Enable Python worker logs
        {
          name: 'PYTHON_ENABLE_DEBUG_LOGGING'
          value: defaultLogLevel == 'Debug' || defaultLogLevel == 'Trace' ? '1' : '0'
        }
      ]
    }
  }
}

output id string = functionApp.id
output name string = functionApp.name
output uri string = 'https://${functionApp.properties.defaultHostName}'
output defaultHostName string = functionApp.properties.defaultHostName
