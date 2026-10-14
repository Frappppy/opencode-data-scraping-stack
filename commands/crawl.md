---
description: Crawl a site (or subtree) with caps, dedup, and rate limiting
---

Crawl: $ARGUMENTS

Arguments are `<url> [maxPages] [maxDepth]`. Defaults: maxPages=30, maxDepth=2.

1. Load `tool-selection`, then `crawl4ai` (or `crawlee`/`scrapy` if the user
   asks for queues at scale). Hand bulk work to the `crawler` agent.
2. `bin/oc-robots.ps1 <url>` first. If robots disallows the subtree, stop and
   report — do not crawl.
3. Scaffold `/newjob crawl-<host>-<date>` if needed. Save the robots.txt
   snapshot into the job dir.
4. Map first (`sitemap.xml` or link discovery); log discovered URL count
   before fetching.
5. Crawl with the given caps, ≥2s per-host delay, dedup on canonical URL,
   cache on. Manifest: `manifest.jsonl` (url, status, path, bytes, time).
6. Failures go to `logs/failures.log`; 429 → backoff; 403 twice → `stealth`
   agent for the whole run, not per-page panic.
7. Finish with `validator` (`/check-output <job-dir>`): pages fetched vs
   mapped, null shells, dedup. Deliver the report, not a cheer.
