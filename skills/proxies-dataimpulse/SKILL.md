---
name: proxies-dataimpulse
description: DataImpulse residential proxies - rotating vs sticky ports, country/session/sessttl username parameters, curl/httpx/playwright/crawl4ai integration, env-var credentials only. Load when routing traffic through proxies or when a scrape needs IP rotation or geo-targeting.
---

# proxies-dataimpulse

You have DataImpulse residential proxies. Use them via environment variables —
**never hardcode credentials into scripts, logs, or commits.**

## Connection model

| Mode | Host:Port | Behavior |
|---|---|---|
| Rotating HTTP | `gw.dataimpulse.com:823` | new IP every request |
| Rotating SOCKS5 | `gw.dataimpulse.com:824` | new IP every request (SOCKS) |
| Sticky | `gw.dataimpulse.com:10000-20000` | same IP per port, 1–120 min |

Credentials live in `config/dataimpulse.local.env` (gitignored) — copy from
`config/dataimpulse.env.example`. Load with `bin/oc-proxy-test.ps1` or your
shell before running jobs.

## Username parameters (the `__` syntax)

Appended to login, delimiter `__`, params `key.value` joined by `;`:

```
login__cr.us:password@ gw.dataimpulse.com:823          # US exit
login__cr.de,au:password@...                            # Germany or Australia
login__cr.au;sessid.123:password@...                    # sticky IP id "123", ~30min
login__cr.fr;sessttl.60:password@...                    # rotate every 60 min
```

- `cr.<cc>` — country. `sessid.<x>` — hold one IP ~30 min. `sessttl.<min>` —
  rotation interval on rotating port.

## Integration snippets

```python
# httpx
proxies = {"http://": proxy_url, "https://": proxy_url}
r = httpx.get(url, proxies=proxies, timeout=30)

# curl_cffi (pair with TLS impersonation — best anti-bot combo)
from curl_cffi import requests
requests.get(url, impersonate="chrome124", proxies={"http": p, "https": p})

# playwright / crawl4ai BrowserConfig
proxy={"server": "http://gw.dataimpulse.com:823",
       "username": f"{login}__cr.{cc}", "password": pw}
```

## Rules

- **Verify first:** `bin\oc-proxy-test.ps1 -Mode rotate` → should print a
  residential exit IP, not yours.
- Rotating for bulk list-scraping; sticky/`sessid` for anything with state
  (carts, multi-step, "browse like a user" flows).
- Residential ≠ unlimited: still pace (≥2s), respect 429/Retry-After, and
  keep per-host volume sane. Proxies hide you; they do not grant permission.
- Never log the password. URLs in logs must be scrubbed of `user:pass@`.
- Only public data. Proxy + private data = the problem, not the solution.
