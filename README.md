# opencode-data-scraping-stack

**An OpenCode setup for web scraping that is built to survive validation.**

One command installs six MCP servers, a capped validation gate, a job workspace
with raw evidence, a robots-first enforcement plugin, eleven scraping
playbooks, six commands, five agents and two knowledge references — then
verifies every one of them.

```powershell
gh repo clone Frappppy/opencode-data-scraping-stack "<clone-dir>"
cd "<clone-dir>"
powershell -ExecutionPolicy Bypass -File install.ps1
```

> Companion to
> [`opencode-hunt-stack`](https://github.com/Frappppy/opencode-hunt-stack).
> That one is about **producing findings that get paid**. This one is about
> **producing datasets that hold up**. Same skeleton (binding `AGENTS.md`,
> `INVENTORY.md`, idempotent installer, on-demand skills, tested router), same
> handoff contract: give the repo link to an agent and it can take it from
> there.

Private repository — clone access requires GitHub auth (`gh auth` or a PAT).

---

## If you are an agent reading this

Do these in order. Do not skip step 1.

1. **Read `AGENTS.md` first** — it carries the binding rules for this repo.
2. **Read this README** — install, components, and the reasoning behind the
   shape. If you only read one thing besides `AGENTS.md`, read this one.
3. **Read `INVENTORY.md`.** It is the exact list of every MCP server, skill,
   command, agent, plugin and reference this stack provides.
4. **Read `docs/REPLICATION.md`** when you are setting up a machine that is
   not this one — paths, `SCRAPING_STACK_ROOT`, installer modes, the `-Check`
   gate.
5. **Install:** `powershell -ExecutionPolicy Bypass -File install.ps1`.
6. **Do the manual steps** the installer cannot do — the DataImpulse
   credentials and the opencode restart. Both are printed below.
7. **Verify:** `install.ps1 -Check` must be green before you touch a target.
8. **Then, every job, open with the gate** — this is what catches a dead
   proxy, a disallowed path, and an unvalidated dataset *before* work starts:

   ```powershell
   bin\oc-robots.ps1 <domain>        # disallowed? stop here, do not negotiate
   bin\oc-proxy-test.ps1 -Mode rotate # prints your exit IP; wrong country? fix env first
   ```

   A disallowed robots path means the job does not run. A failing proxy test
   means the job does not run *through that egress*. Full reasoning in
   `skills/proxies-dataimpulse/SKILL.md`.

Then work in this order, because it is the order that produces data that
validates:

```
/newjob  →  tool-selection  →  scrape | crawl | extract | bypass  →  /check-output
 scaffold      cheapest tool      route-enforced skills               gate it
   + robots gate                                                     (validator)
```

`/check-output` must produce `validation_report.md` before anything is called
done. It is a gate, not a suggestion.

Paste-block for a fresh agent with repo access:

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

## Prerequisites

| Need | Why | Install |
|---|---|---|
| Windows 10/11 | the installer is PowerShell (`install.ps1`) | — |
| `git` | cloning this repo + the 17 reference repos | `winget install Git.Git` |
| Python 3.11+ | venv + crawl4ai/scrapling/playwright libs | `winget install Python.Python.3.12` |
| Node.js 18+ | local MCP servers are npx-based | `winget install OpenJS.NodeJS` |
| opencode (desktop app) | the host everything deploys into | — |
| A DataImpulse account | residential egress for every real job | see below |
| ~2 GB disk | reference repos (~1 GB) + browsers | — |

A **DataImpulse login/password** goes in `config/dataimpulse.local.env`
(gitignored, template at `config/dataimpulse.env.example`). The file is read
by the plugin at shell-spawn time and never committed, printed, or inlined
into a URL.

Optional: `FIRECRAWL_API_KEY` and `BRIGHTDATA_API_TOKEN` as **user
environment variables** — never in files. Without them the keyless tiers
(`firecrawl-keyless`, `webmesh`) still work.

---

## Install

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1          # full setup
powershell -ExecutionPolicy Bypass -File install.ps1 -Link    # deploy into ~/.config/opencode
powershell -ExecutionPolicy Bypass -File install.ps1 -Check   # verify an existing install, change NOTHING
```

`install.ps1` is idempotent, skips what is already satisfied, and **fails
loudly**: an early version ran `pip install --quiet` and reported success
while the imports were broken — the installer now verifies every import and
every stage. Full setup builds the venv, installs the Python libs, downloads
Playwright chromium, fetches the camoufox browser (best-effort, slow),
clones the 17 reference repos, and writes the `local.env` template.

**Manual steps**, because they cannot be automated safely:

1. **DataImpulse credentials** → `config\dataimpulse.local.env` (copy the
   `.example`, fill login + password). Verify with
   `bin\oc-proxy-test.ps1 -Mode rotate` — it prints the exit IP.
2. **Restart opencode** after `-Link` — agents, skills, commands, MCP
   servers and the plugin load at startup, not before.
3. **New shell** after `-Link` — `bin/` is added to the *user* PATH, which
   existing terminals do not pick up.

**`camoufox fetch` needs no key but needs patience.** The download is ~1.3 GB
and died mid-flight here on an SSL error; the installer treats it as a WARN,
never a blocker — the anti-bot ladder still has curl_cffi, DataImpulse
residential, Playwright chromium and nodriver. Retry detached if you want
it (see Gotchas 2–3).

---

## What activates automatically, and what does not

Worth knowing before you assume a scrape is covered.

| Component | Automatic in a new session? | The catch |
|---|---|---|
| `scrape-navigator` plugin | **Yes** | global plugins dir, every prompt in every session — after one opencode restart |
| `navigator` as primary agent | **Yes** | `"default_agent": "navigator"` merged by `-Link`; restart to take effect |
| `scraping.md`, `subagents.md` instructions | **Yes** | loaded into every session |
| keyless MCP (`firecrawl-keyless`, `webmesh`) | **Yes** | work immediately, no keys |
| keyed MCP (`firecrawl`, `brightdata`) | **Only with keys set** | `FIRECRAWL_API_KEY` / `BRIGHTDATA_API_TOKEN` must be in the app's environment |
| `playwright` MCP | **Yes, once chromium exists** | installer downloads it; needs npx reachable |
| `scrapelab` MCP | **No** | optional stealth rung — install its requirements first, enable deliberately |
| 11 skills | **Advertised AND enforced** | the plugin injects matched skill bodies into the request, so unlike a bare skill list this is enforcement — and naming a skill (`@scrapling`) always attaches it |
| 6 commands | **Yes** | you or the agent must invoke them |
| `crawler`, `extractor`, `stealth`, `validator` | **Yes** | the router and commands dispatch them; `validator` runs via `/check-output` |
| `bin/` scripts | **After a new shell** | user PATH; existing terminals do not see them |
| venv, pip libs, `repos/` | **This machine only** | scripts derive paths from `$PSScriptRoot`; the plugin root is overridable via `SCRAPING_STACK_ROOT` (see `docs/REPLICATION.md`) |

### DataImpulse proxies — the egress every real job uses

| Kind | Endpoint | Notes |
|---|---|---|
| Rotating HTTP | `gw.dataimpulse.com:823` | new IP per request |
| Rotating SOCKS5 | `gw.dataimpulse.com:824` | new IP per request |
| Sticky | `gw.dataimpulse.com:10000-20000` | same IP per port; TTL controllable |

Targeting lives in the proxy username, e.g.
`login__cr.us;sessttl.30:password` (US, 30-minute sticky session). Full
syntax: `skills/proxies-dataimpulse/SKILL.md`.

Credentials exist only in gitignored `config/dataimpulse.local.env` and reach
shells through the plugin's `shell.env` hook — no manual exports, nothing in
code, URLs, logs, or commits. The MCP servers that need cloud keys read real
environment variables (`${FIRECRAWL_API_KEY}` style interpolation needs the
variable in the app's environment — a file the app never read does not
count).

| Server | Type | Key | What it is for |
|---|---|---|---|
| **firecrawl** | local (`npx firecrawl-mcp`) | `FIRECRAWL_API_KEY` | scrape/map/crawl/search/extract/agent — the paid tier with the full toolset |
| **firecrawl-keyless** | remote (`mcp.firecrawl.dev`) | none | scrape/search/parse only — works with zero setup |
| **playwright** | local (`npx @playwright/mcp`) | none | JS-rendered pages through the downloaded chromium |
| **brightdata** | local (`npx @brightdata/mcp`) | `BRIGHTDATA_API_TOKEN` | 1200+ prebuilt scrapers (Amazon/LinkedIn/TikTok), CAPTCHA handled; free tier |
| **webmesh** | local (`npx webmesh-mcp`) | none | token-economical tiered fetch + BFS crawl + robots handling |
| **scrapelab** | local (`python -m scrapelab_mcp`) | none | 84-tool nodriver stealth browser — Cloudflare/DataDome targets only, opt-in |

### References — knowledge on demand

`repos/` holds 17 cloned upstreams (crawl4ai, firecrawl, crawlee, scrapy,
scrapling, media-crawler, the MCP servers, browser-use, skyvern, camoufox,
flaresolverr — ~1 GB, gitignored). Skills point at them instead of
remembering APIs. References cost nothing until read, unlike MCP tools which
load into every request — which is why engine knowledge lives in skills, not
servers.

### Skills — 11, loaded on demand and enforced on route

| Skill | Use it when |
|---|---|
| `tool-selection` | **load first for any scrape request** — the decision tree for everything below |
| `crawl4ai` | bulk or JS-rendered crawls: AsyncWebCrawler, run config, proxies |
| `scrapling` | stable pages where adaptive self-healing selectors beat re-scraping |
| `firecrawl-mcp` | picking the right Firecrawl tool, plus credit discipline |
| `stealth-antibot` | 403/429/walls — the escalation ladder, rung by rung |
| `proxies-dataimpulse` | any egress question: ports, targeting syntax, env-only credentials |
| `llm-extraction` | selectors are impractical — schema-first extraction with anti-hallucination |
| `social-media` | X/TikTok/Instagram/LinkedIn/Reddit via MediaCrawler + prebuilt scrapers |
| `api-capture` | the page is a shell over XHR — capture and replay the backing API |
| `pagination` | next-page/cursor/offset/infinite-scroll, traps and dedup |
| `monitor-diff` | watch a page and alert only on change |

Prefix any prompt with `@skill-name` (or just name the skill) to attach it
directly. Routing is a convenience; naming is a command.

### Commands — 6

| Command | What it does |
|---|---|
| `/newjob <name> <url>` | scaffold `jobs/<name>/` workspace + run the robots gate first |
| `/scrape <url> [json]` | one page → markdown/JSON |
| `/crawl <url> [maxPages] [maxDepth]` | capped, paced site crawl |
| `/extract <url\|job> <fields>` | structured, schema-validated JSONL |
| `/bypass <url>` | anti-bot ladder on a blocked page — logs the recipe |
| `/check-output <job-dir>` | **hard gate** on the dataset. Must write `validation_report.md` |

### Agents — 5 custom

| Agent | Role | Deliberate restriction |
|---|---|---|
| `navigator` | primary — **the default** | routes the task and dispatches subagents; does not do everything itself |
| `crawler` | bulk acquisition | caps, dedup, cache, rate limits — no unbounded crawls |
| `extractor` | structure | raw content → schema-validated JSONL, nothing else |
| `stealth` | blocked targets | climbs the ladder one rung at a time, logs every attempt |
| `validator` | pre-delivery gate | provenance-strict: judges the evidence, cannot repair it |

### Scripts — `bin/`

| Script | What it does |
|---|---|
| `oc-scrape.ps1` | one-page scrape from the shell (single page → markdown/JSON) |
| `oc-robots.ps1` | the robots gate: fetch + parse robots.txt, exit non-zero when disallowed |
| `oc-proxy-test.ps1` | egress check: rotating/sticky, HTTP/SOCKS — prints the exit IP |

---

## The four ideas that make this different

Everything else is plumbing.

### 1. The validation gate is mechanical

A dataset nobody checked is a draft, not a deliverable. `/check-output`
runs the `validator` agent against the job dir — schema conformance, dedup,
null rates, coverage vs. the page list, freshness, robots compliance — and
writes `validation_report.md`. Gaps are reported as gaps (pages failed,
fields null, coverage partial), never smoothed over. Nothing is called done
without the report file on disk.

### 2. Evidence is files, and absence claims state their ground

**Prose is not evidence.** Every job lives under `jobs/<name>/`: raw HTML,
markdown, JSONL, manifests, `process_log.md`. A claim without a saved file
is not a claim. And half of what a scrape asserts is a *negative* — "no
other variants listed", "price absent on all pages" — which is only as
strong as the ground searched. So state it: *"enumerated all 214 product
URLs from the sitemap; 209 fetched, 5 failed (listed in the report)"*. Where
coverage genuinely cannot be obtained (login wall, block), the honest move
is a written-down gap in the validation report, not a weaker sentence.

### 3. Robots first, cheapest tool that works

`oc-robots.ps1 <domain>` runs before the first request of every job, and a
disallow is a stop sign, not a negotiation. Then the ladder, cheapest rung
first: static HTML → `httpx`/`curl_cffi`; JS-rendered → crawl4ai or
Playwright; walls → proxies, then stealth browsers, then hosted unlockers —
each only after the previous rung demonstrably failed. Never spin a browser
for a page `curl` can read. CAPTCHA and auth walls are stop-and-ask signals,
not bypass targets.

### 4. Skills are enforced, not suggested

An agent is a prompt plus permissions. It can only *advise* that a skill
should be loaded — and the model may not comply. A plugin can put the skill's
text into the request, which is enforcement.

The `scrape-navigator` plugin classifies every prompt into a route and
injects the matched skill bodies into the system prompt:

| Prompt looks like | Route | Skill applied |
|---|---|---|
| "scrape this product page to markdown" | scrape | `crawl4ai` |
| "crawl the whole docs site, max 50 pages" | crawl | `crawl4ai` + `pagination` |
| "extract name, price, sku into jsonl" | extract | `scrapling` + `llm-extraction` |
| "find the XHR and replay that endpoint" | api | `api-capture` |
| "getting 403s from Cloudflare" | stealth | `stealth-antibot` + `proxies-dataimpulse` |
| "rotate my DataImpulse proxy by country" | proxy | `proxies-dataimpulse` |
| "notify me when the price changes" | monitor | `monitor-diff` |
| "scrape the tiktok profile videos" | social | `social-media` |
| "infinite scroll, crawler stops at page 1" | pagination | `pagination` + `crawl4ai` |
| "search the web for recent papers" | search | `firecrawl-mcp` |
| "use AI to extract these fields" | llm | `llm-extraction` |
| "validate and dedup the output" | validate | *(validator agent)* |
| "set up a new scraping job" | scaffold | `tool-selection` |
| "crawl4ai or scrapy for this" | tool | `tool-selection` |
| "update the ntfy script" | none | *(nothing — it is not a scrape)* |
| "@scrapling walk me through this" | mention | `scrapling` |

**Naming a skill always works.** `@scrapling`, `scrapling` or `scrapling
...` attaches that skill regardless of what the route decided, named skills
keep prompt order so the first one named is guaranteed to reach the model,
and a prompt that names a skill but matches no route still routes instead of
falling through to nothing.

The routing table is one file (`plugins/scrape-navigator/route.js`) with 50
test cases (`node plugins/scrape-navigator/route.test.mjs`), including
realistic phrasings per skill, explicit non-scrape cases that must stay
clean, and assertions that the skills actually get attached — because a
route can pass classification tests and still attach nothing. `api` sits
deliberately above `extract`: "extract the API's fields" should fire the
API-first approach rather than scraping HTML. The plugin never blocks a
request; on any error it does nothing at all.

## Why this shape, from the research

- **Crawl before you render.** Most pages are static HTML under a JS shell;
  fetching is 10–100x cheaper than rendering. Hence the cheapest-tool
  ladder, and `api-capture` above rendering — replaying the backing endpoint
  beats driving the page.
- **Selectors rot; adaptation compounds.** Sites redesign constantly, so
  hardcoded CSS dies on a schedule. Hence `scrapling`'s self-healing
  selectors for stable pages, and LLM extraction only where selectors are
  impractical.
- **Egress is infrastructure, not an afterthought.** Datacenter IPs get
  flagged before the first request finishes. Hence DataImpulse residential
  as the default path, sticky sessions where state matters, and the proxy
  test as a pre-job gate.
- **On-demand beats always-loaded.** MCP tools load into every request
  forever; skills, commands and references load when relevant. So engine
  knowledge goes there, and the MCP surface is kept deliberately small —
  six servers, one of them opt-in.
- **Subagents divide; the router does not do.** Multi-step jobs split across
  `crawler`/`extractor`/`stealth`/`validator` in parallel instead of one
  long sequential session. Hence `navigator` as `default_agent` and the
  global `instructions/subagents.md` policy.

---

## Gotchas we already hit

1. **`pip install --quiet` reported success with broken imports.** The venv
   looked done; nothing imported. The installer now verifies every module
   and fails loudly per stage. Silence is not a status.
2. **Piping to `Select-Object -Last 6` made camoufox look hung.** `Last`
   buffers everything until the process exits, so a 1.3 GB download with a
   spinner showed nothing for an hour. Run long downloads detached with a
   log file and check the log.
3. **Camoufox's progress spinner crashes piped Windows consoles**
   (`UnicodeEncodeError`, cp1252 vs braille characters). Set `PYTHONUTF8=1`
   / `PYTHONIOENCODING=utf-8` and do not pipe its stdout.
4. **PowerShell 5.1 `Start-Process` has no `-Environment`, and a quoted exe
   path passed twice becomes a script argument.** Both produced confusing
   failures (`can't open file 'D:\Code\Data'`, `Non-UTF-8 code starting with
   '\x90'`). Pass `-m camoufox fetch` as the argument list only.
5. **The secret scan flagged `config/dataimpulse.env.example`.** A template
   with `your_password_here` is not a leak. The scan now filters
   `.example`/`.md` out and only fails on real values — plus checks that no
   `.env`/`local.env` file is tracked at all.
6. **The live config is `opencode.jsonc`, not `opencode.json`.** The merger
   prefers `.jsonc`, backs up to `.bak` first, and never overwrites existing
   servers — only adds missing ones.
7. **`${FIRECRAWL_API_KEY}` in MCP config needs the variable in the app's
   environment.** A file the desktop app never read does not count. Cloud
   keys go in user env vars; DataImpulse works because the plugin injects
   it into every spawned shell.
8. **System python is not venv python.** Every Python step must use
   `.venv\Scripts\python.exe` explicitly — PATH order will betray you.

---

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Check   # must end: CHECK: green

node plugins\scrape-navigator\route.test.mjs                  # must end: all tests passed
bin\oc-robots.ps1 https://example.com                         # the robots gate, exit 0
bin\oc-proxy-test.ps1 -Mode rotate                            # egress check, prints exit IP
Get-Content $HOME\.local\state\opencode-scrape\navigator.log -Tail 5   # the routing audit trail
```

---

## Security posture

- Proxy credentials live only in gitignored `config/dataimpulse.local.env`.
  They are in no config file, no log, and not in this repo — run the secret
  scan before every push (`-Check` includes it).
- **Public data only.** No auth bypass, no paywalls, no private data. The
  robots gate runs first; CAPTCHA and login walls are stop-and-ask, never
  bypass targets. Paid solvers need explicit approval.
- **Installing a tool is free. Pointing one at a target is not.** Pacing
  (>=2s/host), `Crawl-delay`, `Retry-After`, and the cheapest-rung rule
  apply to every tool — including freshly installed ones and anything
  invoked through an MCP server.
- Cloud keys are referenced by environment variable only, never written
  into a file, a log, or a commit.
- Hosted fetch (Firecrawl cloud, Bright Data) sends target URLs to a
  provider. Never put credentials or PII into a query.
- Evidence ships as files under `jobs/<name>/` — raw captures stay local
  unless the operator decides otherwise.

---

## Layout

```
<clone-dir>/
├── install.ps1              idempotent installer and verifier
├── AGENTS.md                binding rules — an agent reads this first
├── README.md                this file
├── INVENTORY.md             every server, skill, command, agent, script, repo
├── agents/                  navigator (default) · crawler · extractor · stealth · validator
├── commands/                /scrape · /crawl · /extract · /bypass · /newjob · /check-output
├── skills/                  tool-selection · crawl4ai · scrapling · firecrawl-mcp ·
│                            stealth-antibot · proxies-dataimpulse · llm-extraction ·
│                            social-media · api-capture · pagination · monitor-diff
├── plugins/
│   └── scrape-navigator/    prompt router + skill enforcement (route.js, 50 tests) + shell env hook
├── instructions/            scraping.md · subagents.md (global, deployed by -Link)
├── bin/                     oc-scrape · oc-robots · oc-proxy-test
├── config/                  opencode.json.example · dataimpulse env templates
├── scripts/                 clone-all · crawl4ai + scrapling starters
├── docs/                    CHEATSHEET.md · REPLICATION.md
├── jobs/                    per-job workspaces: HTML, JSONL, logs, validation report (gitignored)
├── output/                  scratch output (gitignored)
├── repos/                   17 cloned reference repos (gitignored, ~1 GB)
└── .venv/                   python environment (gitignored, created by installer)
```

### Where this maps to `opencode-hunt-stack`

Same skeleton, scraping vocabulary. Hunt concept → scrape equivalent:

| hunt-stack | this repo |
|---|---|
| `install.sh` | `install.ps1` (full / `-Link` / `-Check`) |
| `instruction.txt` | `instructions/` (two global files, deployed machine-wide) |
| `prompts/` (operating docs) | `skills/` + `instructions/` (the authority; the rest enforces them) |
| `plugins/scope-guard` | `oc-robots.ps1` gate + `/check-output` gate (no shell interception — scraping has no authorization boundary to guard, only allowlist/deny) |
| `plugins/navigator` + `default_agent: hunter`... `navigator` | `plugins/scrape-navigator` + `"default_agent": "navigator"` |
| `tests/` (must-fail fixtures) | `plugins/scrape-navigator/route.test.mjs` (must-pass router tests, run by `-Check`) |
| `oc-evidence` vault | `jobs/<name>/` workspace + `validation_report.md` |
| `oc-preflight` | `oc-robots.ps1` + `oc-proxy-test.ps1` (per-job pre-flight) |

## Changelog

- **2026-10-14** — Initial: installer (venv, pip libs, chromium, 17
  reference repos), 8 skills, 5 agents, 6 commands, 6 MCP servers,
  DataImpulse integration, `docs/REPLICATION.md`.
- **2026-10-14** — Second pass: `scrape-navigator` plugin (14 routes, 50
  router tests, per-prompt skill injection, shell env hook),
  `api-capture` / `pagination` / `monitor-diff` skills (11 total),
  `instructions/` global files, `navigator` as `"default_agent"` with the
  subagent-first policy, installer hardening (`$PSScriptRoot` paths, loud
  pip stages, `.example`-aware secret scan, `default_agent` + instructions
  merge).
- **2026-10-14** — README rewritten to the hunt-stack shape: agent
  handoff, prerequisites, auto-vs-manual table, the four ideas, full route
  table, research rationale, gotchas, verification, security posture,
  layout, changelog.
