---
description: Escalate past bot protection on a blocked URL using the stealth ladder
---

Bypass: $ARGUMENTS

Arguments are `<url>` — a public page that returned 403/429/JS-challenge/CAPTCHA
when scraped normally.

1. Load `stealth-antibot` + `proxies-dataimpulse`. Hand off to the `stealth`
   agent. Confirm the page is public data — **never** use this on login walls,
   paywalls, or authenticated areas.
2. Log the original block: status, body snippet, evidence file in the job dir.
3. Walk the ladder in order, one rung at a time, logging each attempt:
   curl_cffi impersonate → better headers/pacing → DataImpulse residential
   rotating (`:823`, env credentials) → camoufox/nodriver stealth browser
   (sticky session if a flow needs one IP) → ScrapeLab MCP → hosted unlocker
   (ask before spending credits).
4. CAPTCHA → stop; ask the user before any paid solver.
5. On success: save the working method (engine + proxy mode + fingerprint) to
   `jobs/<name>/logs/bypass-recipe.md` so the next run reuses it.
6. Report the winning rung honestly — "cleared on rung 3 with residential
   rotating" is the deliverable.
