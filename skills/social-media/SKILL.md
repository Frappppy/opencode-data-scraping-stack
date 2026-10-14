---
name: social-media
description: Scraping social platforms - MediaCrawler for X/Douyin/Xiaohongshu/Bilibili, brightdata prebuilt scrapers for Instagram/TikTok/LinkedIn/Reddit, login walls, legal boundaries. Load when the target is a social platform.
---

# social-media

Social platforms are the hardest public-web targets: login walls, infinite
scroll, aggressive anti-bot, and volatile DOMs. Prefer APIs/prebuilt scrapers
over rolling your own.

## Platform → tool

| Platform | First choice | Fallback |
|---|---|---|
| X/Twitter, Douyin, Xiaohongshu, Bilibili, Kuaishou | **MediaCrawler** (`repos/core/media-crawler`) | brightdata scrapers |
| Instagram, TikTok, Facebook | brightdata MCP `run_scraper` (prebuilt) | stealth browser + sticky proxy |
| LinkedIn | brightdata/Decodo LinkedIn scraper | NEVER bypass login — public profiles only, ToS risk |
| Reddit, YouTube | brightdata scrapers or official JSON/RSS (`/.json` endpoints) | crawl4ai on public pages |
| npm / PyPI / Crunchbase | brightdata MCP prebuilt | plain HTTP |

## MediaCrawler

`repos/core/media-crawler` — config-driven (`config/`), cookie login for your
own account on platforms you have rights to. Read its README before running;
platform ToS and local law still apply.

## Common realities

- **Login walls:** if content requires auth, only proceed with an account the
  user owns and where automation is permitted. Scraping behind login against
  ToS is off-limits in this stack (AGENTS.md).
- **Infinite scroll:** need a browser + `scan_full_page`/scroll steps
  (crawl4ai) or the platform's own paginated API when public.
- **Rate limits:** social platforms ban fast. Sticky sessions + low volume +
  long gaps. Residential IPs help but do not make it safe to hammer.
- **Public JSON sugar:** Reddit posts accept `.json` suffix; many "apps" call
  a public API you can call directly with a proper UA — check dev tools first
  before rendering a whole page.

## Legal note

Public data ≠ unlimited license. Respect ToS, copyright of posts, and any PII
regulations (GDPR etc.). When the job smells like surveillance, mass
doxxing, or impersonation — stop and refuse.
