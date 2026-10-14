# opencode data-scraping stack

A private, opencode-native web scraping stack: agents, commands, skills, an
MCP toolbox, and a routing plugin that wire open-source crawlers and your
DataImpulse residential proxies into one workflow with hard legality and
validation gates. Modeled after the
[`opencode-hunt-stack`](https://github.com/Frappppy/opencode-hunt-stack)
pattern (binding `AGENTS.md`, `INVENTORY.md`, installer, on-demand skills).
Private repository — clone access requires GitHub auth.

---

## At a glance

| Layer | Count | Where |
|---|---|---|
| Agents | 5 | `agents/` |
| Default agent | navigator | auto-routed primary, every session |
| Commands | 6 | `commands/` |
| Skills | 11 | `skills/` |
| Instructions | 2 global instruction files | `instructions/` (scraping.md + subagents.md) |
| Plugin | 1 | `plugins/scrape-navigator/` |
| MCP servers | 6 | `config/opencode.json.example` |
| Bin scripts | 3 | `bin/` |
| Reference repos | 17 | `repos/` (gitignored, ~1 GB) |

---

## Give this repo to an agent

Paste this into a fresh agent with repo access:

```
You are setting up and using the private opencode data-scraping stack at
https://github.com/Frappppy/opencode-data-scraping-stack (clone needs gh
auth or a PAT; the repo is private).

navigator is the default agent for every session, and the global
subagent-first policy lives in instructions/subagents.md.

1. Clone the repo, then read AGENTS.md first, then README.md, then
   INVENTORY.md. AGENTS.md rules are binding.
2. Run: powershell -ExecutionPolicy Bypass -File install.ps1
3. Fill in config/dataimpulse.local.env with the DataImpulse login and
   password (gitignored; never commit or print credentials).
4. Run: powershell -ExecutionPolicy Bypass -File install.ps1 -Link
   (deploys agents/skills/commands/plugin/instructions into
   ~/.config/opencode, merges MCP servers into opencode.jsonc, adds bin/ to
   PATH).
5. Run: powershell -ExecutionPolicy Bypass -File install.ps1 -Check
   repeatedly until it reports green. Fix anything red.
6. Restart opencode so agents, skills, commands, MCP servers, and the
   plugin load.
7. Work every scraping task through this workflow: /newjob -> load
   tool-selection -> scrape | crawl | extract | bypass -> /check-output
   before any result is called done.

Note: repos/, .venv/, jobs/, output/, and config/dataimpulse.local.env are
gitignored and regenerated locally by the installer — never commit them.
```

---

## Quick start

```powershell
# clone (repo is private; gh auth or PAT required)
gh repo clone Frappppy/opencode-data-scraping-stack "<clone-dir>"
cd "<clone-dir>"

# 1. full setup: venv, pip libs, chromium, camoufox, 17 reference repos
powershell -ExecutionPolicy Bypass -File install.ps1

# 2. fill in your DataImpulse credentials (gitignored)
notepad config\dataimpulse.local.env

# 3. verify proxies (prints your exit IP)
bin\oc-proxy-test.ps1 -Mode rotate

# 4. deploy into ~/.config/opencode (agents, skills, commands, plugin,
#    instructions, MCP merge, PATH)
powershell -ExecutionPolicy Bypass -File install.ps1 -Link

# 5. health gate - must report green
powershell -ExecutionPolicy Bypass -File install.ps1 -Check
```

Restart opencode after step 4. Optional keys as environment variables only
(never in files): `FIRECRAWL_API_KEY`, `BRIGHTDATA_API_TOKEN`.

`camoufox fetch` (browser download) is best-effort and slow on some
networks — a WARN from `-Check` is fine and never blocks setup.

On this machine the stack root is `D:\Code\Data Scraping`. Elsewhere, scripts
use `$PSScriptRoot`; override the plugin root with the `SCRAPING_STACK_ROOT`
environment variable.

---

## How routing works

The `scrape-navigator` plugin (auto-loaded from
`~/.config/opencode/plugins/` after `-Link`) makes skill knowledge enforced
instead of suggested:

1. Every prompt is classified (`chat.message` hook) against a route table —
   cheapest matching route wins, non-scraping prompts route to `none` so
   unrelated sessions stay clean.
2. The decision and up to two matched skill bodies are injected into the
   system prompt (`experimental.chat.system.transform`), e.g. "crawl the
   docs site" attaches `crawl4ai` + `pagination` and mandates the robots.txt
   gate.
3. `shell.env` injects `DATAIMPULSE_*` / `NTFY_*` / `FIRECRAWL_*` /
   `BRIGHTDATA_*` variables from gitignored `config/dataimpulse.local.env`
   into every spawned shell — proxies work with no manual exports.

`install.ps1 -Link` merges `"default_agent": "navigator"` into
`opencode.jsonc`, so every session and project opens with the router as the
primary agent. The global instruction file `instructions/subagents.md`
enforces subagent-first execution: any task with 3+ steps is divided across
subagents (parallel by default) instead of worked sequentially, and
navigator trusts the plugin's injected route classification as its first
signal.

Audit log: `~/.local/state/opencode-scrape/navigator.log`. The plugin never
blocks a request; on error it does nothing. Unit tests:

```powershell
node plugins/scrape-navigator/route.test.mjs
```

---

## Layout

```
<clone-dir>/
├── AGENTS.md              binding rules — read first
├── README.md              this file
├── INVENTORY.md           every server, skill, command, agent, script, repo
├── install.ps1            setup / -Check / -Link (modes described above)
├── agents/                5 agents (navigator = default): navigator, crawler, extractor, stealth, validator
├── commands/              6 commands: scrape, crawl, extract, bypass, newjob, check-output
├── skills/                11 skills (tool-selection first)
├── plugins/
│   └── scrape-navigator/  prompt router, skill-body injection, shell env hook
├── instructions/          2 global instruction files (scraping.md + subagents.md), deployed by -Link
├── bin/                   oc-scrape, oc-proxy-test, oc-robots
├── config/                opencode.json.example, dataimpulse env templates
├── scripts/               clone-all, crawl4ai + scrapling starters
├── docs/                  CHEATSHEET.md, REPLICATION.md
├── jobs/                  per-job workspaces: HTML, JSONL, logs, validation report (gitignored)
├── output/                scratch output (gitignored)
├── repos/                 17 cloned reference repos (gitignored, ~1 GB)
└── .venv/                 python environment (gitignored, created by installer)
```

---

## Commands

| Command | What it does |
|---|---|
| `/newjob <name> <url>` | Scaffold `jobs/<name>/` workspace |
| `/scrape <url> [json]` | One page to markdown/JSON |
| `/crawl <url> [maxPages] [maxDepth]` | Capped, paced site crawl |
| `/extract <url\|job> <fields>` | Structured, schema-validated JSONL |
| `/bypass <url>` | Anti-bot ladder on a blocked page |
| `/check-output <job-dir>` | Validation gate — required before delivery |

## Agents

| Agent | What it does |
|---|---|
| `navigator` | Default agent: routes every task, dispatches subagents to divide work; on web tasks enforces robots gate, cheapest tool, skills, validate |
| `crawler` | Bulk acquisition: map, caps, dedup, cache, rate limits |
| `extractor` | Raw content to schema-validated JSONL |
| `stealth` | Escalation ladder for blocked targets |
| `validator` | Schema, dedup, coverage, freshness, robots gate |

## Skills

| Skill | What it does |
|---|---|
| `tool-selection` | Decision tree — load first for any scrape request |
| `crawl4ai` | AsyncWebCrawler, config, proxies, failure modes |
| `scrapling` | Adaptive self-healing selectors, fetchers |
| `firecrawl-mcp` | Right Firecrawl tool plus credit discipline |
| `stealth-antibot` | The anti-bot escalation ladder |
| `proxies-dataimpulse` | Ports, targeting syntax, env-only credentials |
| `llm-extraction` | Schema-first LLM extraction, anti-hallucination |
| `social-media` | MediaCrawler plus prebuilt per-platform scrapers |
| `api-capture` | Capture and replay HTTP APIs behind page UIs |
| `pagination` | Next-page detection, depth caps, dedup |
| `monitor-diff` | Change detection between scheduled fetches |

---

## DataImpulse proxies

| Kind | Endpoint | Notes |
|---|---|---|
| Rotating HTTP | `gw.dataimpulse.com:823` | New IP per request |
| Rotating SOCKS5 | `gw.dataimpulse.com:824` | New IP per request |
| Sticky | `gw.dataimpulse.com:10000-20000` | Same IP per port; TTL controllable |

Targeting lives in the proxy username, e.g.
`login__cr.us;sessttl.30:password` (US, 30-minute sticky session). Full
syntax: `skills/proxies-dataimpulse/SKILL.md`.

Credentials exist only in gitignored `config/dataimpulse.local.env` and reach
shells through the plugin's `shell.env` hook. Never put them in code, URLs,
logs, or commits. Verify before any real job:

```powershell
bin\oc-proxy-test.ps1 -Mode rotate
bin\oc-proxy-test.ps1 -Mode sticky -Socks
```

---

## The anti-bot ladder

1. `curl_cffi` TLS impersonation
2. Header hygiene plus >=2s per-host pacing
3. DataImpulse residential proxies (rotating, then sticky)
4. camoufox / nodriver stealth browser (sticky session)
5. ScrapeLab MCP (stealth browser toolset)
6. Hosted unlocker (FlareSolverr / Bright Data / Zyte)

Two 403s with the same method means change rung, never repeat identically.
CAPTCHA and auth walls are stop signals — ask the user, do not bypass.
One command: `/bypass <url>`.

---

## Hard rules

- Public data only. No auth bypass, no paywalls, no private data.
- robots.txt first: run `bin/oc-robots.ps1 <domain>` before any request; if
  it disallows, stop.
- >=2s between requests per host; honor `Crawl-delay` and `Retry-After`.
- Credentials via env vars only (`config/dataimpulse.local.env`, gitignored).
- Evidence is files under `jobs/<name>/` — raw HTML, manifests, logs. No
  prose-only claims.
- Schema before LLM: selectors first; LLM extraction only as validated
  escalation.
- `/check-output` must produce `validation_report.md` before delivery.
- CAPTCHA and auth walls = stop and ask. Paid solvers need explicit approval.

---

## Replication on another machine

Clone, then follow `docs/REPLICATION.md`. It covers environment setup,
`SCRAPING_STACK_ROOT`, installer modes, MCP merge, and the `-Check` gate.

---

## License & ethics

Stack code is MIT. Cloned reference repos keep their own licenses
(crawl4ai/scrapy/crawlee Apache-2.0, firecrawl AGPL, camoufox MPL).
Scraping public data can still violate a site's terms of service — that call
is the operator's.
