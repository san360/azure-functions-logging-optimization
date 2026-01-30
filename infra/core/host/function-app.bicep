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

@description('Storage Account Blob Endpoint')
param storageBlobEndpoint string

@description('Deployment Container Name for function app packages')
param deploymentContainerName string

@description('User-Assigned Managed Identity Resource ID')
param userAssignedIdentityId string

@description('User-Assigned Managed Identity Client ID')
param userAssignedIdentityClientId string

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

@description('Maximum instance count for Flex Consumption')
param maximumInstanceCount int = 100

@description('Instance memory in MB for Flex Consumption')
@allowed([2048, 4096])
param instanceMemoryMB int = 2048

// Flex Consumption Function App with User-Assigned Managed Identity
resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageBlobEndpoint}${deploymentContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: userAssignedIdentityId
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: instanceMemoryMB
      }
      runtime: {
        name: 'python'
        version: pythonVersion
      }
    }
  }

  // App Settings configured as nested resource
  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: {
      // Use managed identity for storage access (no keys)
      AzureWebJobsStorage__accountName: storageAccountName
      AzureWebJobsStorage__credential: 'managedidentity'
      AzureWebJobsStorage__clientId: userAssignedIdentityClientId
      // Application Insights with managed identity
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
      APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${userAssignedIdentityClientId};Authorization=AAD'
      // Logging level overrides via App Settings
      AzureFunctionsJobHost__logging__logLevel__default: defaultLogLevel
      'AzureFunctionsJobHost__logging__logLevel__Host.Results': hostResultsLogLevel
      'AzureFunctionsJobHost__logging__logLevel__Host.Aggregator': hostAggregatorLogLevel
      AzureFunctionsJobHost__logging__logLevel__Function: functionLogLevel
      // Sampling configuration
      'AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__isEnabled': string(enableSampling)
      AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__maxTelemetryItemsPerSecond: string(maxTelemetryItemsPerSecond)
      AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__excludedTypes: samplingExcludedTypes
      // Dependency tracking
      AzureFunctionsJobHost__logging__applicationInsights__enableDependencyTracking: string(enableDependencyTracking)
      // Scale controller logs
      SCALE_CONTROLLER_LOGGING_ENABLED: enableScaleControllerLogs ? 'AppInsights:Verbose' : ''
      // Enable Python worker logs
      PYTHON_ENABLE_DEBUG_LOGGING: defaultLogLevel == 'Debug' || defaultLogLevel == 'Trace' ? '1' : '0'
    }
  }
}

output id string = functionApp.id
output name string = functionApp.name
output uri string = 'https://${functionApp.properties.defaultHostName}'
output defaultHostName string = functionApp.properties.defaultHostName
