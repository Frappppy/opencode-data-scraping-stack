---
name: Tool selection
description: Decision tree for picking the right scraping engine, MCP tool, or agent for a job - static vs JS vs anti-bot vs LLM-ready markdown vs structured extraction. Load FIRST for any scraping request before writing code.
---

# Tool selection

Pick the cheapest tool that reliably does the job. Loading a browser for a
static page wastes minutes and gets you blocked faster.

## Decision tree

```
One URL, need text/markdown?
├─ plain HTML → httpx / curl_cffi → oc-scrape (crawl4ai)
├─ JS-rendered → crawl4ai (renders by default) or Playwright MCP
└─ blocked (403/CF) → /bypass (stealth ladder)

Whole site / many URLs?
├─ ≤ few hundred pages, LLM-ready output → crawl4ai crawl (caps on!)
├─ need queues/retries/middleware → crawlee (Node) or scrapy (Python)
└─ already crawled → extract from jobs/<dir>/raw, do NOT refetch

Need structured JSON?
├─ stable layout → CSS/XPath + pydantic (scrapling adaptive if it shifts)
├─ embedded JSON (JSON-LD, __NEXT_DATA__) → parse it, always
└─ heterogeneous pages → llm-extraction skill (crawl4ai LLM / firecrawl /extract)

Inside opencode (MCP tools)?
├─ search web → firecrawl_search
├─ known URL → markdown → firecrawl_scrape or webmesh web_scrape
├─ whole site → firecrawl_crawl or webmesh web_crawl (capped!)
├─ click/type/login page → playwright tools or firecrawl_interact
├─ Amazon/LinkedIn/TikTok etc. → brightdata run_scraper (prebuilt)
└─ Cloudflare wall → scrapelab or brightdata scrape_as_markdown

Anti-bot?
└─ stealth-antibot skill — escalate ladder, never skip rungs
```

## Anti-patterns

- Playwright for a page that returns full HTML to plain `httpx`.
- LLM extraction on a page with stable `class="product-price"` selectors.
- Crawling without caps "to get everything" — you will get banned, not data.
- Re-fetching pages you already saved in `jobs/<dir>/raw/`.
- Hardcoding CSS class hashes (use Scrapling adaptive selectors).
