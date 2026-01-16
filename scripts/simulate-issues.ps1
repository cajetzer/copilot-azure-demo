# ============================================================
# Issue Simulator for Copilot Demo
# ============================================================
# Creates specific, observable issues for troubleshooting demos
# ============================================================

param(
    [string]$Issue = "menu"
)

# Load configuration from env-config.txt if available
if (Test-Path "env-config.txt") {
    $config = Get-Content "env-config.txt" | Where-Object { $_ -match '=' -and $_ -notmatch '^#' }
    $configHash = @{}
    foreach ($line in $config) {
        $parts = $line -split '=', 2
        $configHash[$parts[0].Trim()] = $parts[1].Trim()
    }
    
    $RESOURCE_GROUP = $configHash['RESOURCE_GROUP']
    $FRONTEND_APP = $configHash['FRONTEND_APP']
    $BACKEND_APP = $configHash['BACKEND_APP']
    $SQL_SERVER = $configHash['SQL_SERVER']
    $APP_INSIGHTS = $configHash['APP_INSIGHTS']
} else {
    Write-Host "ERROR: env-config.txt not found!" -ForegroundColor Red
    Write-Host "Please run deploy.ps1 first to generate the configuration file." -ForegroundColor Yellow
    exit 1
}

function Show-Menu {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Copilot Demo - Issue Simulator" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Choose an issue to simulate:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] http-errors    - Generate 404/500 HTTP errors"
    Write-Host "  [2] high-latency   - Cause slow response times"
    Write-Host "  [3] app-restart    - Restart the app (causes brief outage)"
    Write-Host "  [4] config-change  - Change app configuration"
    Write-Host "  [5] scale-down     - Reduce app resources"
    Write-Host "  [6] bad-config     - Add invalid app setting"
    Write-Host "  [7] clear-issues   - Reset/fix all simulated issues"
    Write-Host ""
    Write-Host "  [A] all-issues     - Simulate multiple issues at once"
    Write-Host "  [Q] quit           - Exit"
    Write-Host ""
}

function Simulate-HTTPErrors {
    Write-Host ""
    Write-Host "[SIMULATING] HTTP Errors..." -ForegroundColor Yellow
    Write-Host ""
    
    # Generate a burst of error requests
    $errorUrls = @(
        "https://$BACKEND_APP.azurewebsites.net/api/nonexistent",
        "https://$BACKEND_APP.azurewebsites.net/crash",
        "https://$BACKEND_APP.azurewebsites.net/error/500",
        "https://$FRONTEND_APP.azurewebsites.net/missing-page",
        "https://$FRONTEND_APP.azurewebsites.net/api/undefined"
    )
    
    for ($i = 1; $i -le 25; $i++) {
        $url = $errorUrls | Get-Random
        try {
            Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null
        } catch {
            $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { "Timeout" }
            Write-Host "  [$i/25] $status - $url" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host ""
    Write-Host "[DONE] Errors generated! Ask Copilot:" -ForegroundColor Green
    Write-Host '  @terminal "Show me HTTP errors from my web apps"' -ForegroundColor Cyan
    Write-Host '  @terminal "Query Application Insights for failed requests in the last 5 minutes"' -ForegroundColor Cyan
}

function Simulate-HighLatency {
    Write-Host ""
    Write-Host "[SIMULATING] High Latency Requests..." -ForegroundColor Yellow
    Write-Host ""
    
    # Make requests that will be slow (App Service cold start, etc.)
    Write-Host "  Generating slow requests (cold starts, timeouts)..." -ForegroundColor Gray
    
    for ($i = 1; $i -le 10; $i++) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            # This will be slow due to cold start or non-existent endpoints
            $response = Invoke-WebRequest -Uri "https://$BACKEND_APP.azurewebsites.net/api/slow-operation?delay=$($i * 1000)" -TimeoutSec 30 -UseBasicParsing -ErrorAction SilentlyContinue
            $stopwatch.Stop()
            Write-Host "  [$i/10] $($stopwatch.ElapsedMilliseconds)ms - Response received" -ForegroundColor Yellow
        } catch {
            $stopwatch.Stop()
            Write-Host "  [$i/10] $($stopwatch.ElapsedMilliseconds)ms - Timeout/Error" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "[DONE] Latency issues generated! Ask Copilot:" -ForegroundColor Green
    Write-Host '  @terminal "Show me slow requests from my backend app"' -ForegroundColor Cyan
    Write-Host '  @terminal "What is the average response time for my API?"' -ForegroundColor Cyan
}

function Simulate-AppRestart {
    Write-Host ""
    Write-Host "[SIMULATING] Application Restart..." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "  Restarting backend app..." -ForegroundColor Gray
    az webapp restart --name $BACKEND_APP --resource-group $RESOURCE_GROUP
    
    Write-Host ""
    Write-Host "[DONE] App restarted! This creates:" -ForegroundColor Green
    Write-Host "  - Brief availability gap in logs" -ForegroundColor White
    Write-Host "  - Cold start latency on next request" -ForegroundColor White
    Write-Host ""
    Write-Host "Ask Copilot:" -ForegroundColor Cyan
    Write-Host '  @terminal "When was my app last restarted?"' -ForegroundColor Cyan
    Write-Host '  @terminal "Show me app service activity logs"' -ForegroundColor Cyan
}

function Simulate-ConfigChange {
    Write-Host ""
    Write-Host "[SIMULATING] Configuration Change..." -ForegroundColor Yellow
    Write-Host ""
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "  Adding new app settings..." -ForegroundColor Gray
    az webapp config appsettings set --name $BACKEND_APP --resource-group $RESOURCE_GROUP --settings DEMO_CHANGED="$timestamp" LOG_LEVEL="DEBUG" FEATURE_FLAG_NEW="enabled" --output none
    
    Write-Host ""
    Write-Host "[DONE] Configuration changed! Ask Copilot:" -ForegroundColor Green
    Write-Host '  @terminal "Show me app settings for my backend app"' -ForegroundColor Cyan
    Write-Host '  @terminal "Compare settings between frontend and backend"' -ForegroundColor Cyan
}

function Simulate-ScaleDown {
    Write-Host ""
    Write-Host "[SIMULATING] Resource Constraint (cannot scale B1 further)..." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "  Note: B1 tier is already minimal. Showing current plan..." -ForegroundColor Gray
    az appservice plan show --name asp-copilot-demo --resource-group $RESOURCE_GROUP --query "{Name:name, Sku:sku.name, Workers:sku.capacity}" --output table
    
    Write-Host ""
    Write-Host "[INFO] To demo resource constraints, ask Copilot:" -ForegroundColor Green
    Write-Host '  @terminal "Show me CPU and memory usage for my App Service"' -ForegroundColor Cyan
    Write-Host '  @terminal "Is my app running out of resources?"' -ForegroundColor Cyan
}

function Simulate-BadConfig {
    Write-Host ""
    Write-Host "[SIMULATING] Bad Configuration..." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "  Adding problematic app settings..." -ForegroundColor Gray
    az webapp config appsettings set --name $BACKEND_APP --resource-group $RESOURCE_GROUP --settings DATABASE_CONNECTION="INVALID_CONNECTION_STRING" API_TIMEOUT="-1" --output none
    
    Write-Host ""
    Write-Host "[DONE] Bad config added! Ask Copilot:" -ForegroundColor Green
    Write-Host '  @terminal "Show me app settings for my backend"' -ForegroundColor Cyan
    Write-Host '  @terminal "Are there any configuration issues?"' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  To fix: Run .\simulate-issues.ps1 -Issue clear-issues" -ForegroundColor Yellow
}

function Clear-AllIssues {
    Write-Host ""
    Write-Host "[CLEARING] Resetting all simulated issues..." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "  Removing bad/demo app settings..." -ForegroundColor Gray
    az webapp config appsettings delete --name $BACKEND_APP --resource-group $RESOURCE_GROUP --setting-names DEMO_CHANGED LOG_LEVEL FEATURE_FLAG_NEW DATABASE_CONNECTION API_TIMEOUT --output none 2>$null
    
    Write-Host "  Restarting apps to clear state..." -ForegroundColor Gray
    az webapp restart --name $BACKEND_APP --resource-group $RESOURCE_GROUP --output none
    az webapp restart --name $FRONTEND_APP --resource-group $RESOURCE_GROUP --output none
    
    Write-Host ""
    Write-Host "[DONE] All issues cleared! Environment reset." -ForegroundColor Green
}

function Simulate-AllIssues {
    Write-Host ""
    Write-Host "[RUNNING] All issue simulations..." -ForegroundColor Yellow
    Write-Host ""
    
    Simulate-HTTPErrors
    Start-Sleep -Seconds 2
    
    Simulate-HighLatency
    Start-Sleep -Seconds 2
    
    Simulate-ConfigChange
    
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  All issues simulated! Ready for troubleshooting demo." -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
}

# Main execution
switch ($Issue.ToLower()) {
    "menu" { 
        Show-Menu
        $choice = Read-Host "Enter choice"
        switch ($choice) {
            "1" { Simulate-HTTPErrors }
            "http-errors" { Simulate-HTTPErrors }
            "2" { Simulate-HighLatency }
            "high-latency" { Simulate-HighLatency }
            "3" { Simulate-AppRestart }
            "app-restart" { Simulate-AppRestart }
            "4" { Simulate-ConfigChange }
            "config-change" { Simulate-ConfigChange }
            "5" { Simulate-ScaleDown }
            "scale-down" { Simulate-ScaleDown }
            "6" { Simulate-BadConfig }
            "bad-config" { Simulate-BadConfig }
            "7" { Clear-AllIssues }
            "clear-issues" { Clear-AllIssues }
            "A" { Simulate-AllIssues }
            "a" { Simulate-AllIssues }
            "all-issues" { Simulate-AllIssues }
            "Q" { Write-Host "Exiting..." -ForegroundColor Gray }
            "q" { Write-Host "Exiting..." -ForegroundColor Gray }
            default { Write-Host "Invalid choice" -ForegroundColor Red }
        }
    }
    "http-errors" { Simulate-HTTPErrors }
    "high-latency" { Simulate-HighLatency }
    "app-restart" { Simulate-AppRestart }
    "config-change" { Simulate-ConfigChange }
    "scale-down" { Simulate-ScaleDown }
    "bad-config" { Simulate-BadConfig }
    "clear-issues" { Clear-AllIssues }
    "all-issues" { Simulate-AllIssues }
    default { 
        Write-Host "Unknown issue type: $Issue" -ForegroundColor Red
        Show-Menu
    }
}
