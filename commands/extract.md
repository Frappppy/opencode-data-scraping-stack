---
description: Extract structured fields from a URL (or already-crawled job dir) into JSONL
---

Extract: $ARGUMENTS

Arguments are `<url | job-dir> <field1, field2, ...>` (fields in plain English
or exact schema keys).

1. Load `llm-extraction` only if structure is unclear; otherwise `scrapling`
   for adaptive selectors. Hand off to the `extractor` agent.
2. Define the Pydantic schema for the requested fields. Show it in one short
   block before extracting so mismatches surface early.
3. Source: fetch the URL (with robots check) or reuse `jobs/<dir>/raw/`.
   Reuse raw when present — never refetch what you already have.
4. Extract: stable selectors/JSON-LD first; LLM strategy only as escalation.
   Validate every row against the schema; retry once, then flag the row.
5. Write `jobs/<name>/parsed/records.jsonl` with `_source_url` +
   `_extracted_at` on each record.
6. Run `validator` before reporting: row count, null-rate per field, dupes,
   3-row spot check. Report numbers, not adjectives.
