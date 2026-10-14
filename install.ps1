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
$stack = $PSScriptRoot
if ([string]::IsNullOrEmpty($stack)) { $stack = Split-Path -Parent $MyInvocation.MyCommand.Path }
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
                     "commands\scrape.md", "bin\oc-scrape.ps1", "scripts\clone-all.ps1",
                     "plugins\scrape-navigator\route.js", "plugins\scrape-navigator\index.ts",
                     "instructions\scraping.md", "instructions\subagents.md", "docs\REPLICATION.md")) {
        if (Test-Path (Join-Path $stack $f)) { OK $f } else { BAD "$f missing" }
    }
    Write-Host "== router tests ==" -ForegroundColor Cyan
    node (Join-Path $stack "plugins\scrape-navigator\route.test.mjs") 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { OK "route.test.mjs all passed" } else { BAD "route.test.mjs FAILED - see node output" }
    Write-Host "== global deployment (-Link) ==" -ForegroundColor Cyan
    $ocDir = Join-Path $HOME ".config\opencode"
    $skillCount = (Get-ChildItem (Join-Path $stack "skills") -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($skillCount -ge 11) { OK "stack skills: $skillCount/11" } else { BAD "stack skills: $skillCount (expected 11)" }
    if (Test-Path (Join-Path $ocDir "plugins\scrape-navigator\index.ts")) { OK "plugin deployed globally" } else { BAD "plugin not deployed - run install.ps1 -Link" }
    if (Test-Path (Join-Path $ocDir "skills\tool-selection\SKILL.md")) { OK "skills deployed globally" } else { BAD "skills not deployed - run install.ps1 -Link" }
    if ((Test-Path (Join-Path $ocDir "instructions\scraping.md")) -and (Test-Path (Join-Path $ocDir "instructions\subagents.md"))) { OK "global instructions deployed" } else { BAD "instructions not deployed - run install.ps1 -Link" }
    $cfgFile = if (Test-Path (Join-Path $ocDir "opencode.jsonc")) { Join-Path $ocDir "opencode.jsonc" } else { Join-Path $ocDir "opencode.json" }
    if (Test-Path $cfgFile) {
        $cfgRaw = Get-Content $cfgFile -Raw
        if ($cfgRaw -match '"firecrawl"') { OK "MCP servers present in $(Split-Path $cfgFile -Leaf)" } else { BAD "MCP servers missing from $(Split-Path $cfgFile -Leaf) - run install.ps1 -Link" }
        if ($cfgRaw -match '"default_agent"') { OK "default_agent set (navigator)" } else { WARN "default_agent not set - run install.ps1 -Link" }
    } else { BAD "no opencode config at $ocDir" }
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
    $secretIssues = @()
    $tracked = @(git -C $stack ls-files 2>$null)
    $secretIssues += @($tracked | Where-Object { $_ -match '(?i)(^|/)\.env$|local\.env$|\.pat$|github-token|/secrets?/' })
    $secretIssues += @(git -C $stack grep -l -E "gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}" 2>$null |
        Where-Object { $_ -notmatch '\.(example|md)$' })
    $pwFiles = @(git -C $stack grep -l -E "DATAIMPULSE_PASSWORD=" 2>$null | Where-Object { $_ -notmatch '\.(example|md)$' })
    foreach ($f in $pwFiles) {
        foreach ($ln in @(git -C $stack grep -h -E "DATAIMPULSE_PASSWORD=" -- $f 2>$null)) {
            if ($ln -match 'DATAIMPULSE_PASSWORD\s*=\s*(.+)$') {
                $rest = $Matches[1].Trim()
                $val = ""
                if     ($rest -match '^"[^"]*"$') { $val = $rest.Substring(1, $rest.Length - 2).Trim() }
                elseif ($rest -match "^'[^']*'$") { $val = $rest.Substring(1, $rest.Length - 2).Trim() }
                elseif ($rest -notmatch '["'']')  { $val = $rest }
                if ($val -and ($val -notmatch '^(your_|<|\$|\{)') -and ($val -notmatch '^placeholder')) { $secretIssues += $f }
            }
        }
    }
    $secretIssues = @($secretIssues | Where-Object { $_ } | Select-Object -Unique)
    if ($secretIssues.Count) { foreach ($s in $secretIssues) { BAD "possible secret in: $s" } }
    else { OK "no secrets tracked" }
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
    & $py -m pip install crawl4ai scrapling httpx "httpx[http2]" trafilatura readability-lxml pydantic curl_cffi playwright camoufox nodriver beautifulsoup4 lxml parsel litellm | Select-Object -Last 15
    if ($LASTEXITCODE -ne 0) { BAD "pip install failed (exit code $LASTEXITCODE)" }

    Write-Host "== verify python modules ==" -ForegroundColor Cyan
    foreach ($mod in @("crawl4ai", "scrapling", "httpx", "pydantic")) {
        & $py -c "import $mod" 2>$null
        if ($LASTEXITCODE -eq 0) { OK "import $mod" } else { BAD "python module '$mod' not installed" }
    }

    Write-Host "== 2/5 browsers ==" -ForegroundColor Cyan
    & $py -m playwright install chromium
    if ($LASTEXITCODE -eq 0) { OK "chromium ready" } else { WARN "playwright chromium install failed - rerun: python -m playwright install chromium" }
    & $py -m camoufox fetch 2>$null   # optional; tolerate failure
    if ($LASTEXITCODE -eq 0) { OK "camoufox fetched" } else { WARN "camoufox fetch failed (optional) - rerun: python -m camoufox fetch" }

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
    Write-Host "== deploy agents/skills/commands/plugins/instructions -> $ocDir ==" -ForegroundColor Cyan
    foreach ($pair in @(@("agents", "agents"), @("commands", "commands"), @("plugins", "plugins"))) {
        $src = Join-Path $stack $pair[0]; $dst = Join-Path $ocDir $pair[1]
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item "$src\*" $dst -Force -Recurse
        OK "$($pair[0])/ -> $dst"
    }
    $skDst = Join-Path $ocDir "skills"
    New-Item -ItemType Directory -Force -Path $skDst | Out-Null
    Copy-Item (Join-Path $stack "skills\*") $skDst -Force -Recurse
    OK "skills/ -> $skDst"
    $insDst = Join-Path $ocDir "instructions"
    New-Item -ItemType Directory -Force -Path $insDst | Out-Null
    Copy-Item (Join-Path $stack "instructions\*") $insDst -Force
    OK "instructions/ -> $insDst"

    Write-Host "== merge MCP config + instructions into opencode config ==" -ForegroundColor Cyan
    # opencode accepts opencode.jsonc OR opencode.json - extend whichever exists
    # (this machine uses .jsonc); create from the example only if neither is there.
    $cfgPath = $null
    foreach ($cand in @("opencode.jsonc", "opencode.json")) {
        $p = Join-Path $ocDir $cand
        if (Test-Path $p) { $cfgPath = $p; break }
    }
    $example = Get-Content (Join-Path $stack "config\opencode.json.example") -Raw | ConvertFrom-Json
    if ($cfgPath) {
        Copy-Item $cfgPath "$cfgPath.bak" -Force
        $cfg = $null
        try { $cfg = (Get-Content $cfgPath -Raw) | ConvertFrom-Json } catch {
            WARN "$(Split-Path $cfgPath -Leaf) has comments - merging only instructions textually; merge MCP servers from config\opencode.json.example by hand"
        }
        if ($cfg) {
            if (-not ($cfg.PSObject.Properties.Name -contains "mcp")) {
                $cfg | Add-Member -NotePropertyName mcp -NotePropertyValue ([PSCustomObject]@{ servers = [PSCustomObject]@{} })
            }
            if (-not ($cfg.mcp.PSObject.Properties.Name -contains "servers")) {
                $cfg.mcp | Add-Member -NotePropertyName servers -NotePropertyValue ([PSCustomObject]@{})
            }
            foreach ($p in $example.mcp.servers.PSObject.Properties) {
                if (-not ($cfg.mcp.servers.PSObject.Properties.Name -contains $p.Name)) {
                    $cfg.mcp.servers | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
                    OK "added mcp server '$($p.Name)'"
                } else { WARN "mcp server '$($p.Name)' already present - left untouched" }
            }
            $insDirUnix = ($insDst -replace "\\", "/")
            $insList = @($cfg.instructions | Where-Object { $_ })
            $addedIns = @()
            foreach ($insFile in (Get-ChildItem (Join-Path $stack "instructions") -Filter *.md -ErrorAction SilentlyContinue)) {
                $insPath = "$insDirUnix/$($insFile.Name)"
                if (-not ($insList -contains $insPath)) { $insList += $insPath; $addedIns += $insFile.Name }
            }
            if ($addedIns.Count -gt 0) {
                if ($cfg.PSObject.Properties.Name -contains "instructions") {
                    $cfg.instructions = $insList
                } else {
                    $cfg | Add-Member -NotePropertyName instructions -NotePropertyValue $insList
                }
                OK "added instructions entries: $($addedIns -join ', ')"
            } else { OK "instructions entries already present" }
            if ($example.PSObject.Properties.Name -contains "default_agent") {
                if (-not ($cfg.PSObject.Properties.Name -contains "default_agent")) {
                    $cfg | Add-Member -NotePropertyName default_agent -NotePropertyValue $example.default_agent
                    OK "added default_agent: $($example.default_agent)"
                } else { OK "default_agent already set: $($cfg.default_agent)" }
            }
            $cfg | ConvertTo-Json -Depth 20 | Set-Content $cfgPath -Encoding UTF8
            OK "$(Split-Path $cfgPath -Leaf) updated (backup: $(Split-Path $cfgPath -Leaf).bak)"
        }
    } else {
        # write a fresh config from the example
        New-Item -ItemType Directory -Force -Path $ocDir | Out-Null
        Copy-Item (Join-Path $stack "config\opencode.json.example") (Join-Path $ocDir "opencode.json")
        OK "created opencode.json from example"
    }

    Write-Host "== add bin/ to user PATH ==" -ForegroundColor Cyan
    $binDir = Join-Path $stack "bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
        OK "added $binDir to user PATH (restart shell to pick up)"
    } else { OK "bin/ already on PATH" }

    Write-Host "`nLink done. Restart opencode (desktop) to load agents/skills/commands/MCP/plugin." -ForegroundColor Green
    exit 0
}
