---
name: scrapling
description: Self-healing extraction with Scrapling - adaptive selectors that survive site redesigns, Fetcher vs StealthyFetcher, when to prefer it over hardcoded CSS. Load when extracting structure from pages that change layout.
---

# scrapling

Python lib (~67k stars) whose **adaptive selectors** re-find elements even
when classes/DOM shift — the fix for scrapers that die on redesigns.
Source + docs: `repos/core/scrapling`.

## Install

```
pip install scrapling
# for browser fetchers:
playwright install chromium   # or: camoufox fetch
```

## Two fetchers

```python
from scrapling.fetchers import Fetcher          # plain HTTP, fast
from scrapling.fetchers import StealthyFetcher  # real browser, stealthy

page = Fetcher.get("https://example.com")
# page = StealthyFetcher.fetch("https://example.com", headless=True)
```

Use `Fetcher` first; only go `StealthyFetcher` when the page is JS-empty or
blocks plain HTTP. (Starter: `scripts/starter_scrapling.py`.)

## Extraction

```python
# Adaptive: survives class-name churn — prefer this over raw CSS on brittle sites
for h in page.css("h2.title"):
    print(h.text, h.attrib.get("href"))

# When you know the page shifts, lean on semantic/structural anchors:
# tables, itemprop, data-* attrs, heading hierarchy — not .css-1x2ab3c
```

Consult `repos/core/scrapling` README for the current adaptive-matching and
`wait_for` APIs — the library moves fast; trust the cloned source over memory.

## When to choose scrapling over crawl4ai

| | crawl4ai | scrapling |
|---|---|---|
| Best at | bulk markdown for LLMs | precise, redesign-proof extraction |
| Output | clean markdown pages | typed fields from HTML |
| Pair it | crawl the site | extract from saved raw/ |

Ideal pipeline: crawl4ai (or crawler agent) saves `raw/` → scrapling extracts
from those files without refetching.
