# Scraping Cheatsheet

## Decision tree
```
Need data from a URL?
├─ Static HTML? → httpx + BeautifulSoup / parsel
├─ JS-rendered / SPA? → crawl4ai or Playwright
├─ Site blocks bots? → camoufox / nodriver / ScrapeLabMCP / FlareSolverr
├─ Feeding an LLM / RAG? → crawl4ai or firecrawl (markdown output)
├─ Site breaks often? → Scrapling (self-healing selectors)
├─ Social media? → MediaCrawler / brightdata scrapers
└─ Don't want to code? → MCP server (firecrawl / brightdata) via opencode
```

## Python one-liners
```python
# static fetch + clean article text
import httpx, trafilatura
html = httpx.get(url, headers={"User-Agent":"Mozilla/5.0"}).text
text = trafilatura.extract(html)

# JA3-fingerprint-impersonating request (beats TLS fingerprinting)
from curl_cffi import requests
r = requests.get(url, impersonate="chrome124")

# async concurrent crawl
import asyncio, httpx
async with httpx.AsyncClient() as c:
    pages = await asyncio.gather(*[c.get(u) for u in urls])
```

## Anti-detection checklist
1. Real browser fingerprint → camoufox (Firefox) or nodriver (Chrome)
2. TLS/JA3 fingerprint → curl_cffi impersonate
3. Residential proxy → brightdata / oxylabs (datacenter IPs get banned fast)
4. Realistic headers + timeout pacing + jittered delays
5. CAPTCHA → 2captcha / capSolver
6. Session persistence → keep cookies/localStorage between requests
7. Respect robots.txt + ToS; rate-limit ethically

## MCP tool routing (in opencode)
| Task | Tool |
|---|---|
| Search the web | `firecrawl_search` |
| Known URL → markdown | `firecrawl_scrape` or `web_scrape` |
| Whole site | `firecrawl_crawl` or `web_crawl` |
| Click/fill/login | `playwright` tools or `firecrawl_interact` |
| Cloudflare-protected | `scrapelab` or `brightdata scrape_as_markdown` |
| Structured JSON (Amazon/LinkedIn/...) | `brightdata run_scraper` |
| Check if page changed | `web_diff` (webmesh) |
| Token-cheap verification | `web_check` (webmesh) |

## Scaling tips
- Queue > loop: use crawlee or scrapy for dedup/queues/politeness
- Cache aggressively (SQLite/Redis) — never re-fetch unchanged pages
- Batch: firecrawl `/crawl`, brightdata `scrape_batch` (10/call)
- Extract with schema (pydantic) not regex
- Monitor with `firecrawl /monitor` or `web_diff` instead of full re-crawls
