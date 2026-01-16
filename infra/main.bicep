metadata description = 'Azure infrastructure for copilot-azure-demo: 3-tier app (frontend → backend → SQL) with Managed Identity'

@minLength(1)
@maxLength(64)
@description('Environment name (e.g., demo, dev, test). Used in resource naming.')
param environment string = 'demo'

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Optional suffix for resource names (for CI isolation or parallel deployments). If provided, overrides deterministic suffix.')
param suffix string = ''

@description('App Service Plan SKU (e.g., B1, B2, P1V2)')
param appServicePlanSku string = 'B1'

@description('SQL Server admin Entra ID (Azure AD) principal ID (GUID)')
param sqlAdminPrincipalId string

@description('SQL Server admin Entra ID login (email or UPN)')
param sqlAdminLogin string

// Compute deterministic suffix if not provided
var computedSuffix = empty(suffix) ? substring(uniqueString(resourceGroup().id, environment), 0, 4) : suffix

// Resource naming (deterministic + optional override)
var resourceNamePrefix = 'copilot-demo-${environment}'
var storageAccountName = toLower(replace('st${environment}${computedSuffix}', '-', ''))
var appInsightsName = 'ai-${resourceNamePrefix}-${computedSuffix}'
var appServicePlanName = 'asp-${resourceNamePrefix}-${computedSuffix}'
var backendAppName = 'app-backend-${environment}-${computedSuffix}'
var frontendAppName = 'app-frontend-${environment}-${computedSuffix}'
var sqlServerName = 'sql-${environment}-${computedSuffix}'
var sqlDatabaseName = 'appdb'
var userAssignedIdentityName = 'mi-${resourceNamePrefix}-${computedSuffix}'

// Get current subscription context
var subscriptionId = subscription().subscriptionId
var tenantId = subscription().tenantId

// ============ User-Assigned Managed Identity ============
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userAssignedIdentityName
  location: location
}

// ============ Storage Account ============
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ============ Application Insights ============
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============ App Service Plan (Linux) ============
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  kind: 'Linux'
  sku: {
    name: appServicePlanSku
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

// ============ SQL Server and Database ============
module sqlModule 'modules/sql.bicep' = {
  name: 'sqlDeployment'
  params: {
    location: location
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    userAssignedIdentityId: userAssignedIdentity.id
    userAssignedIdentityPrincipalId: userAssignedIdentity.properties.principalId
    adminEntraId: sqlAdminPrincipalId
    adminEntraLogin: sqlAdminLogin
  }
}

// ============ Backend Web App ============
module backendWebApp 'modules/webapp.bicep' = {
  name: 'backendAppDeployment'
  params: {
    location: location
    appServicePlanId: appServicePlan.id
    appName: backendAppName
    runtimeStack: 'NODE|18-lts'
    appInsightsKey: appInsights.properties.InstrumentationKey
    userAssignedIdentityId: userAssignedIdentity.id
    appSettings: [
      {
        name: 'API_URL'
        value: 'http://localhost:3001' // Local dev; overridden in deploy
      }
      {
        name: 'NODE_ENV'
        value: 'production'
      }
      {
        name: 'SQL_CONNECTION_STRING'
        value: 'Server=tcp:${sqlModule.outputs.sqlServerFqdn},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Managed Identity;User Id=${userAssignedIdentity.properties.clientId};'
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: userAssignedIdentity.properties.clientId
      }
    ]
  }
}

// ============ Frontend Web App ============
module frontendWebApp 'modules/webapp.bicep' = {
  name: 'frontendAppDeployment'
  params: {
    location: location
    appServicePlanId: appServicePlan.id
    appName: frontendAppName
    runtimeStack: 'NODE|18-lts'
    appInsightsKey: appInsights.properties.InstrumentationKey
    userAssignedIdentityId: userAssignedIdentity.id
    appSettings: [
      {
        name: 'API_URL'
        value: backendWebApp.outputs.webAppUrl
      }
      {
        name: 'NODE_ENV'
        value: 'production'
      }
    ]
  }
}

// ============ OUTPUTS ============
// Required outputs for azd service-to-resource mapping
@description('Frontend Web App resource name (for azd deploy)')
output AZURE_WEB_APP_NAME_FRONTEND string = frontendAppName

@description('Backend Web App resource name (for azd deploy)')
output AZURE_WEB_APP_NAME_BACKEND string = backendAppName

@description('Frontend application URL')
output frontendUrl string = frontendWebApp.outputs.webAppUrl

@description('Backend API URL')
output backendUrl string = backendWebApp.outputs.webAppUrl

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlModule.outputs.sqlServerFqdn

@description('SQL Database name')
output sqlDatabaseName string = sqlModule.outputs.sqlDatabaseName

@description('Storage Account name')
output storageAccountName string = storageAccount.name

@description('Managed Identity client ID (for app use)')
output managedIdentityClientId string = userAssignedIdentity.properties.clientId

@description('Managed Identity principal ID (for RBAC)')
output managedIdentityPrincipalId string = userAssignedIdentity.properties.principalId

@description('Resource group name')
output resourceGroupName string = resourceGroup().name

@description('Resource naming suffix (computed or provided)')
output resourceSuffix string = computedSuffix
