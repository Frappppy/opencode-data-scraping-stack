# Inventory — everything this stack exposes

Assembled 2026-10-14. Source of truth for what's here; update when adding
skills/commands/agents/servers.

**Counts: 6 MCP server configs · 8 skills · 6 commands · 5 agents · 3 bin
scripts · 3 python scripts · 17 reference repos (cloned, gitignored) ·
1 installer**

---

## 1. MCP servers — `config/opencode.json.example`

Deploy with `install.ps1 -Link` (merges into `~/.config/opencode/opencode.json`).

| Server | Type | Key needed | Tools (approx) | Status |
|---|---|---|---|---|
| `firecrawl` | local `npx firecrawl-mcp` | `FIRECRAWL_API_KEY` (1k free/mo) | 27 | needs key |
| `firecrawl-keyless` | remote `mcp.firecrawl.dev/v2/mcp` | none | 3 | ready |
| `playwright` | local `npx @playwright/mcp` | none | ~61 | ready |
| `brightdata` | local `npx @brightdata/mcp` | `BRIGHTDATA_API_TOKEN` (5k free/mo) | 32 | needs key |
| `webmesh` | local `npx webmesh-mcp` | none | 7 | ready |
| `scrapelab` | local python (stealth) | none | 84 | optional, off by default |

Routing tables: `skills/firecrawl-mcp/SKILL.md`, `skills/tool-selection/SKILL.md`.

## 2. Skills — `~/.config/opencode/skills/` after `-Link`

| Skill | Purpose |
|---|---|
| `tool-selection` | decision tree — load FIRST for any scrape request |
| `crawl4ai` | AsyncWebCrawler, config, proxies, failure modes |
| `scrapling` | adaptive self-healing selectors, fetchers |
| `firecrawl-mcp` | which Firecrawl tool + credit discipline |
| `stealth-antibot` | 6-rung escalation ladder (curl_cffi → hosted) |
| `proxies-dataimpulse` | rotating/sticky ports, `__cr.cc;sessttl` syntax, env-only creds |
| `llm-extraction` | schema-first LLM extraction, anti-hallucination |
| `social-media` | MediaCrawler + prebuilt scrapers per platform |

## 3. Commands — `~/.config/opencode/commands/` after `-Link`

| Command | Purpose | Agent |
|---|---|---|
| `/scrape <url> [json]` | one page → markdown/JSON | navigator |
| `/crawl <url> [maxPages] [maxDepth]` | capped site crawl | crawler |
| `/extract <url\|job> <fields>` | structured JSONL | extractor |
| `/bypass <url>` | stealth ladder on a blocked page | stealth |
| `/newjob <name> <url>` | scaffold `jobs/<name>/` workspace | navigator |
| `/check-output <job-dir>` | validation report | validator |

## 4. Agents — `~/.config/opencode/agents/` after `-Link`

| Agent | Mode | Role |
|---|---|---|
| `navigator` | all | orchestrator: robots → cheapest tool → skills → validate |
| `crawler` | subagent | bulk acquisition: map, caps, dedup, cache, rate limits |
| `extractor` | subagent | raw → schema-validated JSONL |
| `stealth` | subagent | escalation ladder, logs bypass recipes |
| `validator` | subagent | schema/dedup/coverage/freshness/robots gate |

## 5. Bin scripts — `bin/` (added to PATH by `-Link`)

| Script | Purpose |
|---|---|
| `oc-scrape.ps1 <url>` | quick crawl4ai markdown scrape via venv |
| `oc-proxy-test.ps1 [-Mode rotate\|sticky] [-Socks]` | verify DataImpulse, print exit IP |
| `oc-robots.ps1 <url>` | fetch + summarize robots.txt (required pre-crawl) |

## 6. Python scripts — `scripts/`

| Script | Purpose |
|---|---|
| `clone-all.ps1` | idempotent shallow-clone of all 17 reference repos |
| `starter_crawl4ai.py` | minimal async markdown crawl |
| `starter_scrapling.py` | static + stealth extraction example |

Installer: `install.ps1` (`-Check` health gate, `-Link` deploy).

## 7. Reference repos — `repos/` (gitignored, ~1 GB)

Cloned by `scripts/clone-all.ps1`. Consult as docs; never commit or edit in place.

- **core/** crawl4ai · firecrawl · crawlee · scrapy · scrapling · media-crawler
- **mcp-servers/** firecrawl-mcp-server · brightdata-mcp · playwright-mcp · webmesh-mcp · scrapelab-mcp · reference-servers
- **agents/** browser-use · skyvern · firecrawl-web-agent
- **anti-bot/** camoufox · flaresolverr

## 8. Config files

| File | Purpose |
|---|---|
| `config/opencode.json.example` | MCP servers + references — template for opencode.json |
| `config/dataimpulse.env.example` | proxy credential template |
| `config/dataimpulse.local.env` | YOUR real proxy creds — gitignored, created by installer |
| `config/claude_desktop_config.json` | same MCP set for Claude Desktop |

## 9. Proxies & hosted services (accounts, not files)

- **DataImpulse** — residential. Rotating `:823`/`:824`, sticky `:10000-20000`.
  Env-driven: `DATAIMPULSE_*`. Test: `bin\oc-proxy-test.ps1`.
- Free tiers worth adding: Firecrawl 1k/mo, Bright Data 5k/mo, Scrapfly,
  ScrapingBee, String, Apify $5, Hyperbrowser, Browserless.
- Paid unlockers when residential isn't enough: Zyte, Oxylabs, ScraperAPI.
- CAPTCHA: 2captcha / CapSolver — user approval required per AGENTS.md.
