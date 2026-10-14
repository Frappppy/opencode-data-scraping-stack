---
name: monitor-diff
description: Change detection and re-scraping over time - local diff of saved raw, webmesh web_check/web_diff, firecrawl /monitor, scheduling and alerting. Load when tracking prices/stock/availability or "notify me when this changes".
---

# monitor-diff

Monitoring is mostly *not* re-crawling: diff what you already have, fetch only
when it matters, alert without spamming.

## Ladder (cheapest first)

1. **Local hash diff** — you already have `jobs/<name>/raw/`. Re-fetch the page
   (rate-limited), normalize, diff against baseline. No new tools needed.
2. **`web_check` / `web_diff` (webmesh MCP)** — returns `pass: true` + a
   200-char snippet, never the full page. Token-cheap; `web_diff` remembers
   the last state (SQLite) and answers `changed: bool`. Use for assertions
   ("is the price still X") and change checks.
3. **`firecrawl /monitor`** — hosted recurring checks with diffs. Costs
   credits; set the cadence honestly (minutes, not seconds).
4. **Full job re-run** — only when structure changed or monitoring missed
   something; reuses cache, validates with `validator`.

## Making diffs clean (kill false positives)

Strip volatile bits **before** comparing:
- timestamps, view counters, ad slots, CSRF tokens, `nonce`, rotating image
  URLs, session ids in hrefs, "X minutes ago" text.
- Normalize whitespace and attribute order; compare extracted *fields*, not
  raw bytes, when a schema exists.
- Prefer semantic diffs: price field, "In stock" text, table rows — via
  `web_check` with `text_equals`/`selector_exists`.

## Schedule & state

```
jobs/<name>/monitor/
├── baseline.html     (or baseline.json of extracted fields)
├── state.json        (last check, last hash, consecutive-equal count)
└── history.log       (ts, changed, snippet)
```

- Cadence: match volatility — prices daily, tickets hourly, docs weekly.
  Jitter the schedule; obey `Crawl-delay`.
- Alerting: your **ntfy** stack (topic from `NTFY_TOPIC` env — never commit it)
  or log-only. Notify on *change*, not on every check; debounce repeats.
- First run = baseline, not an alert.

## Rules

- Same robots/pacing rules as crawling — monitoring multiplies request count
  over time; keep the per-day budget explicit.
- Record every check in `history.log` — an alert without a log line is a rumor.
