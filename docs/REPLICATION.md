# REPLICATION — copy this stack to another Windows machine

End state: 5 agents · 6 commands · 11 skills · 6 MCP servers · the
`scrape-navigator` plugin · navigator as `default_agent` · global
`instructions/scraping.md` + `instructions/subagents.md` · DataImpulse
proxies wired in · `install.ps1 -Check` green.

Every command below is PowerShell on Windows. Steps are ordered; run them in
sequence.

---

## 1. Prerequisites

| Requirement | Minimum | Verify with |
|---|---|---|
| Windows 10/11 + PowerShell | 5.1+ | `$PSVersionTable.PSVersion` |
| git | any recent | `git --version` |
| Python | 3.11+ | `python --version` |
| Node.js (with `npx` on PATH) | 18+ | `node -v` and `npx -v` |
| opencode desktop app | current release | app opens |
| Access to the private repo | read | `gh auth status` |

- All four tools (`git`, `python`, `node`, `npx`) must be on PATH — `-Check`
  fails the environment gate otherwise.
- Launch opencode desktop once before step 5 so it creates its config
  directory (`~/.config/opencode/`).
- Disk budget: ~1 GB for `repos/`, plus venv + browsers (chromium, camoufox).
- Read `AGENTS.md` before you do anything with the stack — its rules bind.

## 2. Clone the private repo

Clone **to the default path** unless you also do step 8:

```powershell
# Option A — gh CLI
gh auth login
git clone https://github.com/Frappppy/opencode-data-scraping-stack.git "D:\Code\Data Scraping"

# Option B — PAT via Windows credential manager (paste the PAT at the prompt)
git config --global credential.helper manager
git clone https://github.com/Frappppy/opencode-data-scraping-stack.git "D:\Code\Data Scraping"

cd "D:\Code\Data Scraping"
```

Never embed a PAT in a URL that you later commit or share.

**Pre-flight — the source machine must have pushed everything.** The clone
only works if these paths are tracked:

```powershell
git ls-files plugins instructions docs/REPLICATION.md skills/api-capture
git status --short        # must NOT show plugins/, instructions/, skills/api-capture as untracked
```

If they are untracked on the source machine, commit and push them first —
otherwise `install.ps1 -Check` fails on the new box (missing
`plugins\scrape-navigator\route.js`, `instructions\scraping.md`,
`instructions\subagents.md`, `docs\REPLICATION.md`, or fewer than 11
skills).

## 3. Run the installer (5 stages)

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Idempotent; safe to re-run. What each stage does:

| Stage | Purpose |
|---|---|
| **1/5 python venv + libs** | Creates `.venv\`, upgrades pip, installs crawl4ai, scrapling, httpx (+http2), trafilatura, readability-lxml, pydantic, curl_cffi, playwright, camoufox, nodriver, beautifulsoup4, lxml, parsel, litellm; then verifies `crawl4ai`, `scrapling`, `httpx`, `pydantic` import (non-zero pip exit is a failure) |
| **2/5 browsers** | `playwright install chromium`, then `camoufox fetch` (best-effort — failure is tolerated, never blocks setup) |
| **3/5 clone reference repos** | Runs `scripts\clone-all.ps1`: 17 shallow clones into `repos/` (~1 GB, skips what exists) |
| **4/5 node deps for MCP servers** | `npm install` in `repos\mcp-servers\{firecrawl-mcp-server, brightdata-mcp, webmesh-mcp, playwright-mcp}` |
| **5/5 proxy credentials template** | Copies `config\dataimpulse.env.example` → `config\dataimpulse.local.env` if it does not exist yet |

Note: `install.ps1` resolves its own location from `$PSScriptRoot`
(`$stack = $PSScriptRoot`, line 13), so the installer works from any clone
path. The only baked-in default left is the plugin's stack root — see step 8.

Camoufox note: `camoufox fetch` is best-effort and very slow on some
networks; its rich progress spinner crashes with a UnicodeEncodeError when
stdout is piped on a cp1252 Windows console, so retry it detached when it
hangs or fails — `$env:PYTHONUTF8=1; Start-Process -FilePath python
-ArgumentList '-m','camoufox','fetch' -RedirectStandardOutput camoufox.log
-RedirectStandardError camoufox.err`. A WARN is fine, not a blocker: the
anti-bot ladder still has curl_cffi, DataImpulse residential, playwright
chromium, nodriver, and the optional ScrapeLab MCP.

## 4. Fill in credentials (local only)

```powershell
notepad config\dataimpulse.local.env     # created by stage 5/5 from the template
```

- Set `DATAIMPULSE_LOGIN` / `DATAIMPULSE_PASSWORD` from your DataImpulse
  dashboard; optionally `DATAIMPULSE_COUNTRY` (e.g. `us`) and
  `DATAIMPULSE_SESSION_TTL` (minutes).
- Ports: rotating HTTP `:823`, rotating SOCKS5 `:824`, sticky `:10000-20000`.
  Targeting is appended to the login as `LOGIN__cr.us;sessttl.30:PASSWORD`.
- The file is gitignored (`dataimpulse.local.*`). **Never commit it, never
  paste its values into chat, logs, output, or commits** (AGENTS.md rule).

Optional free-tier API keys — register them as user environment variables,
never in committed files:

```powershell
[Environment]::SetEnvironmentVariable("FIRECRAWL_API_KEY", "<key>", "User")      # 1,000 credits/mo free
[Environment]::SetEnvironmentVariable("BRIGHTDATA_API_TOKEN", "<token>", "User") # 5,000 req/mo free
```

Open a new shell (or restart opencode) so the variables are visible, then:

```powershell
bin\oc-proxy-test.ps1 -Mode rotate
```

## 5. Deploy into opencode — `install.ps1 -Link`

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Link
```

| Source | Destination |
|---|---|
| `agents/` | `~/.config/opencode/agents/` (5 files) |
| `commands/` | `~/.config/opencode/commands/` (6 files) |
| `skills/` | `~/.config/opencode/skills/` (11 dirs) |
| `plugins/` | `~/.config/opencode/plugins/scrape-navigator/` |
| `instructions/` | `~/.config/opencode/instructions/` (`scraping.md`, `subagents.md`) |
| `config/opencode.json.example` | merged into `~/.config/opencode/opencode.jsonc` (or `opencode.json` if that is what exists): adds the 6 MCP servers `firecrawl`, `firecrawl-keyless`, `playwright`, `brightdata`, `webmesh`, `scrapelab`, sets `"default_agent": "navigator"`, plus both instructions entries `~/.config/opencode/instructions/scraping.md` and `~/.config/opencode/instructions/subagents.md`. Existing entries are left untouched; a `.bak` backup is written first; if no config exists at all, one is created from the example |
| `bin/` | appended to the user `PATH` (restart the shell to pick it up) |

## 6. Health gate — `-Check` must be green

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Check
```

Checks, in order: environment (`git`, `python`, `node`, `npx`) · stack files
(including `plugins\scrape-navigator\route.js`, `plugins\scrape-navigator\index.ts`,
`instructions\scraping.md`, `instructions\subagents.md`, `docs\REPLICATION.md`) · router tests
(`route.test.mjs`) · global deployment (11 skills, plugin/skills/both instruction
files deployed, MCP servers plus `default_agent` present in the opencode
config — WARN if missing) · python env (venv plus
`import crawl4ai, scrapling, httpx, pydantic`) · repos (4 spot checks) ·
secrets hygiene (tracked files scanned for leaked credentials).

Only `CHECK: green` (exit code 0) means setup is done. Anything else names the
failing gate — fix it and re-run.

## 7. Restart opencode and verify

1. Quit and restart the **opencode desktop app** (loads agents, commands,
   skills, MCP servers, plugin, instructions). Confirm the merged config
   carries the default agent and both instruction files:

   ```powershell
   Select-String -Path $HOME\.config\opencode\opencode.jsonc -Pattern 'default_agent|instructions/'
   # expect: "default_agent": "navigator" plus scraping.md AND subagents.md
   ```
2. Router tests pass:

   ```powershell
   node plugins\scrape-navigator\route.test.mjs
   # expect: all tests passed
   ```

3. Routing is live — send any scraping prompt (e.g. `scrape
   https://example.com to markdown`), then:

   ```powershell
   Get-Content $HOME\.local\state\opencode-scrape\navigator.log -Tail 5
   # expect: <timestamp> route=... skills=... agent=... why="..."
   ```

   No lines after a prompt → the plugin is not loaded (re-run `-Link`,
   restart the app).

4. Proxies work — a residential exit IP:

   ```powershell
   bin\oc-proxy-test.ps1 -Mode rotate
   ```

5. The command layer works — inside opencode:

   ```text
   /scrape https://example.com
   ```

   markdown comes back and artifacts land under the job workspace.

## 8. Cloning to a NON-default path

Default root: `D:\Code\Data Scraping`. How the pieces behave elsewhere:

- **Scripts — no edits needed.** They derive their location from
  `$PSScriptRoot`, so they work from any clone path:

  | File | Line | Root resolution |
  |---|---|---|
  | `install.ps1` | 13-14 | `$stack = $PSScriptRoot` (falls back to `$MyInvocation.MyCommand.Path`) |
  | `bin/oc-scrape.ps1` | 8 | `$stack = Split-Path -Parent $PSScriptRoot` (`bin/` is one level below the root) |
  | `bin/oc-proxy-test.ps1` | 10 | `$stack = Split-Path -Parent $PSScriptRoot` |
  | `scripts/clone-all.ps1` | 4-5 | `$stack = Split-Path -Parent $PSScriptRoot`; `$base = Join-Path $stack "repos"` |
  | `bin/oc-robots.ps1` | — | no stack path; runs from anywhere |

  Python starters and `plugins/scrape-navigator/route.test.mjs` are
  path-independent too (relative imports / script arguments).

- **Plugin — set one env var.** `SCRAPING_STACK_ROOT=<path>` points the
  plugin at your `skills/` and at `config/dataimpulse.local.env`
  (`plugins/scrape-navigator/index.ts` falls back to
  `D:/Code/Data Scraping` when the variable is unset). The log stays at
  `~/.local/state/opencode-scrape/navigator.log`. Set it for the opencode
  desktop process (user environment variable) before launching the app.

## 9. Give this to an agent

Paste into a fresh AI agent on the new machine:

> Read `AGENTS.md` first — it holds the hard rules (public data only, robots.txt
> before the first request, ≥2s per-host pacing, credentials only via
> `DATAIMPULSE_*` env vars / gitignored `config/dataimpulse.local.env`, evidence
> is files under `jobs/<name>/`, schema before LLM, `/check-output` before any
> delivery) and they override convenience. Then `README.md`, then `INVENTORY.md`
> for the complete file/tool inventory. Set up with
> `powershell -ExecutionPolicy Bypass -File install.ps1`, then
> `install.ps1 -Link` (deploys agents/commands/skills/plugin/instructions to
> `~/.config/opencode/`, merges the 6 MCP servers into `opencode.jsonc`, sets
> `default_agent` to `navigator`, and registers both instruction files), then
> `install.ps1 -Check` until it prints `CHECK: green`. Fill in
> `config/dataimpulse.local.env` with the DataImpulse credentials and never
> commit or print them. Work the pipeline as `/newjob <name> <url>` →
> `skills/tool-selection` picks the engine → `/scrape | /crawl | /extract |
> /bypass` does the work → `/check-output <job-dir>` gates delivery. The
> `scrape-navigator` plugin auto-routes every prompt and injects the matching
> skill text; if routing looks wrong, audit
> `~/.local/state/opencode-scrape/navigator.log`.

## 10. What stays local vs what's in git

**In git — stack files only** (markdown, PowerShell/Python scripts, config
templates): `AGENTS.md` `README.md` `INVENTORY.md` `docs/` `install.ps1`
`.gitignore` `agents/` `commands/` `skills/` `plugins/` `instructions/` `bin/`
`scripts/` `config/opencode.json.example` `config/dataimpulse.env.example`
`config/claude_desktop_config.json`. Count today: **34 tracked files**
(`git ls-files | Measure-Object -Line`) — plus `plugins/`, `instructions/`,
`skills/api-capture`, `skills/pagination`, `skills/monitor-diff` and
`docs/REPLICATION.md` once committed; confirm with `git status` before cloning
elsewhere (step 2).

**Never in git — local state, regenerated by the tooling:**

| Gitignored path | Regenerated by |
|---|---|
| `repos/` (17 reference repos, ~1 GB) | `scripts/clone-all.ps1` (run by stage 3/5) |
| `.venv/`, `venv/`, `node_modules/` | `install.ps1` (stages 1/5 and 4/5) |
| `jobs/`, `output/`, `*.log` | per-job runtime as you scrape |
| `config/dataimpulse.local.env` | template copied by stage 5/5 — you fill it in |
| `dataimpulse.local.*`, `*token*`, `*secret*`, `*password*` | credential patterns excluded by `.gitignore` |

Quick re-verification after any move:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Check    # must end CHECK: green
node plugins\scrape-navigator\route.test.mjs                   # must end all tests passed
bin\oc-proxy-test.ps1 -Mode rotate                             # residential exit IP
```
