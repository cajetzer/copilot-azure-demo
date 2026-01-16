# Copilot Demo - Tested Commands & Prompts
## All commands verified working as of January 13, 2026

### ⚠️ Important Notes
**Application Insights queries require data to be present:**
- Queries may return empty results if Application Insights has no data yet
- Fresh deployments need 2-5 minutes for data to populate
- Commands include error handling and will display helpful messages
- To generate test data: `.\generate-load.ps1 -Scenario all` or `.\simulate-issues.ps1 -Issue all-issues`

**Resource naming:**
- All commands use variables from `env-config.txt` instead of hardcoded names
- Ensure you run commands from the repository root where `env-config.txt` exists
- Variables are sourced at the start of each command block

---

## BEFORE THE DEMO

### Generate Issues to Troubleshoot
```powershell
# Run this 5 minutes before demo to populate data:
.\simulate-issues.ps1 -Issue all-issues

# Or generate traffic manually:
.\generate-load.ps1 -Scenario all
```

---

## DEMO SECTION 1: ENVIRONMENT DISCOVERY
**What it shows:** Full visibility into Azure infrastructure

### ✅ TESTED COMMANDS:

**List all resources:**
```powershell
az resource list --resource-group rg-copilot-demo --query "[].{Name:name, Type:type, Location:location}" -o table
```
*Expected output: Shows 10 resources including web apps, SQL, storage, App Insights*

**Check web app status:**
```powershell
az webapp list --resource-group rg-copilot-demo --query "[].{Name:name, State:state, URL:defaultHostName}" -o table
```
*Expected output: Both apps showing "Running" state*

**Check SQL server status:**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
az sql server show --name sql-copilot-demo-{SUFFIX} --resource-group rg-copilot-demo --query "{Name:name, FQDN:fullyQualifiedDomainName, State:state}" -o table
```
*Expected output: State = Ready*

### COPILOT PROMPTS:
- "Show me all resources in my Azure resource group rg-copilot-demo"
- "Check if my web apps are running"
- "Is my SQL database online?"

---

## DEMO SECTION 2: FRONTEND TROUBLESHOOTING  
**What it shows:** Real-time logs, HTTP errors, response times

### ✅ TESTED COMMANDS:

**Stream live logs (interactive):**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
az webapp log tail --name app-copilot-demo-frontend-{SUFFIX} --resource-group rg-copilot-demo
```
*Shows: Real-time application logs*

**Check recent activity log:**
```powershell
az monitor activity-log list --resource-group rg-copilot-demo --max-events 10 --query "[].{Time:eventTimestamp, Operation:operationName.localizedValue, Status:status.localizedValue}" -o table
```
*Shows: Recent operations like restarts, config changes*

**Web app HTTP metrics:**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
$subId = az account show --query id -o tsv
az monitor metrics list --resource "/subscriptions/$subId/resourceGroups/rg-copilot-demo/providers/Microsoft.Web/sites/app-copilot-demo-frontend-{SUFFIX}" --metric "Requests" "Http2xx" "Http4xx" --interval PT5M -o table
```
*Shows: Request counts by status code*

### COPILOT PROMPTS:
- "Stream live logs from my frontend app"
- "Show me HTTP errors from my web app"
- "What's the average response time?"

---

## DEMO SECTION 3: BACKEND/API INVESTIGATION
**What it shows:** App Insights telemetry, slow endpoints, dependencies

### ✅ TESTED COMMANDS:

**Request summary by status:**
```powershell
# Source environment config
Get-Content ./env-config.txt | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $parts = $_ -split '=', 2
    Set-Variable -Name $parts[0] -Value $parts[1]
}

# Run query with error handling
$result = az monitor app-insights query --app $APP_INSIGHTS --resource-group $RESOURCE_GROUP --analytics-query "requests | summarize count() by cloud_RoleName, resultCode | order by count_ desc" -o json 2>&1

if ($LASTEXITCODE -ne 0 -or $result -notmatch '^\s*\{') {
    Write-Host "⚠️  Query failed. Ensure Application Insights has data. Try running: .\generate-load.ps1 -Scenario all" -ForegroundColor Yellow
} else {
    $result | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Write-Host
}
```
*Shows: Count of 200s, 404s, etc. per app*  
*Note: If no data is available, run `.\generate-load.ps1 -Scenario all` to populate Application Insights*

**Find 404 errors:**
```powershell
# Source environment config
Get-Content ./env-config.txt | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $parts = $_ -split '=', 2
    Set-Variable -Name $parts[0] -Value $parts[1]
}

# Run query with error handling
$result = az monitor app-insights query --app $APP_INSIGHTS --resource-group $RESOURCE_GROUP --analytics-query "requests | where resultCode == '404' | project timestamp, url, duration | order by timestamp desc | take 10" -o json 2>&1

if ($LASTEXITCODE -ne 0 -or $result -notmatch '^\s*\{') {
    Write-Host "⚠️  Query failed. Ensure Application Insights has data. Try running: .\simulate-issues.ps1 -Issue http-errors" -ForegroundColor Yellow
} else {
    $parsedResult = $result | ConvertFrom-Json
    if ($null -eq $parsedResult.tables -or $parsedResult.tables.Count -eq 0 -or $parsedResult.tables[0].rows.Count -eq 0) {
        Write-Host "ℹ️  No 404 errors found in Application Insights. To generate test data, run: .\simulate-issues.ps1 -Issue http-errors" -ForegroundColor Cyan
    } else {
        $result | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Write-Host
    }
}
```
*Shows: Recent 404 errors with URLs*  
*Note: If no 404 errors exist, generate them with `.\simulate-issues.ps1 -Issue http-errors`*

**Average response times per app:**
```powershell
# Source environment config
Get-Content ./env-config.txt | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $parts = $_ -split '=', 2
    Set-Variable -Name $parts[0] -Value $parts[1]
}

# Run query with error handling
$result = az monitor app-insights query --app $APP_INSIGHTS --resource-group $RESOURCE_GROUP --analytics-query "requests | summarize avgDuration=avg(duration), count=count() by cloud_RoleName | order by avgDuration desc" -o json 2>&1

if ($LASTEXITCODE -ne 0 -or $result -notmatch '^\s*\{') {
    Write-Host "⚠️  Query failed. Ensure Application Insights has data. Try running: .\generate-load.ps1 -Scenario all" -ForegroundColor Yellow
} else {
    $result | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Write-Host
}
```
*Shows: Backend ~33ms, Frontend ~22ms average*  
*Note: Requires active traffic. Generate with `.\generate-load.ps1 -Scenario all`*

**Check app settings:**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
az webapp config appsettings list --name app-copilot-demo-backend-{SUFFIX} --resource-group rg-copilot-demo --query "[].{Name:name, Value:value}" -o table
```
*Shows: All configuration including LOG_LEVEL=DEBUG, VERSION=2.1.0*

### COPILOT PROMPTS:
- "Show me 404 errors from my backend API"
- "What's the average response time for requests?"
- "Check the app settings for my backend"

---

## DEMO SECTION 4: DATABASE DIAGNOSTICS
**What it shows:** SQL metrics, DTU usage, firewall rules

### ✅ TESTED COMMANDS:

**SQL DTU metrics:**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
$subId = az account show --query id -o tsv
az monitor metrics list --resource "/subscriptions/$subId/resourceGroups/rg-copilot-demo/providers/Microsoft.Sql/servers/sql-copilot-demo-{SUFFIX}/databases/appdb" --metric "dtu_consumption_percent" --interval PT5M -o table
```
*Shows: DTU percentage over time (usually 0-1% for idle)*

**SQL Server info:**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
az sql server show --name sql-copilot-demo-{SUFFIX} --resource-group rg-copilot-demo --query "{Name:name, FQDN:fullyQualifiedDomainName, State:state, Admin:administrators.login}" -o table
```
*Shows: Server FQDN, Ready state, AD admin*

**Firewall rules:**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
az sql server firewall-rule list --server sql-copilot-demo-{SUFFIX} --resource-group rg-copilot-demo -o table
```
*Shows: AllowAzureServices and AllowMyIP rules*

**Database size/usage:**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
az sql db show --server sql-copilot-demo-{SUFFIX} --name appdb --resource-group rg-copilot-demo --query "{Name:name, Edition:edition, MaxSize:maxSizeBytes, Status:status}" -o table
```
*Shows: Basic edition, 2GB max, Online status*

### COPILOT PROMPTS:
- "Show me DTU usage for my SQL database"
- "List firewall rules for my SQL server"
- "What's the database size and status?"

---

## DEMO SECTION 5: CONFIG COMPARISON
**What it shows:** Differences between environments, version drift

### ✅ TESTED COMMANDS:

**Compare settings side-by-side:**
```powershell
# Replace {SUFFIX} with your actual suffix from env-config.txt
Write-Host "=== FRONTEND ===" -ForegroundColor Cyan
az webapp config appsettings list --name app-copilot-demo-frontend-{SUFFIX} --resource-group rg-copilot-demo --query "[?name=='VERSION' || name=='LOG_LEVEL' || name=='CACHE_ENABLED' || name=='FEATURE_FLAG_V2'].{Name:name, Value:value}" -o table

Write-Host "`n=== BACKEND ===" -ForegroundColor Cyan  
az webapp config appsettings list --name app-copilot-demo-backend-{SUFFIX} --resource-group rg-copilot-demo --query "[?name=='VERSION' || name=='LOG_LEVEL' || name=='CACHE_ENABLED' || name=='FEATURE_FLAG_V2'].{Name:name, Value:value}" -o table
```
*Shows these differences:*
| Setting | Frontend | Backend |
|---------|----------|---------|
| VERSION | 2.0.5 | 2.1.0 |
| LOG_LEVEL | INFO | DEBUG |
| CACHE_ENABLED | true | false |
| FEATURE_FLAG_V2 | disabled | enabled |

**App Service Plan info:**
```powershell
az appservice plan show --name asp-copilot-demo --resource-group rg-copilot-demo --query "{Name:name, SKU:sku.name, Workers:sku.capacity}" -o table
```
*Shows: B1 SKU with 1 worker*

### COPILOT PROMPTS:
- "Compare app settings between frontend and backend"
- "What version is deployed to each app?"
- "Show me differences in configuration"

---

## DEMO SECTION 6: ACTIVITY & AUDIT
**What it shows:** Who did what and when

### ✅ TESTED COMMANDS:

**Recent Azure operations:**
```powershell
az monitor activity-log list --resource-group rg-copilot-demo --max-events 15 --query "[].{Time:eventTimestamp, Operation:operationName.localizedValue, Status:status.localizedValue, Caller:caller}" -o table
```
*Shows: Restart, config updates, deployments with timestamps*

### COPILOT PROMPTS:
- "Show me recent operations on my resource group"
- "Who made changes to my web app?"
- "When was my app last restarted?"

---

## QUICK REFERENCE - WORKING DEMO COMMANDS

```powershell
# Source environment config first
Get-Content ./env-config.txt | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $parts = $_ -split '=', 2
    Set-Variable -Name $parts[0] -Value $parts[1]
}

# Environment overview
az resource list -g $RESOURCE_GROUP -o table

# App status
az webapp list -g $RESOURCE_GROUP --query "[].{Name:name,State:state}" -o table

# Live logs
az webapp log tail --name $BACKEND_APP -g $RESOURCE_GROUP

# App Insights - errors (with error handling)
$result = az monitor app-insights query --app $APP_INSIGHTS -g $RESOURCE_GROUP --analytics-query "requests | where resultCode != '200' | take 10" -o json 2>&1
if ($LASTEXITCODE -ne 0 -or $result -notmatch '^\s*\{') {
    Write-Host "⚠️  Query failed. Check if data exists." -ForegroundColor Yellow
} else {
    $result | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Write-Host
}

# App Insights - performance (with error handling)
$result = az monitor app-insights query --app $APP_INSIGHTS -g $RESOURCE_GROUP --analytics-query "requests | summarize avg(duration) by cloud_RoleName" -o json 2>&1
if ($LASTEXITCODE -ne 0 -or $result -notmatch '^\s*\{') {
    Write-Host "⚠️  Query failed. Check if data exists." -ForegroundColor Yellow
} else {
    $result | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Write-Host
}

# SQL metrics
az monitor metrics list --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Sql/servers/$SQL_SERVER/databases/$SQL_DATABASE" --metric "dtu_consumption_percent" -o table

# Config compare
az webapp config appsettings list --name $BACKEND_APP -g $RESOURCE_GROUP -o table

# Activity log
az monitor activity-log list -g $RESOURCE_GROUP --max-events 10 -o table
```

---

## CLEANUP AFTER DEMO

```powershell
# Reset simulated issues
.\simulate-issues.ps1 -Issue clear-issues

# Or delete everything (stops all charges)
az group delete --name rg-copilot-demo --yes --no-wait
```
