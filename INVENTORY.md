# Inventory — everything this stack exposes

Assembled 2026-10-14. Source of truth for what's here; update when adding
skills/commands/agents/servers.

**Counts: 6 MCP server configs · 11 skills · 6 commands · 5 agents · 1 plugin
(scrape-navigator) · 3 bin scripts · 3 scripts · 17 reference repos (cloned,
gitignored) · 1 installer · 2 global instruction files · default agent:
navigator**

---

## 1. MCP servers — `config/opencode.json.example`

Deploy with `install.ps1 -Link` (merges into `~/.config/opencode/opencode.jsonc`,
or `opencode.json` if that is the config that exists). The example also
carries `"default_agent": "navigator"` and both `instructions/*.md` entries;
`-Link` merges those too (existing entries left untouched, `.bak` backup
first).

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
| `api-capture` | reuse the page's backing API (XHR/fetch/HAR/GraphQL) instead of rendering HTML |
| `pagination` | rel=next / page / cursor / infinite scroll, pagination traps + dedup |
| `monitor-diff` | change detection: diff saved raw, webmesh/firecrawl monitors, scheduling + alerts |

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
| `navigator` | all | **default agent**; universal router — first move on every task is dispatching subagents to divide work (3+ step rule, parallel by default); web-touching tasks then enforce robots → cheapest tool → skills → validate |
| `crawler` | subagent | bulk acquisition: map, caps, dedup, cache, rate limits |
| `extractor` | subagent | raw → schema-validated JSONL |
| `stealth` | subagent | escalation ladder, logs bypass recipes |
| `validator` | subagent | schema/dedup/coverage/freshness/robots gate |

## 5. Plugin — `plugins/scrape-navigator/` (deployed to `~/.config/opencode/plugins/`)

Routes every incoming prompt to the right approach and makes skill knowledge
*present* in the request instead of merely suggested.

| File | Role |
|---|---|
| `route.js` | pure routing logic: `SKILL_IDS` (11 ids), `ROUTES` (14 routes), `classify()` / `decide()` / `mentionedSkills()` |
| `route.test.mjs` | unit tests — `node plugins/scrape-navigator/route.test.mjs` |
| `index.ts` | the opencode plugin: three hooks below |

Hooks:

1. `chat.message` — classifies each incoming prompt, stashes the decision keyed
   by session ID, appends it to the navigator log.
2. `experimental.chat.system.transform` — injects the route decision, the
   suggested agent, mandatory gates, and up to **2 skill bodies** (4000 chars
   each) into the system prompt.
3. `shell.env` — injects `DATAIMPULSE_*` / `NTFY_*` / `FIRECRAWL_*` /
   `BRIGHTDATA_*` variables from gitignored `config/dataimpulse.local.env`
   into every spawned shell. Stack root overridable via `SCRAPING_STACK_ROOT`
   (default `D:/Code/Data Scraping`).

Routing table — route → suggested agent → skills attached (first 2 injected):

| Route | Agent | Skills |
|---|---|---|
| `stealth` — blocked / anti-bot escalation | stealth | stealth-antibot, proxies-dataimpulse |
| `proxy` — DataImpulse / proxies / exit IP | stealth | proxies-dataimpulse |
| `monitor` — change detection / schedules | crawler | monitor-diff |
| `social` — platform scraping | crawler | social-media |
| `api` — capture the backing API (XHR/HAR) | extractor | api-capture |
| `pagination` — next page / infinite scroll | crawler | pagination, crawl4ai |
| `crawl` — bulk site crawl | crawler | crawl4ai, pagination |
| `scrape` — single page | navigator | crawl4ai |
| `extract` — structured fields | extractor | scrapling, llm-extraction |
| `search` — web search / URL discovery | navigator | firecrawl-mcp |
| `llm` — LLM-driven extraction | extractor | llm-extraction |
| `validate` — output QA | validator | (none) |
| `scaffold` — new scraping job | navigator | tool-selection |
| `tool` — choose the engine | navigator | tool-selection |
| `none` — no scraping signal → build agent | build | (none) |

- `tool-selection` attaches unconditionally inside any workspace containing
  `jobs/`; an explicit `@skill-name` mention always attaches (first-named wins).
- Log: `~/.local/state/opencode-scrape/navigator.log`
  (`route=... skills=... agent=... why="..."`).
- Test: `node plugins/scrape-navigator/route.test.mjs` → `all tests passed`.

## 6. Bin scripts — `bin/` (added to PATH by `-Link`)

| Script | Purpose |
|---|---|
| `oc-scrape.ps1 <url>` | quick crawl4ai markdown scrape via venv |
| `oc-proxy-test.ps1 [-Mode rotate\|sticky] [-Socks]` | verify DataImpulse, print exit IP |
| `oc-robots.ps1 <url>` | fetch + summarize robots.txt (required pre-crawl) |

## 7. Scripts — `scripts/` (1 PowerShell + 2 Python)

| Script | Purpose |
|---|---|
| `clone-all.ps1` | idempotent shallow-clone of all 17 reference repos |
| `starter_crawl4ai.py` | minimal async markdown crawl |
| `starter_scrapling.py` | static + stealth extraction example |

Installer: `install.ps1` (`-Check` health gate, `-Link` deploy). `-Link`
merges `default_agent: navigator` into the opencode config and registers
every file in `instructions/` (both) in its `instructions` array; `-Check`
verifies the stack file `instructions\subagents.md`, both instruction files
deployed, and `default_agent` present (WARN if missing). `camoufox fetch` is
best-effort — slow on some networks, a WARN never blocks setup.

## 8. Reference repos — `repos/` (gitignored, ~1 GB)

Cloned by `scripts/clone-all.ps1`. Consult as docs; never commit or edit in place.

- **core/** crawl4ai · firecrawl · crawlee · scrapy · scrapling · media-crawler
- **mcp-servers/** firecrawl-mcp-server · brightdata-mcp · playwright-mcp · webmesh-mcp · scrapelab-mcp · reference-servers
- **agents/** browser-use · skyvern · firecrawl-web-agent
- **anti-bot/** camoufox · flaresolverr

## 9. Config files

| File | Purpose |
|---|---|
| `config/opencode.json.example` | MCP servers + `default_agent: navigator` + both `instructions` entries — template for the opencode config |
| `config/dataimpulse.env.example` | proxy credential template |
| `config/dataimpulse.local.env` | YOUR real proxy creds — gitignored, created by installer |
| `config/claude_desktop_config.json` | same MCP set for Claude Desktop |

## 10. Global instructions — `instructions/` (2 files)

**`instructions/scraping.md`** — seven always-on rules for any web-touching
task (robots first, cheapest tool that works, env-only credentials, evidence
is files, validate before "done", public data only, plus the scrape-navigator
routing/log note).

**`instructions/subagents.md`** — subagent-first execution policy: divide any
task with 3+ steps across subagents, parallel by default, wait only on real
dependencies, keep 1-step work inline, give every code subagent a
verify-method plus "do not commit", and report like an orchestrator. Applies
to every session and project.

Both are registered in `~/.config/opencode/opencode.jsonc` in the
`instructions` array (`.../instructions/scraping.md` and
`.../instructions/subagents.md`, forward slashes) by `install.ps1 -Link`,
which also copies the files to `~/.config/opencode/instructions/`.

## 11. Proxies & hosted services (accounts, not files)

- **DataImpulse** — residential. Rotating `:823`/`:824`, sticky `:10000-20000`.
  Env-driven: `DATAIMPULSE_*`. Test: `bin\oc-proxy-test.ps1`.
- Free tiers worth adding: Firecrawl 1k/mo, Bright Data 5k/mo, Scrapfly,
  ScrapingBee, String, Apify $5, Hyperbrowser, Browserless.
- Paid unlockers when residential isn't enough: Zyte, Oxylabs, ScraperAPI.
- CAPTCHA: 2captcha / CapSolver — user approval required per AGENTS.md.
