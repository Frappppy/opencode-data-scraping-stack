---
name: firecrawl-mcp
description: Routing to Firecrawl MCP tools - scrape vs map vs crawl vs search vs interact vs agent, keyless endpoint, credit discipline, when NOT to use Firecrawl. Load when a Firecrawl MCP tool is available and you must pick the right one.
---

# firecrawl-mcp

Firecrawl MCP gives the agent web tools: search, scrape, crawl, map, interact,
agent. Server: `repos/mcp-servers/firecrawl-mcp-server`. Key:
`FIRECRAWL_API_KEY` (free 1,000 credits/mo) or keyless remote
`https://mcp.firecrawl.dev/v2/mcp` (3 tools only).

## Tool routing

| Situation | Tool |
|---|---|
| Known URL, want content | `firecrawl_scrape` (JSON format if you have a schema) |
| Need the list of URLs on a site | `firecrawl_map` — cheap discovery before crawling |
| Many pages under one site | `firecrawl_crawl` — ALWAYS set `limit`, `includePaths`/`excludePaths` |
| Starting from a question, no URL | `firecrawl_search` (+ `scrapeOptions` if you also want content) |
| Page needs click/type/scroll first | `firecrawl_interact` (fresh `url` or existing `scrapeId`) |
| Unknown URLs, multi-site research | `firecrawl_agent` — describe fields + schema; cap `max_credits` |
| Files (PDF/DOCX) | `firecrawl_parse` |

## Credit discipline

- 1 credit ≈ 1 page — **404s and failed scrapes still cost**. Map first,
  scrape what matters.
- `firecrawl_agent` and stealth extras burn faster; set `max_credits`.
- For bulk high-volume work, crawl4ai (free, self-hosted) beats credits.
- Never fire `firecrawl_crawl` without a limit "to see what happens".

## When NOT to use Firecrawl

- Data must stay local (VPC/privacy) → crawl4ai self-hosted.
- You already have raw HTML in `jobs/<dir>/raw/` → extract locally.
- Simple static page → httpx costs nothing.
- Heavy anti-bot at scale → brightdata/zyte unlockers, or stealth stack.

## Profiles & sessions

`firecrawl_interact` supports named profiles
(`scrapeOptions.profile`) to persist cookies/localStorage across turns —
use for multi-step flows, then `interact_stop` to save.
