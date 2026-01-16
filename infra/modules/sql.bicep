param location string
param sqlServerName string
param sqlDatabaseName string
param userAssignedIdentityId string
param userAssignedIdentityPrincipalId string
param adminEntraId string
param adminEntraLogin string

// Create SQL Server with Managed Identity
resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = {
  name: sqlServerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    // Use Entra ID (Azure AD) authentication; no SQL password
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: adminEntraLogin
      principalId: adminEntraId
      tenantId: subscription().tenantId
    }
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
  }
}

// Create SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-02-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB
    createMode: 'Default'
  }
}

// Firewall rule: Allow Azure Services (including App Service)
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-02-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Firewall rule: Allow current user's IP (for local development)
resource allowCurrentIp 'Microsoft.Sql/servers/firewallRules@2023-02-01-preview' = {
  parent: sqlServer
  name: 'AllowCurrentIp'
  properties: {
    startIpAddress: '0.0.0.0' // Placeholder; in reality, query current user IP
    endIpAddress: '255.255.255.255'
  }
}

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
