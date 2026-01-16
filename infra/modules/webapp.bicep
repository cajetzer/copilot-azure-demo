param location string
param appServicePlanId string
param appName string
param runtimeStack string = 'NODE|18-lts'
param appSettings array = []
param appInsightsKey string
param userAssignedIdentityId string
param serviceName string = ''

// Create the Web App
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  tags: {
    'azd-service-name': serviceName
  }
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
      linuxFxVersion: runtimeStack
      alwaysOn: true
      appSettings: concat(
        [
          {
            name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
            value: appInsightsKey
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: 'InstrumentationKey=${appInsightsKey}'
          }
          {
            name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
            value: '~3'
          }
          {
            name: 'XDT_MicrosoftApplicationInsights_Mode'
            value: 'recommended'
          }
        ],
        appSettings
      )
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
  }
}

// Configure application logging
resource webAppLogging 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: webApp
  name: 'logs'
  properties: {
    applicationLogs: {
      fileSystemLevel: 'Verbose'
    }
    detailedErrorMessages: {
      enabled: true
    }
    failedRequestsTracing: {
      enabled: true
    }
    httpLogs: {
      fileSystem: {
        enabled: true
        retentionInDays: 1
        retentionInMb: 100
      }
    }
  }
}

output webAppId string = webApp.id
output webAppName string = webApp.name
output defaultHostName string = webApp.properties.defaultHostName
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
