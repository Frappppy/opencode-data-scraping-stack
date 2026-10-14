# install.ps1 — one-time setup for the opencode data-scraping stack (Windows)
#
#   powershell -ExecutionPolicy Bypass -File install.ps1          # full setup
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Check   # verify only
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Link    # deploy agents/skills/commands + merge MCP config into ~/.config/opencode
#
# Idempotent. Safe to re-run.
param(
    [switch]$Check,
    [switch]$Link
)
$ErrorActionPreference = "Continue"
$stack = "D:\Code\Data Scraping"
$ocDir = Join-Path $HOME ".config\opencode"
$fail = 0

function OK($m)   { Write-Host "  [ok]   $m" -ForegroundColor Green }
function WARN($m) { Write-Host "  [warn] $m" -ForegroundColor Yellow }
function BAD($m)  { Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:fail++ }

# ---------- CHECK MODE ----------
if ($Check) {
    Write-Host "== environment ==" -ForegroundColor Cyan
    foreach ($cmd in @("git", "python", "node", "npx")) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) { OK "$cmd available" } else { BAD "$cmd missing" }
    }
    Write-Host "== stack files ==" -ForegroundColor Cyan
    foreach ($f in @("AGENTS.md", "README.md", "INVENTORY.md", "install.ps1",
                     "config\opencode.json.example", "config\dataimpulse.env.example",
                     "skills\tool-selection\SKILL.md", "agents\navigator.md",
                     "commands\scrape.md", "bin\oc-scrape.ps1", "scripts\clone-all.ps1")) {
        if (Test-Path (Join-Path $stack $f)) { OK $f } else { BAD "$f missing" }
    }
    Write-Host "== python env ==" -ForegroundColor Cyan
    $py = Join-Path $stack ".venv\Scripts\python.exe"
    if (Test-Path $py) {
        OK "venv present"
        foreach ($mod in @("crawl4ai", "scrapling", "httpx", "pydantic")) {
            & $py -c "import $mod" 2>$null
            if ($LASTEXITCODE -eq 0) { OK "import $mod" } else { BAD "python module '$mod' not installed" }
        }
    } else { BAD "venv missing - run install.ps1 without -Check" }
    Write-Host "== repos ==" -ForegroundColor Cyan
    foreach ($r in @("core\crawl4ai", "core\scrapling", "mcp-servers\firecrawl-mcp-server", "anti-bot\camoufox")) {
        if (Test-Path (Join-Path $stack "repos\$r\.git")) { OK "repos\$r" } else { WARN "repos\$r not cloned (scripts\clone-all.ps1)" }
    }
    Write-Host "== secrets hygiene ==" -ForegroundColor Cyan
    $dirty = git -C $stack grep -l -E "DATAIMPULSE_PASSWORD\s*=\s*[^`$]|fc-[A-Za-z0-9]{8,}|password\s*=\s*['`"][^'`"]+['`"]" -- ':!*.example' ':!*.md' 2>$null
    if ($dirty) { BAD "possible secret in: $($dirty -join ', ')" } else { OK "no obvious secrets in tracked files" }
    Write-Host ""
    if ($fail -eq 0) { Write-Host "CHECK: green" -ForegroundColor Green; exit 0 }
    else { Write-Host "CHECK: $fail failure(s)" -ForegroundColor Red; exit 1 }
}

# ---------- FULL SETUP ----------
if (-not $Check -and -not $Link) {
    Write-Host "== 1/5 python venv + libs ==" -ForegroundColor Cyan
    $py = Join-Path $stack ".venv\Scripts\python.exe"
    if (-not (Test-Path $py)) { python -m venv (Join-Path $stack ".venv") }
    & $py -m pip install --quiet --upgrade pip
    & $py -m pip install --quiet crawl4ai scrapling httpx httpx[http2] trafilatura readability-lxml pydantic curl_cffi playwright camoufox nodriver beautifulsoup4 lxml parsel litellm

    Write-Host "== 2/5 browsers ==" -ForegroundColor Cyan
    & $py -m playwright install chromium
    & $py -m camoufox fetch 2>$null   # optional; tolerate failure

    Write-Host "== 3/5 clone reference repos ==" -ForegroundColor Cyan
    & powershell -ExecutionPolicy Bypass -File (Join-Path $stack "scripts\clone-all.ps1")

    Write-Host "== 4/5 node deps for MCP servers ==" -ForegroundColor Cyan
    foreach ($r in @("mcp-servers\firecrawl-mcp-server", "mcp-servers\brightdata-mcp", "mcp-servers\webmesh-mcp", "mcp-servers\playwright-mcp")) {
        $p = Join-Path $stack "repos\$r"
        if ((Test-Path "$p\package.json")) { Push-Location $p; npm install --silent | Out-Null; Pop-Location; OK $r }
    }

    Write-Host "== 5/5 proxy credentials template ==" -ForegroundColor Cyan
    $localEnv = Join-Path $stack "config\dataimpulse.local.env"
    if (-not (Test-Path $localEnv)) {
        Copy-Item (Join-Path $stack "config\dataimpulse.env.example") $localEnv
        WARN "created config\dataimpulse.local.env - fill in your DataImpulse login/password"
    } else { OK "dataimpulse.local.env already present" }

    Write-Host "`nSetup done. Next:  install.ps1 -Link   (deploy to opencode)   then   bin\oc-proxy-test.ps1" -ForegroundColor Green
    exit 0
}

# ---------- LINK MODE: deploy into ~/.config/opencode ----------
if ($Link) {
    Write-Host "== deploy agents/skills/commands -> $ocDir ==" -ForegroundColor Cyan
    foreach ($pair in @(@("agents", "agents"), @("commands", "commands"))) {
        $src = Join-Path $stack $pair[0]; $dst = Join-Path $ocDir $pair[1]
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item "$src\*" $dst -Force -Recurse
        OK "$($pair[0])/ -> $dst"
    }
    $skDst = Join-Path $ocDir "skills"
    New-Item -ItemType Directory -Force -Path $skDst | Out-Null
    Copy-Item (Join-Path $stack "skills\*") $skDst -Force -Recurse
    OK "skills/ -> $skDst"

    Write-Host "== merge MCP config into $ocDir\opencode.json ==" -ForegroundColor Cyan
    $cfgPath = Join-Path $ocDir "opencode.json"
    $example = Get-Content (Join-Path $stack "config\opencode.json.example") -Raw | ConvertFrom-Json
    if (Test-Path $cfgPath) {
        Copy-Item $cfgPath "$cfgPath.bak" -Force
        $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
        if (-not $cfg.mcp) { $cfg | Add-Member -NotePropertyName mcp -NotePropertyValue ([PSCustomObject]@{ servers = [PSCustomObject]@{} }) }
        if (-not $cfg.mcp.servers) { $cfg.mcp | Add-Member -NotePropertyName servers -NotePropertyValue ([PSCustomObject]@{}) }
        foreach ($p in $example.mcp.servers.PSObject.Properties) {
            if (-not ($cfg.mcp.servers.PSObject.Properties.Name -contains $p.Name)) {
                $cfg.mcp.servers | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
                OK "added mcp server '$($p.Name)'"
            } else { WARN "mcp server '$($p.Name)' already present - left untouched" }
        }
        $cfg | ConvertTo-Json -Depth 20 | Set-Content $cfgPath -Encoding UTF8
        OK "opencode.json updated (backup: opencode.json.bak)"
    } else {
        # write a fresh config from the example
        New-Item -ItemType Directory -Force -Path $ocDir | Out-Null
        Copy-Item (Join-Path $stack "config\opencode.json.example") $cfgPath
        OK "created $cfgPath from example"
    }

    Write-Host "== add bin/ to user PATH ==" -ForegroundColor Cyan
    $binDir = Join-Path $stack "bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
        OK "added $binDir to user PATH (restart shell to pick up)"
    } else { OK "bin/ already on PATH" }

    Write-Host "`nLink done. Restart opencode to load agents/skills/commands/MCP." -ForegroundColor Green
    exit 0
}
