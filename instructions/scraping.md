# Data-scraping rules (global)

Applied to every session in every project when a task touches the public web.

1. **Robots first.** `bin/oc-robots.ps1 <domain>` before the first request;
   save the snapshot to the job's `logs/`. Disallowed → stop and report.
2. **Cheapest tool that works.** Static HTML → httpx/curl_cffi; JS → crawl4ai;
   blocked → stealth ladder (`stealth-antibot` skill). A browser is not a
   default. Schema before LLM.
3. **Credentials are env-only.** `DATAIMPULSE_*` and API keys from env /
   gitignored `config/*.local.env` — never in code, logs, output, or commits.
4. **Evidence is files.** Every claim lands in `jobs/<name>/` (raw, manifest,
   logs). Prose without a file is not a claim.
5. **Validate before "done".** `/check-output <job-dir>` must write
   `validation_report.md`; partial coverage is reported as partial.
6. **Public data only.** No auth bypass, no paywalls, no login-gated scraping
   without the user's own account and permission. CAPTCHA = stop and ask.
7. The `scrape-navigator` plugin injects the matching skill text automatically
   (log: `~/.local/state/opencode-scrape/navigator.log`) — if routing looks
   wrong, read the log before guessing.
