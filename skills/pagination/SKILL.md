---
name: pagination
description: Finding and following pagination correctly - rel=next, page/cursor/offset params, infinite scroll, load-more, plus pagination traps and dedup. Load when a crawl must go beyond one page or when crawls loop, stall, or return duplicates.
---

# pagination

#1 crawl failure mode after bot-walls: the crawler never leaves page 1, or
walks a facet loop forever. Decide the mechanism before crawling.

## Patterns (in order of preference)

| Pattern | Detect | Follow |
|---|---|---|
| `rel="next"` link | semantic, best signal | parse `a[rel=next]` |
| Page numbers | `?page=2`, `/page/2/`, `p=`, `pg=` | increment; find max from UI |
| Cursor/offset | `?cursor=...`, `?offset=100` | follow returned `next` cursor |
| API envelope | JSON has `next`/`total_pages` | see `api-capture` skill |
| "Load more" button | button/AJAX append | `js_code`: click + wait (`crawl4ai`) |
| Infinite scroll | content grows on scroll | `scan_full_page` + `scroll_delay`, or scroll-until-stable loop |

**Verify, don't assume:** after fetching 3+ pages, hash page bodies — 3
distinct hashes and monotonic page markers mean pagination actually works.

## Traps (why crawls loop or explode)

- **Faceted URLs:** `/category/x?color=red&sort=price` × thousands — exclude
  sort/filter params, whitelist `page`/`cursor` only.
- **Calendar/date loops** and archive trees — cap by date range.
- **Session IDs in URLs** (`;jsessionid=`, `?sid=`) — strip before dedup.
- **"Endless" archive pagination** (page 1..10^6) — set `maxPages`, discover
  the real end from the UI (last-page link or total count).
- Distinct URLs, same content (view=all, print pages) — dedup by content hash,
  not URL alone.

## crawl4ai setup

```python
CrawlerRunConfig(
    scan_full_page=True, scroll_delay=0.5,        # infinite scroll
    js_code="document.querySelector('.load-more')?.click()",
    exclude_external_links=True,
    # exclude pattern for facet params:
    # exclude_patterns=["sort=", "session="]
)
```

Link discovery: map first (`sitemap.xml` / `firecrawl_map`), then crawl only
URLs matching `include_patterns` (`/docs/*`). See `crawl4ai` + `tool-selection`.
