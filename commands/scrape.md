---
description: Scrape a single URL to clean markdown (and optionally JSON) with crawl4ai
---

Scrape: $ARGUMENTS

Arguments are `<url> [json]`. Default output is markdown; pass `json` for
schema-assisted extraction (then ask which fields).

1. Load `tool-selection`, then `crawl4ai` skill.
2. Run `bin/oc-robots.ps1 <url>` — obey the result.
3. Create the job scaffold if none exists:
   `jobs/scrape-<host>-<yyyyMMdd-HHmmss>/{raw,parsed,logs}`.
4. Fetch via `bin/oc-scrape.ps1 <url>` or the venv Python with
   `CrawlerRunConfig(cache_mode=CacheMode.BYPASS, page_timeout=60000)`.
5. Save raw HTML to `raw/`, markdown to `parsed/page.md`.
6. If the page is JS-empty or returns 403, escalate per `stealth-antibot`
   (curl_cffi → DataImpulse → stealth browser) and log each attempt.
7. Report: path to markdown, byte count, and anything skipped (paywall,
   CAPTCHA, consent wall).
