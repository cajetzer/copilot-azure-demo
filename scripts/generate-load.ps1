# ============================================================
# Load Generator for Copilot Demo
# ============================================================
# This script generates traffic and simulates issues for demo
# ============================================================

param(
    [string]$Scenario = "all",
    [int]$Duration = 60,
    [int]$Concurrency = 5
)

# Load configuration from env-config.txt if available
if (Test-Path "env-config.txt") {
    $config = Get-Content "env-config.txt" | Where-Object { $_ -match '=' -and $_ -notmatch '^#' }
    $configHash = @{}
    foreach ($line in $config) {
        $parts = $line -split '=', 2
        $configHash[$parts[0].Trim()] = $parts[1].Trim()
    }
    
    $FRONTEND_URL = $configHash['FRONTEND_URL']
    $BACKEND_URL = $configHash['BACKEND_URL']
    $RESOURCE_GROUP = $configHash['RESOURCE_GROUP']
    $SQL_SERVER = $configHash['SQL_SERVER']
    $SQL_DB = $configHash['SQL_DATABASE']
    $APP_INSIGHTS = $configHash['APP_INSIGHTS']
} else {
    Write-Host "ERROR: env-config.txt not found!" -ForegroundColor Red
    Write-Host "Please run deploy.ps1 first to generate the configuration file." -ForegroundColor Yellow
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Copilot Demo - Load & Issue Generator" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Scenarios available:" -ForegroundColor Yellow
Write-Host "  1. traffic    - Generate HTTP traffic to web apps"
Write-Host "  2. errors     - Generate HTTP errors (404, 500)"
Write-Host "  3. slow       - Simulate slow responses"
Write-Host "  4. sql        - Generate SQL activity"
Write-Host "  5. logs       - Generate application logs"
Write-Host "  6. all        - Run all scenarios"
Write-Host ""
Write-Host "Usage: .\generate-load.ps1 -Scenario <name> -Duration <seconds>" -ForegroundColor Gray
Write-Host ""

function Generate-Traffic {
    param([int]$Seconds = 30, [int]$Concurrent = 5)
    
    Write-Host "[TRAFFIC] Generating HTTP traffic for $Seconds seconds..." -ForegroundColor Yellow
    
    $endpoints = @(
        "$FRONTEND_URL/",
        "$FRONTEND_URL/api/health",
        "$BACKEND_URL/",
        "$BACKEND_URL/api/health"
    )
    
    $endTime = (Get-Date).AddSeconds($Seconds)
    $requestCount = 0
    
    while ((Get-Date) -lt $endTime) {
        $jobs = @()
        for ($i = 0; $i -lt $Concurrent; $i++) {
            $url = $endpoints | Get-Random
            $jobs += Start-Job -ScriptBlock {
                param($u)
                try {
                    $response = Invoke-WebRequest -Uri $u -TimeoutSec 10 -UseBasicParsing
                    return @{ Url = $u; Status = $response.StatusCode; Success = $true }
                } catch {
                    return @{ Url = $u; Status = 0; Success = $false; Error = $_.Exception.Message }
                }
            } -ArgumentList $url
        }
        
        $results = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
        
        foreach ($r in $results) {
            $requestCount++
            if ($r.Success) {
                Write-Host "  [$requestCount] $($r.Url) -> $($r.Status)" -ForegroundColor Green
            } else {
                Write-Host "  [$requestCount] $($r.Url) -> ERROR" -ForegroundColor Red
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "[TRAFFIC] Complete - $requestCount requests sent" -ForegroundColor Green
}

function Generate-Errors {
    param([int]$Count = 20)
    
    Write-Host "[ERRORS] Generating HTTP errors..." -ForegroundColor Yellow
    
    $errorEndpoints = @(
        "$FRONTEND_URL/nonexistent-page-404",
        "$FRONTEND_URL/api/undefined-endpoint",
        "$BACKEND_URL/api/crash",
        "$BACKEND_URL/api/timeout",
        "$BACKEND_URL/throw-error",
        "$FRONTEND_URL/missing/deeply/nested/path"
    )
    
    for ($i = 1; $i -le $Count; $i++) {
        $url = $errorEndpoints | Get-Random
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
            Write-Host "  [$i] $url -> $($response.StatusCode)" -ForegroundColor Yellow
        } catch {
            $statusCode = 0
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            Write-Host "  [$i] $url -> $statusCode (Error)" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 200
    }
    
    Write-Host "[ERRORS] Complete - $Count error requests sent" -ForegroundColor Green
}

function Generate-SlowRequests {
    param([int]$Count = 10)
    
    Write-Host "[SLOW] Simulating slow requests..." -ForegroundColor Yellow
    
    # These requests will naturally be slow or timeout
    $slowEndpoints = @(
        "$BACKEND_URL/api/slow?delay=5000",
        "$BACKEND_URL/api/heavy-computation",
        "$FRONTEND_URL/api/large-payload"
    )
    
    for ($i = 1; $i -le $Count; $i++) {
        $url = $slowEndpoints | Get-Random
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 30 -UseBasicParsing -ErrorAction SilentlyContinue
            $stopwatch.Stop()
            Write-Host "  [$i] $url -> $($response.StatusCode) ($($stopwatch.ElapsedMilliseconds)ms)" -ForegroundColor Yellow
        } catch {
            $stopwatch.Stop()
            Write-Host "  [$i] $url -> Timeout/Error ($($stopwatch.ElapsedMilliseconds)ms)" -ForegroundColor Red
        }
    }
    
    Write-Host "[SLOW] Complete" -ForegroundColor Green
}

function Generate-SQLActivity {
    Write-Host "[SQL] Generating SQL database activity..." -ForegroundColor Yellow
    
    # Query database metrics
    Write-Host "  Querying database metrics..." -ForegroundColor Gray
    
    $query = @"
SELECT TOP 10 
    r.session_id,
    r.status,
    r.command,
    r.wait_type,
    r.cpu_time,
    r.total_elapsed_time
FROM sys.dm_exec_requests r
WHERE r.session_id > 50
ORDER BY r.cpu_time DESC
"@
    
    # Use az sql to run queries (requires Azure AD auth token)
    Write-Host "  Note: SQL uses Azure AD authentication" -ForegroundColor Gray
    Write-Host "  Run this to connect: az sql db connect --name appdb --server sql-copilot-demo-10084" -ForegroundColor Cyan
    
    # Generate some activity by checking metrics
    Write-Host "  Fetching SQL metrics..." -ForegroundColor Gray
    az monitor metrics list --resource "/subscriptions/34f82e2f-412d-4355-8c44-6e87749f4e37/resourceGroups/rg-copilot-demo/providers/Microsoft.Sql/servers/sql-copilot-demo-10084/databases/appdb" --metric "dtu_consumption_percent" --interval PT1M --output table 2>$null
    
    Write-Host "[SQL] Complete" -ForegroundColor Green
}

function Generate-Logs {
    param([int]$Seconds = 30)
    
    Write-Host "[LOGS] Generating application log entries for $Seconds seconds..." -ForegroundColor Yellow
    Write-Host "  Sending requests to generate log entries..." -ForegroundColor Gray
    
    $endTime = (Get-Date).AddSeconds($Seconds)
    $count = 0
    
    while ((Get-Date) -lt $endTime) {
        $count++
        
        # Generate various types of requests that will create different log levels
        $scenarios = @(
            @{ Url = "$BACKEND_URL/"; Type = "INFO" },
            @{ Url = "$BACKEND_URL/api/health"; Type = "INFO" },
            @{ Url = "$BACKEND_URL/api/not-found"; Type = "WARN" },
            @{ Url = "$BACKEND_URL/api/error"; Type = "ERROR" }
        )
        
        $scenario = $scenarios | Get-Random
        
        try {
            Invoke-WebRequest -Uri $scenario.Url -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  [$count] $($scenario.Type): $($scenario.Url)" -ForegroundColor Gray
        } catch {
            Write-Host "  [$count] $($scenario.Type): $($scenario.Url) (expected)" -ForegroundColor Gray
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "[LOGS] Complete - $count log entries generated" -ForegroundColor Green
    Write-Host ""
    Write-Host "View logs with:" -ForegroundColor Cyan
    Write-Host "  az webapp log tail --name app-backend-10084 --resource-group rg-copilot-demo" -ForegroundColor White
}

# Main execution
Write-Host "Starting scenario: $Scenario" -ForegroundColor Cyan
Write-Host ""

switch ($Scenario.ToLower()) {
    "traffic" { Generate-Traffic -Seconds $Duration -Concurrent $Concurrency }
    "errors" { Generate-Errors -Count 20 }
    "slow" { Generate-SlowRequests -Count 10 }
    "sql" { Generate-SQLActivity }
    "logs" { Generate-Logs -Seconds $Duration }
    "all" {
        Generate-Traffic -Seconds 15 -Concurrent 3
        Write-Host ""
        Generate-Errors -Count 15
        Write-Host ""
        Generate-SlowRequests -Count 5
        Write-Host ""
        Generate-Logs -Seconds 15
        Write-Host ""
        Generate-SQLActivity
    }
    default {
        Write-Host "Unknown scenario: $Scenario" -ForegroundColor Red
        Write-Host "Valid scenarios: traffic, errors, slow, sql, logs, all" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Load generation complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now use Copilot to investigate:" -ForegroundColor Cyan
Write-Host '  @terminal "Show me errors from my web app in the last 10 minutes"' -ForegroundColor White
Write-Host '  @terminal "Query App Insights for failed requests"' -ForegroundColor White
Write-Host '  @terminal "Stream logs from my backend app"' -ForegroundColor White
Write-Host ""
