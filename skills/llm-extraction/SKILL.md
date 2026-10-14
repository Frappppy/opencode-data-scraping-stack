---
name: llm-extraction
description: Schema-driven LLM extraction - pydantic models, crawl4ai LLMExtractionStrategy, firecrawl /extract, litellm routing, validation loops, when NOT to use an LLM. Load when extracting structured data from heterogeneous or unstructured pages.
---

# llm-extraction

LLM extraction costs tokens and can hallucinate. Use it when selectors are
impractical — heterogeneous layouts, free-form text, no stable DOM.

## Rule zero

If the page has stable structure (prices in `.price`, rows in `<tr>`), use
CSS/XPath + pydantic. **Cheaper, faster, deterministic.** LLM is escalation.

## Pattern: schema → fetch → extract → validate

```python
from pydantic import BaseModel

class Product(BaseModel):
    name: str
    price: float | None
    currency: str | None = None
    in_stock: bool | None = None
```

1. Show the schema to the user if the request was vague.
2. Fetch (crawl4ai markdown, or firecrawl_scrape JSON with schema).
3. Extract with `LLMExtractionStrategy` (crawl4ai) or `firecrawl /extract`
   (schema or prompt). Route models via `litellm` if using local/multi-provider.
4. **Validate every row against the model.** On failure: one retry with the
   validation error in the prompt; then flag the row — never silently drop,
   never fabricate.

## firecrawl /extract

Pass the JSON schema (or a tight prompt). It runs an LLM pass on fetched
content and returns typed JSON. Costs an inference fee on top of the credit —
fine for spot enrichment, wrong for 100k pages.

## Emission

JSONL, one object per record, `_source_url` + `_extracted_at` always present,
nulls explicit. Then `validator` agent: null-rates, dupes, 3-row spot check.

## Anti-hallucination checklist

- Temperature 0 where the API allows.
- Never let the model "fill gaps" — a missing price is `null`, not a guess.
- Spot-check 3 rows against `_source_url` before delivery.
- If >20% of rows fail validation, the schema or the prompt is wrong — fix
  those, not the data.
