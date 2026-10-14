# oc-scrape.ps1 — quick single-page scrape via crawl4ai (venv)
# Usage: oc-scrape.ps1 https://example.com [markdown|json]
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [string]$Format = "markdown"
)
$ErrorActionPreference = "Stop"
$stack = "D:\Code\Data Scraping"
$py = Join-Path $stack ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Host "venv missing. Run: powershell -File $stack\install.ps1" -ForegroundColor Red
    exit 1
}
& $py (Join-Path $stack "scripts\starter_crawl4ai.py") $Url
