# 🚀 VS Code + GitHub Copilot: Azure Troubleshooting Demo

[![Azure](https://img.shields.io/badge/Azure-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com)
[![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/features/copilot)
[![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://code.visualstudio.com)

> **Transform Azure infrastructure troubleshooting from CLI expertise to natural conversation**

## 📋 Executive Summary

This project demonstrates how **GitHub Copilot in VS Code's terminal** transforms infrastructure troubleshooting from a specialized skill into a conversational experience—enabling engineers to diagnose issues across a full application stack using natural language.

### 💼 Business Value

| Benefit | Impact |
|---------|--------|
| **Faster MTTR** | Engineers don't need to memorize CLI commands |
| **Knowledge Democratization** | Junior staff can troubleshoot like seniors |
| **Reduced Context Switching** | Stay in VS Code for code *and* operations |
| **Audit-Ready** | All commands are visible and reproducible |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AZURE RESOURCE GROUP                               │
│                           rg-copilot-demo                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────┐      ┌─────────────────┐      ┌─────────────────┐         │
│   │   TIER 1    │      │     TIER 2      │      │     TIER 3      │         │
│   │  Frontend   │      │   Application   │      │    Database     │         │
│   ├─────────────┤      ├─────────────────┤      ├─────────────────┤         │
│   │             │      │                 │      │                 │         │
│   │ App Service │ ───▶ │  App Service    │ ───▶ │  Azure SQL DB   │         │
│   │  (Web UI)   │      │   (Node.js)     │      │   (Basic tier)  │         │
│   │   FREE/B1   │      │      B1         │      │                 │         │
│   │             │      │                 │      │                 │         │
│   └─────────────┘      └─────────────────┘      └─────────────────┘         │
│          │                     │                        │                    │
│          └─────────────────────┴────────────────────────┘                    │
│                                │                                             │
│                    ┌───────────┴───────────┐                                 │
│                    │  Application Insights │                                 │
│                    │  (Full Stack Tracing) │                                 │
│                    └───────────────────────┘                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Cost Estimate (5 Days)

| Resource | SKU | Daily Cost | 5-Day Cost |
|----------|-----|------------|------------|
| App Service Plan | B1 (shared by 2 apps) | ~$0.075/hr × 24 = $1.80 | $9.00 |
| Azure SQL Database | Basic (5 DTU) | ~$0.0067/hr × 24 = $0.16 | $0.80 |
| Application Insights | Pay-as-you-go | ~$2.30/GB (minimal data) | ~$5.00 |
| Storage Account | Standard LRS | Minimal | ~$0.10 |
| **TOTAL ESTIMATE** | | | **~$15 - $25** |

> ⚠️ **Note**: Actual costs may vary. Delete resources after demo to stop charges.

---

## Deployed Resources

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `rg-copilot-demo` | Container for all resources |
| App Service Plan | `asp-copilot-demo` | Hosts both web apps (B1 tier) |
| Frontend Web App | `app-copilot-demo-frontend-10084` | User-facing web interface |
| Backend API App | `app-copilot-demo-backend-10084` | REST API with SQL connectivity |
| SQL Server | `sql-copilot-demo-10084` | Azure SQL logical server (Azure AD auth) |
| SQL Database | `appdb` | Application database (Basic tier) |
| Application Insights | `ai-copilot-demo` | Monitoring and tracing |
| Storage Account | `st10084` | Logs and diagnostics |

### Live URLs

- **Frontend**: https://app-copilot-demo-frontend-10084.azurewebsites.net
- **Backend API**: https://app-copilot-demo-backend-10084.azurewebsites.net
- **SQL Server**: sql-copilot-demo-10084.database.windows.net

---

## Quick Start

### Prerequisites

- **Azure Developer CLI** (`azd`) installed: https://aka.ms/azd-install
- **Azure CLI** installed and logged in (`az login`)
- VS Code with GitHub Copilot extension
- PowerShell 7+ or Bash terminal
- Shell integration enabled (already configured)

### Deploy with Azure Developer CLI (Recommended)

```powershell
# Set required Entra ID admin for SQL Server
$adminUpn = "your-admin@yourtenant.onmicrosoft.com"  # Your Entra ID UPN
$adminObjectId = az ad user show --id $adminUpn --query id -o tsv

# Provision infrastructure using Bicep
azd provision --parameter sqlAdminPrincipalId=$adminObjectId --parameter sqlAdminLogin=$adminUpn
```

**What `azd provision` does:**
1. Validates Bicep templates in `infra/`
2. Creates/updates Azure resources: App Service Plan, Web Apps, SQL Server (Azure AD auth), Application Insights, Storage Account, Managed Identity
3. Populates outputs (URLs, keys, database FQDN)
4. Runs `scripts/azd-post-provision.ps1` to generate `env-config.txt` for backwards compatibility

**Optional: Deploy application code**
```powershell
azd deploy
```

### Deploy with Legacy Script (Deprecated)

```powershell
# Old method (still supported for backwards compatibility)
.\scripts\deploy.ps1
```

### Generate Issues for Demo

```powershell
# First, ensure env-config.txt is populated from azd outputs
# (azd post-provision automatically generates this)

# Interactive menu to simulate issues
.\scripts\simulate-issues.ps1

# Or run specific scenarios:
.\scripts\simulate-issues.ps1 -Issue http-errors    # Generate 404/500 errors
.\scripts\simulate-issues.ps1 -Issue high-latency   # Cause slow responses
.\scripts\simulate-issues.ps1 -Issue config-change  # Modify app settings
.\scripts\simulate-issues.ps1 -Issue all-issues     # Run all simulations
.\scripts\simulate-issues.ps1 -Issue clear-issues   # Reset everything
```

### Generate Load/Traffic

```powershell
# Generate traffic and activity (populates Application Insights)
.\scripts\generate-load.ps1 -Scenario all          # All scenarios
.\scripts\generate-load.ps1 -Scenario traffic      # HTTP traffic only
.\scripts\generate-load.ps1 -Scenario errors       # Error requests only
.\scripts\generate-load.ps1 -Scenario logs         # Generate log entries
```

### Cleanup

```powershell
# Option 1: Use azd (removes all azd-provisioned resources)
azd down

# Option 2: Use Azure CLI (delete resource group)
az group delete --name rg-copilot-demo --yes --no-wait
```

---

## Demo Flow

### Duration: 15-20 minutes

### 🔴 BEFORE DEMO: Generate Test Data
```powershell
.\simulate-issues.ps1 -Issue all-issues
```
*Wait 2-3 minutes for App Insights data to populate*

### ACT 1: Environment Discovery (3 min)

| Step | Ask Copilot | What It Shows | Verified ✅ |
|------|-------------|---------------|-------------|
| 1.1 | "Show me all resources in my Azure resource group rg-copilot-demo" | 10 resources: 2 web apps, SQL, App Insights, etc. | ✅ |
| 1.2 | "Check if my web apps are running" | Both apps show "Running" state | ✅ |
| 1.3 | "Is my SQL database online?" | State = Ready, FQDN displayed | ✅ |

### ACT 2: Frontend Troubleshooting (4 min)

| Step | Ask Copilot | What It Shows | Verified ✅ |
|------|-------------|---------------|-------------|
| 2.1 | "Stream live logs from my frontend app service" | Real-time log stream | ✅ |
| 2.2 | "Show me recent operations on my web app" | Restarts, config changes | ✅ |
| 2.3 | "Show me HTTP request metrics for my frontend" | 2xx, 4xx counts | ✅ |

### ACT 3: Backend/API Investigation (4 min)

| Step | Ask Copilot | What It Shows | Verified ✅ |
|------|-------------|---------------|-------------|
| 3.1 | "Query App Insights for 404 errors" | URLs that returned 404 | ✅ |
| 3.2 | "What's the average response time for my API?" | ~33ms backend, ~22ms frontend | ✅ |
| 3.3 | "Show me app settings for my backend" | LOG_LEVEL=DEBUG, VERSION=2.1.0 | ✅ |

### ACT 4: Database Deep Dive (4 min)

| Step | Ask Copilot | What It Shows | Verified ✅ |
|------|-------------|---------------|-------------|
| 4.1 | "Show me DTU usage for my Azure SQL database" | DTU percentage (0-1% when idle) | ✅ |
| 4.2 | "List firewall rules for my SQL server" | AllowAzureServices, AllowMyIP | ✅ |
| 4.3 | "What's my database size and status?" | Basic, 2GB, Online | ✅ |

### ACT 5: Config Comparison (3 min)

| Step | Ask Copilot | What It Shows | Verified ✅ |
|------|-------------|---------------|-------------|
| 5.1 | "Compare app settings between frontend and backend" | VERSION, LOG_LEVEL, CACHE differences | ✅ |
| 5.2 | "Show me recent activity on my resource group" | Who did what, when | ✅ |

### Configuration Differences (Pre-loaded for Demo)

| Setting | Frontend | Backend |
|---------|----------|---------|
| VERSION | 2.0.5 | 2.1.0 |
| LOG_LEVEL | INFO | DEBUG |
| CACHE_ENABLED | true | false |
| FEATURE_FLAG_V2 | disabled | enabled |

---

## Sample Copilot Prompts

### System Monitoring
```
@terminal Show me CPU and memory usage for my App Service
@terminal Check disk I/O for my web app
@terminal Show me network traffic metrics
```

### User Access & Security
```
@terminal Show me who has accessed my SQL server
@terminal Check for failed login attempts
@terminal List active database sessions
```

### Configuration Management
```
@terminal Compare app settings between my frontend and backend
@terminal Show me environment variables for my web app
@terminal What version of Node.js is my backend running?
```

### Troubleshooting
```
@terminal Why is my API slow?
@terminal Show me errors from the last hour
@terminal Are there any blocking queries in my database?
```

---

## Environment Variables

After deployment, these values will be saved to `env-config.txt`:

- `RESOURCE_GROUP` - Azure resource group name
- `FRONTEND_URL` - Frontend application URL
- `BACKEND_URL` - Backend API URL
- `SQL_SERVER` - SQL Server hostname
- `SQL_DATABASE` - Database name
- `APP_INSIGHTS` - Application Insights name

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `az: command not found` | Install Azure CLI: https://aka.ms/installazurecli |
| Deployment fails | Check subscription permissions and quotas |
| SQL connection timeout | Verify firewall rules allow your IP |
| App Service not starting | Check `az webapp log tail` for errors |

### Useful Commands

```powershell
# Check deployment status
az group show --name rg-copilot-demo --query "properties.provisioningState"

# View recent deployments
az deployment group list --resource-group rg-copilot-demo -o table

# Get all resource IDs
az resource list --resource-group rg-copilot-demo --query "[].id" -o tsv
```

---

## Cleanup

**IMPORTANT**: Delete resources after your demo to avoid ongoing charges.

```powershell
# Delete everything in one command
az group delete --name rg-copilot-demo --yes --no-wait

# Verify deletion
az group exists --name rg-copilot-demo
```

---

## 📚 Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [GitHub Copilot in VS Code](https://docs.github.com/copilot)
- [Application Insights Overview](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure SQL Database](https://docs.microsoft.com/azure/azure-sql/)

---

## 📄 License

MIT License - This demo environment is provided for demonstration and educational purposes.

---

<p align="center">
  <b>Built with ❤️ for GitHub Copilot demos</b>
</p>
