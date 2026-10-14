---
name: api-capture
description: Reuse a site's own backing API (XHR/fetch/HAR) instead of scraping rendered HTML - lighter, faster, less likely to be blocked. Load when DevTools/network show JSON responses, when pages are shells over an API, or when direct endpoints are suspected.
---

# api-capture

Most modern pages are a thin shell over JSON endpoints. Calling the API the
page itself calls is **the single biggest success-rate lever**: no rendering,
no layout breakage, no consent-wall markup, tiny responses.

## How to find the endpoint

1. Open the page in Playwright MCP / ScrapeLab / browser DevTools and list
   network requests (`scraping_browser_network_requests`, ScrapeLab
   `search_network_requests`, or CDP Network). Filter `fetch`/`XHR`.
2. Typical payload URLs: `/api/`, `/_next/data/`, `graphql`, `?output=json`,
   `format=json`, `/wp-json/`, `/v1|v2/`. Reddit: append `.json` to any URL.
3. Read the **request the page makes after scroll/click** — the real data call
   often fires only after interaction (`firecrawl_interact` or `web_interact`
   to trigger, then capture).
4. Save the recipe: method, URL, required headers, query/body params →
   `jobs/<name>/logs/api-recipe.md`.

## Replay rules

```bash
# replay with browser TLS fingerprint + your proxy (see curl_cffi / dataimpulse skills)
curl_cffi: requests.get(url, impersonate="chrome124", headers={...}, proxies=...)
```

- Send only the headers that matter: `Accept`, `Referer`, `Origin`, and any
  **public** client key the site ships to everyone (anon API keys in JS
  bundles are public by design).
- **Never replay a session token, cookie, or `Authorization` header belonging
  to an account.** That crosses from "reading public data" into unauthorized
  access — out of scope for this stack, always.
- Keep pacing: the API rate-limits harder than the page did. 429 → backoff.

## When the API fights back

- **Signed/nonce params** → capture the full request with HAR and replay
  quickly, or fall back to rendering (the browser computes the signature).
- **One-time tokens** → drive the browser once to mint, then reuse within TTL.
- **gRPC/websocket** → use the browser; do not reverse the protocol by hand.

## Pair with

- `pagination` — API pagination is usually cursor/offset params, not pages.
- `proxies-dataimpulse` — rotate when the API 429s by IP.
- `stealth-antibot` — only after API replay fails; rendering is the fallback,
  not the first move.
