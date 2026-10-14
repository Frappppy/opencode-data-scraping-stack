# oc-robots.ps1 — fetch and summarize robots.txt for a domain
# Load this BEFORE crawling any site. AGENTS.md requires it.
# Usage: oc-robots.ps1 https://example.com
param(
    [Parameter(Mandatory = $true)][string]$Url
)
$ErrorActionPreference = "Stop"
$uri = [Uri]$Url
$robotsUrl = "$($uri.Scheme)://$($uri.Host)/robots.txt"
Write-Host "Fetching $robotsUrl" -ForegroundColor Cyan
try {
    $robots = (Invoke-WebRequest -Uri $robotsUrl -TimeoutSec 15 -UseBasicParsing).Content
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "No robots.txt (404) -> default: crawl allowed, be polite." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "FETCH FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host "`n===== robots.txt =====" -ForegroundColor Green
Write-Host $robots
Write-Host "===== summary =====" -ForegroundColor Green
$lines = $robots -split "`n"
$disallowAll = $false
foreach ($l in $lines) {
    $t = $l.Trim()
    if ($t -match '^(User-agent|Disallow|Allow|Crawl-delay|Sitemap)\s*:\s*(.*)$') {
        Write-Host ("  {0,-12} {1}" -f $Matches[1], $Matches[2].Trim())
        if ($t -match '^User-agent\s*:\s*\*' -or ($t -match '^Disallow\s*:\s*/\s*$')) { if ($t -match '^Disallow\s*:\s*/\s*$') { $disallowAll = $true } }
    }
}
if ($disallowAll) { Write-Host "`nWARNING: site disallows all crawlers for *. Do not crawl without explicit permission." -ForegroundColor Red }
else { Write-Host "`nRemember: obey Crawl-delay and per-path Disallows. Log this file into your job dir." -ForegroundColor Yellow }
