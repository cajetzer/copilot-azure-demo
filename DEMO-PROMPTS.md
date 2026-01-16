# Copilot Demo - Tested Commands & Prompts
## All commands verified working as of January 13, 2026

> **Note:** Commands below use `{SUFFIX}` as a placeholder. Replace it with your actual suffix value from `env-config.txt` (e.g., if your frontend app is `app-copilot-demo-frontend-12345`, use `12345` as the suffix).

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
az monitor app-insights query --app ai-copilot-demo --resource-group rg-copilot-demo --analytics-query "requests | summarize count() by cloud_RoleName, resultCode | order by count_ desc"
```
*Shows: Count of 200s, 404s, etc. per app*

**Find 404 errors:**
```powershell
az monitor app-insights query --app ai-copilot-demo --resource-group rg-copilot-demo --analytics-query "requests | where resultCode == '404' | project timestamp, url, duration | order by timestamp desc | take 10"
```
*Shows: Recent 404 errors with URLs*

**Average response times per app:**
```powershell
az monitor app-insights query --app ai-copilot-demo --resource-group rg-copilot-demo --analytics-query "requests | summarize avgDuration=avg(duration), count=count() by cloud_RoleName | order by avgDuration desc"
```
*Shows: Backend ~33ms, Frontend ~22ms average*

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
# Environment overview
az resource list -g rg-copilot-demo -o table

# App status
az webapp list -g rg-copilot-demo --query "[].{Name:name,State:state}" -o table

# Live logs
az webapp log tail --name app-copilot-demo-backend-{SUFFIX} -g rg-copilot-demo

# App Insights - errors
az monitor app-insights query --app ai-copilot-demo -g rg-copilot-demo --analytics-query "requests | where resultCode != '200' | take 10"

# App Insights - performance
az monitor app-insights query --app ai-copilot-demo -g rg-copilot-demo --analytics-query "requests | summarize avg(duration) by cloud_RoleName"

# SQL metrics
az monitor metrics list --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-copilot-demo/providers/Microsoft.Sql/servers/sql-copilot-demo-{SUFFIX}/databases/appdb" --metric "dtu_consumption_percent" -o table

# Config compare
az webapp config appsettings list --name app-copilot-demo-backend-{SUFFIX} -g rg-copilot-demo -o table

# Activity log
az monitor activity-log list -g rg-copilot-demo --max-events 10 -o table
```

---

## CLEANUP AFTER DEMO

```powershell
# Reset simulated issues
.\simulate-issues.ps1 -Issue clear-issues

# Or delete everything (stops all charges)
az group delete --name rg-copilot-demo --yes --no-wait
```
