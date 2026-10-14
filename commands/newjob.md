---
description: Scaffold a new scrape job workspace with process log and robots snapshot
---

New job: $ARGUMENTS

Arguments are `<job-name> <target-url>`.

Create exactly this, nothing outside it:

```
jobs/<job-name>/
├── README.md          (goal, target, schema, chosen engine)
├── process_log.md     (append decisions as you go, not after)
├── raw/               (HTML/markdown per URL)
├── parsed/            (records.jsonl, page.md)
└── logs/              (failures.log, bypass-recipe.md, robots.txt)
```

Then fill in:

1. `README.md`: what data is wanted, expected record shape, target URL(s),
   chosen engine + why (one paragraph).
2. Run `bin/oc-robots.ps1 <target-url>`; save the snapshot to
   `logs/robots.txt`. If disallowed, say so and stop.
3. First `process_log.md` entry: date, scope, plan.
4. If proxies will be used, note `DATAIMPULSE_*` env is loaded (never write
   the values).

Do not scrape anything yet. Report the scaffold path, the robots verdict, and
the plan — then proceed on confirmation.
