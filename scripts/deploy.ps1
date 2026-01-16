# ============================================================
# VS Code + GitHub Copilot Azure Demo Deployment Script
# ============================================================

$ErrorActionPreference = "Stop"

# Generate unique suffix
$SUFFIX = Get-Random -Maximum 99999

# Configuration
$RESOURCE_GROUP = "rg-copilot-demo"
$LOCATION = "eastus"
$SQL_SERVER_NAME = "sql-copilot-demo-$SUFFIX"
$SQL_DB_NAME = "appdb"
$SQL_ADMIN = "sqladmin"
$SQL_PASSWORD = "CopilotDemo2026!"
$APP_SERVICE_PLAN = "asp-copilot-demo"
$FRONTEND_APP = "app-copilot-demo-frontend-$SUFFIX"
$BACKEND_APP = "app-copilot-demo-backend-$SUFFIX"
$APP_INSIGHTS = "ai-copilot-demo"
$STORAGE_ACCOUNT = "st$SUFFIX"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  VS Code + GitHub Copilot Azure Demo Deployment" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resources to be created:" -ForegroundColor Yellow
Write-Host "  - Resource Group: $RESOURCE_GROUP"
Write-Host "  - App Service Plan: $APP_SERVICE_PLAN (B1)"
Write-Host "  - Frontend Web App: $FRONTEND_APP"
Write-Host "  - Backend API App: $BACKEND_APP"
Write-Host "  - SQL Server: $SQL_SERVER_NAME"
Write-Host "  - SQL Database: $SQL_DB_NAME (Basic tier)"
Write-Host "  - Application Insights: $APP_INSIGHTS"
Write-Host "  - Storage Account: $STORAGE_ACCOUNT"
Write-Host ""
Write-Host "Estimated cost: ~15-25 dollars for 5 days" -ForegroundColor Green
Write-Host ""

$confirm = Read-Host "Proceed with deployment? (y/n)"
if ($confirm -ne "y") {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting deployment..." -ForegroundColor Cyan
Write-Host ""

# STEP 1: Resource Group
Write-Host "[1/8] Creating Resource Group..." -ForegroundColor Yellow
az group create --name $RESOURCE_GROUP --location $LOCATION --output none
Write-Host "  Done - Resource Group created" -ForegroundColor Green

# STEP 2: Storage Account
Write-Host "[2/8] Creating Storage Account..." -ForegroundColor Yellow
az storage account create --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --location $LOCATION --sku Standard_LRS --kind StorageV2 --output none
Write-Host "  Done - Storage Account created" -ForegroundColor Green

# STEP 3: Application Insights
Write-Host "[3/8] Creating Application Insights..." -ForegroundColor Yellow
az monitor app-insights component create --app $APP_INSIGHTS --location $LOCATION --resource-group $RESOURCE_GROUP --kind web --output none
$APPINSIGHTS_KEY = az monitor app-insights component show --app $APP_INSIGHTS --resource-group $RESOURCE_GROUP --query instrumentationKey -o tsv
$APPINSIGHTS_CONN = az monitor app-insights component show --app $APP_INSIGHTS --resource-group $RESOURCE_GROUP --query connectionString -o tsv
Write-Host "  Done - Application Insights created" -ForegroundColor Green

# STEP 4: SQL Server
Write-Host "[4/8] Creating Azure SQL Server..." -ForegroundColor Yellow
az sql server create --name $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --admin-user $SQL_ADMIN --admin-password $SQL_PASSWORD --output none
Write-Host "  Done - SQL Server created" -ForegroundColor Green

# STEP 5: SQL Database
Write-Host "[5/8] Creating Azure SQL Database (Basic tier)..." -ForegroundColor Yellow
az sql db create --resource-group $RESOURCE_GROUP --server $SQL_SERVER_NAME --name $SQL_DB_NAME --edition Basic --capacity 5 --max-size 2GB --output none

# Firewall rules
az sql server firewall-rule create --resource-group $RESOURCE_GROUP --server $SQL_SERVER_NAME --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --output none
$MY_IP = (Invoke-RestMethod -Uri "https://api.ipify.org")
az sql server firewall-rule create --resource-group $RESOURCE_GROUP --server $SQL_SERVER_NAME --name AllowMyIP --start-ip-address $MY_IP --end-ip-address $MY_IP --output none
Write-Host "  Done - SQL Database created (Your IP: $MY_IP)" -ForegroundColor Green

# STEP 6: App Service Plan
Write-Host "[6/8] Creating App Service Plan (B1)..." -ForegroundColor Yellow
az appservice plan create --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP --location $LOCATION --sku B1 --is-linux --output none
Write-Host "  Done - App Service Plan created" -ForegroundColor Green

# STEP 7: Backend API
Write-Host "[7/8] Creating Backend API App..." -ForegroundColor Yellow
az webapp create --name $BACKEND_APP --resource-group $RESOURCE_GROUP --plan $APP_SERVICE_PLAN --runtime "NODE:18-lts" --output none

$SQL_CONNECTION = "Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Database=$SQL_DB_NAME;User ID=$SQL_ADMIN;Password=$SQL_PASSWORD;Encrypt=true;Connection Timeout=30;"

az webapp config appsettings set --name $BACKEND_APP --resource-group $RESOURCE_GROUP --settings SQL_CONNECTION_STRING=$SQL_CONNECTION APPINSIGHTS_INSTRUMENTATIONKEY=$APPINSIGHTS_KEY NODE_ENV=production --output none
az webapp log config --name $BACKEND_APP --resource-group $RESOURCE_GROUP --application-logging filesystem --detailed-error-messages true --failed-request-tracing true --web-server-logging filesystem --output none
Write-Host "  Done - Backend API created" -ForegroundColor Green

# STEP 8: Frontend App
Write-Host "[8/8] Creating Frontend Web App..." -ForegroundColor Yellow
az webapp create --name $FRONTEND_APP --resource-group $RESOURCE_GROUP --plan $APP_SERVICE_PLAN --runtime "NODE:18-lts" --output none

$API_URL = "https://$BACKEND_APP.azurewebsites.net"
az webapp config appsettings set --name $FRONTEND_APP --resource-group $RESOURCE_GROUP --settings API_URL=$API_URL APPINSIGHTS_INSTRUMENTATIONKEY=$APPINSIGHTS_KEY --output none
az webapp log config --name $FRONTEND_APP --resource-group $RESOURCE_GROUP --application-logging filesystem --detailed-error-messages true --failed-request-tracing true --web-server-logging filesystem --output none
Write-Host "  Done - Frontend Web App created" -ForegroundColor Green

# Save configuration
$configLines = @(
    "# Copilot Azure Demo - Environment Configuration",
    "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "RESOURCE_GROUP=$RESOURCE_GROUP",
    "APP_SERVICE_PLAN=$APP_SERVICE_PLAN",
    "FRONTEND_APP=$FRONTEND_APP",
    "FRONTEND_URL=https://$FRONTEND_APP.azurewebsites.net",
    "BACKEND_APP=$BACKEND_APP",
    "BACKEND_URL=https://$BACKEND_APP.azurewebsites.net",
    "SQL_SERVER=$SQL_SERVER_NAME",
    "SQL_SERVER_FQDN=$SQL_SERVER_NAME.database.windows.net",
    "SQL_DATABASE=$SQL_DB_NAME",
    "SQL_ADMIN=$SQL_ADMIN",
    "SQL_PASSWORD=$SQL_PASSWORD",
    "APP_INSIGHTS=$APP_INSIGHTS",
    "STORAGE_ACCOUNT=$STORAGE_ACCOUNT",
    "",
    "# Cleanup Command:",
    "# az group delete --name $RESOURCE_GROUP --yes --no-wait"
)

$configLines | Out-File -FilePath "env-config.txt" -Encoding UTF8

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Frontend: https://$FRONTEND_APP.azurewebsites.net" -ForegroundColor White
Write-Host "Backend:  https://$BACKEND_APP.azurewebsites.net" -ForegroundColor White
Write-Host "SQL Server: $SQL_SERVER_NAME.database.windows.net" -ForegroundColor White
Write-Host "App Insights: $APP_INSIGHTS" -ForegroundColor White
Write-Host ""
Write-Host "Config saved to: env-config.txt" -ForegroundColor Yellow
Write-Host ""
Write-Host "To cleanup: az group delete --name $RESOURCE_GROUP --yes" -ForegroundColor Yellow
Write-Host ""
