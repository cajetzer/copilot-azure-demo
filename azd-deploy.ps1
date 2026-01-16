#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Wrapper script for 'azd up' that uses the logged-in user as SQL admin and handles parameter resolution.
  
.DESCRIPTION
  Uses the currently logged-in Azure user as the SQL Server admin, looks up their Entra ID object ID,
  and then calls 'azd up' with the required parameters.
  
.EXAMPLE
  .\azd-deploy.ps1
#>

param(
    [switch]$ProvisionOnly
)

Write-Host "🚀 Azure Developer CLI Deployment Wrapper" -ForegroundColor Cyan
Write-Host ""

# Check if already logged in
try {
    $account = az account show --query "user.name" -o tsv 2>$null
    if ($account) {
        Write-Host "✓ Logged in as: $account" -ForegroundColor Green
        Write-Host ""
    }
}
catch {
    Write-Host "⚠️  Not logged in. Please run: az login" -ForegroundColor Yellow
    exit 1
}

# Use logged-in user as SQL admin
$adminUpn = $account
Write-Host "SQL Server Admin Configuration" -ForegroundColor Cyan
Write-Host "─────────────────────────────────" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "Using logged-in user as SQL Server admin: $adminUpn" -ForegroundColor Cyan
Write-Host ""

# Look up the object ID
Write-Host "Looking up Entra ID object ID..." -ForegroundColor Cyan

try {
    $adminObjectId = az ad user show --id $adminUpn --query id -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($adminObjectId)) {
        Write-Host "✗ Failed to find user: $adminUpn" -ForegroundColor Red
        Write-Host "  Ensure the email is a valid Entra ID user in your tenant." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✓ Found object ID: $adminObjectId" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error looking up user: $_" -ForegroundColor Red
    exit 1
}

# Read location and resourceGroupName from parameters.json (with defaults)
$parametersFile = "$PSScriptRoot/infra/parameters.json"
$location = "eastus"
$resourceGroupName = "rg-copilot-demo"
if (Test-Path $parametersFile) {
    try {
        $params = Get-Content $parametersFile | ConvertFrom-Json
        if ($params.parameters.location.value) {
            $location = $params.parameters.location.value
        }
        if ($params.parameters.resourceGroupName.value) {
            $resourceGroupName = $params.parameters.resourceGroupName.value
        }
    }
    catch {
        Write-Host "⚠️  Could not parse parameters.json, using defaults" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Deployment Parameters" -ForegroundColor Cyan
Write-Host "────────────────────" -ForegroundColor DarkCyan
Write-Host "  Admin UPN:       $adminUpn"
Write-Host "  Admin Object ID: $adminObjectId"
Write-Host "  Location:        $location"
Write-Host "  Resource Group:  $resourceGroupName"
Write-Host ""

# Ensure azd project is initialized
Write-Host "Checking azd project..." -ForegroundColor Cyan
$azdDir = ".azure"
if (-not (Test-Path $azdDir)) {
    Write-Host "Initializing azd project structure..." -ForegroundColor Cyan
    
    # Create .azure directory and environment folder
    New-Item -ItemType Directory -Path "$azdDir/demo" -Force | Out-Null
    
    # Create config.json (azd looks for this to recognize a project)
    $config = @{
        version = 1
        defaultEnvironment = "demo"
    } | ConvertTo-Json
    Set-Content -Path "$azdDir/config.json" -Value $config -Encoding UTF8
    
    Write-Host "✓ Project structure created" -ForegroundColor Green
}
else {
    Write-Host "✓ Project already initialized" -ForegroundColor Green
}

# Set azd environment variables so azd doesn't prompt for them
Write-Host ""
Write-Host "Setting azd environment parameters..." -ForegroundColor Cyan

# azd stores parameters as AZURE_INFRA_PARAMETERS_<PARAM_NAME> in the environment
$envFilePath = "$azdDir/demo/.env"
$envContent = @"
AZURE_ENV_NAME=demo
AZURE_LOCATION=$location
AZURE_RESOURCE_GROUP=$resourceGroupName
sqlAdminPrincipalId=$adminObjectId
sqlAdminLogin=$adminUpn
"@

Set-Content -Path $envFilePath -Value $envContent -Encoding UTF8
Write-Host "✓ Environment parameters set" -ForegroundColor Green

Write-Host ""

# Build azd command (no --parameter flags needed)
if ($ProvisionOnly) {
    Write-Host "Running: azd provision (infrastructure only, no app deployment)" -ForegroundColor Yellow
    $azdCmd = "provision"
}
else {
    Write-Host "Running: azd up (full deployment)" -ForegroundColor Yellow
    $azdCmd = "up"
}

Write-Host ""

# Call azd
& azd $azdCmd
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Wait 2-3 minutes for Application Insights data to populate"
    Write-Host "  2. Run: .\scripts\simulate-issues.ps1 -Issue all-issues"
    Write-Host "  3. Then ask Copilot questions about your Azure resources"
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "✗ Deployment failed with exit code: $exitCode" -ForegroundColor Red
}

exit $exitCode
