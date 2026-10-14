# AGENTS.md — opencode data-scraping stack

Binding rules for any agent working in this repository or using this stack to
scrape. Read this before anything else, then `README.md`, then `INVENTORY.md`.

## Read in this order

1. **This file** — hard rules and the workflow.
2. **`skills/tool-selection/SKILL.md`** — which engine, every time, first.
3. **`README.md`** — install, components, and why the stack is shaped this way.
4. **`INVENTORY.md`** — every MCP server, skill, command, agent, script, repo.
5. **`docs/CHEATSHEET.md`** — quick patterns and the anti-detection checklist.
6. **`plugins/scrape-navigator/`** — routing context: prompts are auto-routed
   and the matching skill bodies are auto-injected into the request, so treat
   injected skill text as already-loaded context. If routing looks wrong, audit
   `~/.local/state/opencode-scrape/navigator.log` before guessing.

`navigator` is the default agent for every session and project — it routes
first and dispatches subagents to divide the work. The subagent-first policy
it follows lives in the global `instructions/subagents.md` (deployed
machine-wide by `-Link`).

## Hard rules

- **Legality before throughput.** Public data only. No auth bypass, no
  paywalls, no private data, no scraping behind a login unless the user owns
  the account and permits automation. If the request smells like surveillance,
  doxxing, or mass ToS violation — refuse.
- **robots.txt before the first request.** Run `bin/oc-robots.ps1 <domain>`.
  Save the snapshot to the job's `logs/`. If it disallows the path, stop and
  report — do not "try anyway".
- **Pace like a guest, not a DDoS.** ≥2s between requests per host (honor
  `Crawl-delay`). On `429`, obey `Retry-After` immediately. Two 403s with the
  same method → change method (stealth ladder), never repeat identically.
- **Credentials never touch the repo.** Proxies come from `DATAIMPULSE_*`
  env vars (`config/dataimpulse.local.env`, gitignored). No tokens, passwords,
  or `user:pass@` URLs in code, logs, output, or commits. Scrub them before
  writing any file.
- **Evidence is files, not prose.** Raw HTML/markdown, manifests, robots
  snapshots, validation reports — all under `jobs/<name>/`. A claim without a
  saved artifact is not a claim. Never fabricate or reconstruct "results".
- **Schema before LLM.** Stable structure → selectors/pydantic. LLM
  extraction only as escalation, always validated, nulls never filled in.
- **Validate before delivery.** `/check-output` (validator agent) must produce
  `validation_report.md` before any dataset is called done. Partial coverage
  is reported as partial — never round a gap away.
- **CAPTCHA and auth walls are stop signals.** Paid solvers only with explicit
  user approval. Never bypass authentication.

## Workflow

```
/newjob  →  tool-selection  →  scrape | crawl | extract | bypass
                                    ↓
                            validator (/check-output)
                                    ↓
                          delivery + validation_report.md
```

Subagents: `navigator` (default orchestrator), `crawler` (bulk),
`extractor` (structure), `stealth` (blocks), `validator` (gate).
Multi-step work (3+ steps) must be dispatched to subagents in parallel —
navigator's first move on every task (global `instructions/subagents.md`).
Skills load on demand via the names above — do not inline their content.
The `scrape-navigator` router injects the matching skill text for the current
prompt automatically: use what is already in the request, do not re-derive or
duplicate it.

## Environment rules

- Use the tool that exists; install into the stack venv (`.venv`) otherwise.
  Never `--break-system-packages`, never `curl | sh` from unknown hosts.
- Cloned third-party sources live in `repos/` (gitignored). Consult them as
  documentation; never edit them in place; never commit them.
- MCP tools load into every request forever; skills/commands load on demand.
  Knowledge belongs in skills — do not wrap CLI tools into new MCP servers
  without being asked.

## Working on this repo

- `powershell -File install.ps1 -Check` must be green before you push.
- `node plugins/scrape-navigator/route.test.mjs` must pass (all tests green)
  before you push — it is a gate, not a suggestion.
- New skills must be registered in `SKILL_IDS` **and** `ROUTES` in
  `plugins/scrape-navigator/route.js`, with a coverage probe for the skill in
  `plugins/scrape-navigator/route.test.mjs`, or the router will never attach it.
- Keep secrets out of the diff: run a scan for `DATAIMPULSE_PASSWORD`,
  `FIRECRAWL_API_KEY`, `API_TOKEN`, `user:pass@` patterns before every commit.
- Stack files only in git: `agents/ commands/ skills/ plugins/ instructions/
  config/ bin/ scripts/ docs/ *.md install.ps1 .gitignore`. Never `repos/`,
  `.venv/`, `jobs/`, `output/`.
- Match the existing style: skills/commands/agents are short, directive,
  frontmatter-described. Prefer a new skill over a longer one.
