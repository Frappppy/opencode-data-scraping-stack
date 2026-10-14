---
name: crawl4ai
description: Using crawl4ai for LLM-ready markdown crawls - AsyncWebCrawler, CrawlerRunConfig, caching, wait_for, JS execution, extraction strategies, DataImpulse proxy config. Load when crawling or scraping with crawl4ai.
---

# crawl4ai

Open-source Playwright-based crawler that emits clean markdown (~67% fewer
tokens than raw HTML). Source + full docs: `repos/core/crawl4ai`.

## Install (once)

```
pip install crawl4ai && playwright install chromium
```

## Single page → markdown

```python
import asyncio
from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode

async def main(url):
    browser = BrowserConfig(headless=True)
    run = CrawlerRunConfig(
        cache_mode=CacheMode.BYPASS,
        page_timeout=60_000,
        scan_full_page=True,
        scroll_delay=0.5,
        wait_for="css:.content-loaded",   # per-site: wait for the real content
    )
    async with AsyncWebCrawler(config=browser) as c:
        r = await c.arun(url, config=run)
        print(r.markdown if r.success else r.error_message)

asyncio.run(main("https://example.com"))
```

Or: `bin/oc-scrape.ps1 <url>` / `scripts/starter_crawl4ai.py`.

## Key CrawlerRunConfig options

| Option | Use |
|---|---|
| `wait_for` | css:/xpath:/js: selector that means "content is ready" |
| `js_code` | run JS before extract (open accordions, click tabs) |
| `scan_full_page` + `scroll_delay` | trigger lazy-load/infinite scroll |
| `exclude_external_links` | keep crawls on-domain |
| `cache_mode` | `ENABLED` for re-runs, `BYPASS` when freshness matters |
| `extraction_strategy` | `JsonCssExtractionStrategy(schema)` or `LLMExtractionStrategy` for structured output |
| `page_timeout` | raise to 60000 for slow SPAs |

## DataImpulse proxy

```python
browser = BrowserConfig(
    proxy={"server": "http://gw.dataimpulse.com:823",
           "username": os.environ["DATAIMPULSE_LOGIN"] + "__cr.us",   # see proxies-dataimpulse skill
           "password": os.environ["DATAIMPULSE_PASSWORD"]},
)
```

## Failure modes

- **Empty markdown** → page needs `wait_for` or scroll; or it's a consent
  wall (try stealth-antibot / ScrapeLab auto-dismiss).
- **403** → escalate: curl_cffi → DataImpulse residential → stealth browser.
- **Missed content** → add `js_code` or `wait_for`; check `r.html` raw size.
- Never crawl without caps — set `maxPages`/depth via the crawler agent norms.
