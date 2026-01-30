@description('Name of the Application Insights resource')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Application type')
param applicationType string = 'web'

@description('Disable local authentication')
param disableLocalAuth bool = false

@description('Sampling percentage (0-100). Set to 100 to disable sampling at AI level.')
param samplingPercentage int = 100

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspaceId
    DisableLocalAuth: disableLocalAuth
    SamplingPercentage: samplingPercentage
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output id string = applicationInsights.id
output name string = applicationInsights.name
output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
