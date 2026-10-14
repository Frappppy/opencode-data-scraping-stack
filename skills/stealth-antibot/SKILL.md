---
name: stealth-antibot
description: Escalation ladder for blocked scrapes - curl_cffi TLS impersonation, header hygiene, DataImpulse residential, camoufox, nodriver, FlareSolverr, ScrapeLab MCP, hosted unlockers. Load when a request returns 403/429/JS-challenge/CAPTCHA.
---

# stealth-antibot

Blocked? Escalate one rung at a time. Repeat attempts with the same
fingerprint/proxy are wasted traffic and get you burned deeper.

## Ladder (stop at first success)

### 1. curl_cffi — TLS/JA3 impersonation
```python
from curl_cffi import requests
r = requests.get(url, impersonate="chrome124")   # matches real Chrome TLS
```
Many WAFs block on JA3 fingerprint alone. This clears them with zero stealth
cost. Try before anything else.

### 2. Header hygiene + pacing
Real `User-Agent`, `Accept-Language`, `Accept`, referer from a prior page.
Jittered delays (2–5s). Fix `requests` library defaults that scream "bot".

### 3. DataImpulse residential rotating
`gw.dataimpulse.com:823` — real residential IPs. See `proxies-dataimpulse`
skill. Datacenter IPs are pre-burned on most WAFs.

### 4. Stealth browsers
- **camoufox** (`repos/anti-bot/camoufox`): anti-fingerprint Firefox.
  `pip install camoufox && camoufox fetch`
- **nodriver**: successor of undetected-chromedriver — no `navigator.webdriver`.
- **playwright-stealth**: `pip install playwright-stealth` (patches, weaker
  than the above).

Sticky session (`sessid`) when a flow must hold one IP across requests.

### 5. ScrapeLab MCP (`scrapelab`)
84-tool stealth browser, auto cookie-consent dismiss (100+ CMPs), CDP access.
Enable in opencode config when you hit Cloudflare/DataDome interstitials.

### 6. Hosted unlockers
- **FlareSolverr** (`repos/anti-bot/flaresolverr`): self-hosted CF proxy.
- **brightdata MCP** `scrape_as_markdown`: unblocking built into every request.
- Zyte / Scrapfly / ScraperAPI: paid, reliable, per-page cost.

## Hard rules

- **CAPTCHA = stop.** Ask before any paid solver (2captcha/capSolver).
- **Never bypass auth, paywalls, or private data.** Public pages only.
- Log every rung + outcome to `logs/bypass-recipe.md`; reuse what works.
- After 2 identical failures, change a variable — fingerprint, proxy mode,
  or engine. Never the third identical try.
