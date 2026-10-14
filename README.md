# opencode data-scraping stack

A complete, opencode-native web scraping stack: open-source engines, MCP
servers, autonomous agents, and your **DataImpulse residential proxies** —
wired together with skills, commands, and hard rules that keep scrapes legal,
polite, and validated.

Modeled after [`opencode-hunt-stack`](https://github.com/Frappppy/opencode-hunt-stack):
binding `AGENTS.md`, a full `INVENTORY.md`, on-demand skills, subagents, and
an installer that deploys everything into `~/.config/opencode`.

---

## What you get

| Layer | Contents |
|---|---|
| **Agents** | `navigator` (orchestrator) · `crawler` · `extractor` · `stealth` · `validator` |
| **Commands** | `/scrape` `/crawl` `/extract` `/bypass` `/newjob` `/check-output` |
| **Skills** | tool-selection · crawl4ai · scrapling · firecrawl-mcp · stealth-antibot · **proxies-dataimpulse** · llm-extraction · social-media |
| **MCP servers** | firecrawl · playwright · brightdata · webmesh · scrapelab (stealth) · firecrawl-keyless |
| **Engines (cloned)** | crawl4ai · firecrawl · crawlee · scrapy · scrapling · MediaCrawler · camoufox · FlareSolverr · browser-use · skyvern + 7 more |
| **Your proxies** | DataImpulse rotating (`:823`/`:824`) + sticky (`:10000-20000`), env-var driven |

## Install (Windows)

```powershell
cd "D:\Code\Data Scraping"

# 1. full setup: venv, pip libs, playwright/chromium, camoufox, clone repos
powershell -ExecutionPolicy Bypass -File install.ps1

# 2. fill in your DataImpulse creds (gitignored)
notepad config\dataimpulse.local.env

# 3. verify proxies + environment
bin\oc-proxy-test.ps1 -Mode rotate

# 4. deploy agents/skills/commands + merge MCP config into ~/.config/opencode
powershell -ExecutionPolicy Bypass -File install.ps1 -Link

# 5. health gate (must be green)
powershell -ExecutionPolicy Bypass -File install.ps1 -Check
```

Restart opencode after step 4. Optional API keys (free tiers):
`FIRECRAWL_API_KEY`, `BRIGHTDATA_API_TOKEN` — set as environment variables,
never in files.

## Use it

```
/newjob price-watch https://example.com/products
/scrape https://example.com/product/123
/crawl https://example.com/docs 50 3
/extract jobs/price-watch "name, price, availability"
/bypass https://bot-walled.example.com/listing
/check-output jobs/price-watch
```

The `navigator` agent routes each request: robots check → cheapest engine →
skills on demand → `validator` gate before anything is called "done". Every
job lands in `jobs/<name>/` with raw HTML, JSONL, logs, and a
`validation_report.md`.

## Layout

```
├── AGENTS.md            binding rules — read first
├── README.md            this file
├── INVENTORY.md         every server, skill, command, agent, script, repo
├── install.ps1          setup / -Check / -Link
├── agents/              navigator, crawler, extractor, stealth, validator
├── commands/            scrape, crawl, extract, bypass, newjob, check-output
├── skills/              8 skills (tool-selection first)
├── bin/                 oc-scrape, oc-proxy-test, oc-robots
├── config/              opencode.json.example, dataimpulse templates
├── scripts/             clone-all, crawl4ai + scrapling starters
├── docs/CHEATSHEET.md   decision tree, one-liners, anti-detection checklist
├── jobs/                per-job workspaces (gitignored)
└── repos/               17 cloned reference repos (gitignored, ~1 GB)
```

## Where things live (and what survives a new session)

- **Everything on disk is permanent.** The stack is at `D:\Code\Data Scraping\`
  on your D: drive — a new opencode session on this machine finds it all.
- **Cloned repos** are under `repos/` (crawl4ai, firecrawl, camoufox, ...).
  They are **intentionally not in git** (1 GB of third-party code + licensing);
  `scripts/clone-all.ps1` re-fetches them on any machine in minutes.
- **Agents/skills/commands/MCP only auto-load** after `install.ps1 -Link`
  copies them to `~/.config/opencode/` — that's machine-global, so every
  future session on this box gets them. Project-local alternative: open
  opencode with this folder as the working directory and point your
  `opencode.json` here.
- **Your venv + browsers** (`.venv/`, chromium, camoufox) persist on disk.
- **Secrets** live only in `config/dataimpulse.local.env` (gitignored) and
  env vars — never in git, never in logs.

## Anti-bot ladder (summary)

`curl_cffi` TLS impersonation → header hygiene + pacing → **DataImpulse
residential rotating** → camoufox/nodriver stealth browser (sticky session)
→ ScrapeLab MCP → hosted unlocker (FlareSolverr / brightdata / Zyte).
CAPTCHA and auth walls are stop signals — ask, don't bypass. Full ladder:
`skills/stealth-antibot/SKILL.md`; one command: `/bypass <url>`.

## Hard rules (from AGENTS.md)

Public data only · robots.txt before the first request · ≥2s per-host pacing,
obey 429 · credentials via env vars only · evidence = files in `jobs/` ·
schema before LLM · `/check-output` before delivery · no auth/paywall bypass.

## License & ethics

Stack code: MIT (your repos). Cloned repos keep their own licenses (crawl4ai/
scrapy/crawlee Apache, firecrawl AGPL, camoufox MPL). Scraping public data
can still violate site ToS — you own that call. This stack is built to make
the legal path the easy path.
