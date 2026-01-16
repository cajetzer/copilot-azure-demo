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

Write-Host ""
Write-Host "Deployment Parameters" -ForegroundColor Cyan
Write-Host "────────────────────" -ForegroundColor DarkCyan
Write-Host "  Admin UPN:       $adminUpn"
Write-Host "  Admin Object ID: $adminObjectId"
Write-Host "  Location:        eastus"
Write-Host "  Resource Group:  rg-copilot-demo"
Write-Host ""

# Build azd command
$azdCmd = @(
    "up",
    "--parameter", "sqlAdminPrincipalId=$adminObjectId",
    "--parameter", "sqlAdminLogin=$adminUpn"
)

if ($ProvisionOnly) {
    $azdCmd[0] = "provision"
    Write-Host "Running: azd provision (infrastructure only, no app deployment)" -ForegroundColor Yellow
}
else {
    Write-Host "Running: azd up (full deployment)" -ForegroundColor Yellow
}

Write-Host ""

# Call azd with resolved parameters
& azd @azdCmd
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
