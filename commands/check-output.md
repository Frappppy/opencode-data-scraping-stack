---
description: Validate a job directory's output — schema, dedup, coverage, compliance — and write the validation report
---

Check output: $ARGUMENTS

Arguments are `<job-dir>` (e.g. `jobs/my-crawl-20261014`).

1. Hand off to the `validator` agent. Run every check it defines:
   schema conformance, dedup, coverage vs manifest/map, freshness/integrity,
   robots + rate compliance, 3-row live spot-check.
2. Write `jobs/<dir>/validation_report.md` with PASS/FAIL per check and hard
   numbers (rows, nulls, dupes, missing pages).
3. On FAIL: list exactly what the `extractor`/`crawler` must redo. Do not
   patch data yourself unless the user asks.
4. Final message = the verdict line from the report plus the report path.
   If coverage is partial, the partial number leads — never round a gap away.
