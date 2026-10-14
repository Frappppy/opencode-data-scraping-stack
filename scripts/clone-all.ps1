# clone-all.ps1 — shallow-clone the full scraping stack
# Run from anywhere. Idempotent: skips dirs that already exist.
$ErrorActionPreference = "Continue"
$stack = Split-Path -Parent $PSScriptRoot
$base = Join-Path $stack "repos"

$repos = @(
    # --- core engines ---
    @{ url = "https://github.com/unclecode/crawl4ai.git";          dir = "core\crawl4ai" },
    @{ url = "https://github.com/firecrawl/firecrawl.git";         dir = "core\firecrawl" },
    @{ url = "https://github.com/apify/crawlee.git";               dir = "core\crawlee" },
    @{ url = "https://github.com/scrapy/scrapy.git";               dir = "core\scrapy" },
    @{ url = "https://github.com/D4Vinci/Scrapling.git";           dir = "core\scrapling" },
    @{ url = "https://github.com/NanmiCoder/MediaCrawler.git";     dir = "core\media-crawler" },
    # --- mcp servers ---
    @{ url = "https://github.com/firecrawl/firecrawl-mcp-server.git"; dir = "mcp-servers\firecrawl-mcp-server" },
    @{ url = "https://github.com/brightdata/brightdata-mcp.git";      dir = "mcp-servers\brightdata-mcp" },
    @{ url = "https://github.com/microsoft/playwright-mcp.git";       dir = "mcp-servers\playwright-mcp" },
    @{ url = "https://github.com/creatorpiyush/webmesh-mcp.git";      dir = "mcp-servers\webmesh-mcp" },
    @{ url = "https://github.com/competitorch/ScrapeLabMCP.git";      dir = "mcp-servers\scrapelab-mcp" },
    @{ url = "https://github.com/modelcontextprotocol/servers.git";   dir = "mcp-servers\reference-servers" },
    # --- agents ---
    @{ url = "https://github.com/browser-use/browser-use.git";        dir = "agents\browser-use" },
    @{ url = "https://github.com/Skyvern-AI/skyvern.git";             dir = "agents\skyvern" },
    @{ url = "https://github.com/firecrawl/web-agent.git";            dir = "agents\firecrawl-web-agent" },
    # --- anti-bot ---
    @{ url = "https://github.com/daijro/camoufox.git";                dir = "anti-bot\camoufox" },
    @{ url = "https://github.com/FlareSolverr/FlareSolverr.git";     dir = "anti-bot\flaresolverr" }
)

$ok = 0; $skip = 0; $fail = @()
foreach ($r in $repos) {
    $path = Join-Path $base $r.dir
    if (Test-Path $path) { Write-Host "SKIP  $($r.dir) (exists)" -ForegroundColor Yellow; $skip++; continue }
    Write-Host "CLONE $($r.url) -> $($r.dir)" -ForegroundColor Cyan
    git clone --depth 1 $r.url $path 2>&1 | Out-Null
    if (Test-Path $path) { $ok++ } else { $fail += $r.dir }
}
Write-Host "`nDone: $ok cloned, $skip skipped, $($fail.Count) failed" -ForegroundColor Green
if ($fail.Count) { Write-Host "Failed: $($fail -join ', ')" -ForegroundColor Red }
