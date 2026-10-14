# oc-proxy-test.ps1 — verify your DataImpulse proxy works and print the exit IP
# Loads config/dataimpulse.local.env if present, else env vars must be set.
# Usage: oc-proxy-test.ps1 [-Mode rotate|sticky] [-Socks] [-Url https://api.ipify.org?format=json]
param(
    [ValidateSet("rotate", "sticky")][string]$Mode = "rotate",
    [switch]$Socks,
    [string]$Url = "https://api.ipify.org?format=json"
)
$ErrorActionPreference = "Stop"
$stack = "D:\Code\Data Scraping"

# Load local env file if it exists (gitignored)
$localEnv = Join-Path $stack "config\dataimpulse.local.env"
if (Test-Path $localEnv) {
    Get-Content $localEnv | ForEach-Object {
        if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+?)\s*$') {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim('"'), "Process")
        }
    }
}

$host_ = $env:DATAIMPULSE_HOST; $login = $env:DATAIMPULSE_LOGIN; $pass = $env:DATAIMPULSE_PASSWORD
if (-not ($host_ -and $login -and $pass)) {
    Write-Host "Missing credentials. Copy config\dataimpulse.env.example -> config\dataimpulse.local.env and fill it in." -ForegroundColor Red
    exit 1
}

$port = if ($Mode -eq "rotate") {
    if ($Socks) { $env:DATAIMPULSE_ROTATE_SOCKS_PORT } else { $env:DATAIMPULSE_ROTATE_HTTP_PORT }
} else { $env:DATAIMPULSE_STICKY_PORT }
if (-not $port) { $port = if ($Mode -eq "rotate") { 823 } else { 10000 } }

# Build targeting suffix: LOGIN__cr.CC;sessttl.MIN:PASSWORD
$cc = $env:DATAIMPULSE_COUNTRY; $ttl = $env:DATAIMPULSE_SESSION_TTL
$target = @()
if ($cc) { $target += "cr.$cc" }
if ($Mode -eq "rotate" -and $ttl) { $target += "sessttl.$ttl" }
$suffix = if ($target) { "__" + ($target -join ";") } else { "" }
$user = "$login$suffix"
$scheme = if ($Socks) { "socks5" } else { "http" }
$proxyUrl = "$scheme://${user}:${pass}@${host_}:${port}"

Write-Host "Testing $Mode proxy ($scheme) -> $Url ..." -ForegroundColor Cyan
try {
    $resp = Invoke-WebRequest -Uri $Url -Proxy $proxyUrl -TimeoutSec 30 -UseBasicParsing
    Write-Host "OK (HTTP $($resp.StatusCode))" -ForegroundColor Green
    Write-Host "Exit IP/body: $($resp.Content)"
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
