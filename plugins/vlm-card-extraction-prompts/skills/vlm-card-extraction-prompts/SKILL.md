---
name: vlm-card-extraction-prompts
description: Use when building a VLM-driven extraction pipeline for scanned PDFs containing structured cards (insurance cards, government IDs, membership cards, similar documents). Provides six production-tuned prompts covering the full detect → verify → extract → audit cycle, including retry-with-feedback for low-confidence extractions.
---

# vlm-card-extraction-prompts

## When to invoke

Building any VLM-driven document extraction pipeline where:
- Input is scanned PDFs (possibly multi-page) containing one or more bounded cards/regions per page.
- The structure is known enough that you can crop and re-extract focused regions.
- Output is structured data (e.g., Pydantic models) per region.
- You want human review for low-confidence outputs.

The prompt set was tuned against ID cards and insurance cards but the same shape applies to any structured single-page document.

## The 6 prompts

1. **DETECTION** (`prompts/detection.md`) — given a page image, return bounding boxes for each card region with Front/Back/Unknown labels and confidence scores.
2. **VERIFICATION** (`prompts/verification.md`) — given a cropped region, classify as FRONT / BACK / NOT_A_CARD to filter false-positive crops.
3. **EXTRACTION** (`prompts/extraction.md`) — extract structured fields from a verified Front crop.
4. **EXTRACTION_WITH_CONTEXT** (`prompts/extraction_with_context.md`) — same as EXTRACTION but with known patterns injected as system context (e.g., from a knowledge wiki).
5. **EXTRACTION_RETRY** (`prompts/extraction_retry.md`) — re-extract with explicit issue feedback after a verification failure.
6. **AUDIT** (`prompts/audit.md`) — given a full page image, count visible cards (used for sanity-checking the detection step).

## Recommended pipeline

```
Page image
  ↓ DETECTION → bounding boxes
  ↓ crop each Front/Unknown region
  ↓ VERIFICATION (if Unknown) → keep / drop
  ↓ EXTRACTION (or EXTRACTION_WITH_CONTEXT if wiki has rules for the issuer)
  ↓ validate (deterministic — patterns, hallucination filters)
  ↓ if invalid: EXTRACTION_RETRY → revalidate (max 1 retry)
  ↓ if confidence < threshold: route to human review
  ↓ accept / reject
  ↓ AUDIT page → did we miss any cards? (run conditionally)
```

## Consuming

Load each prompt at runtime:

```python
from importlib.resources import files

PROMPT_DIR = files("vlm_card_extraction_prompts") / "prompts"
DETECTION = (PROMPT_DIR / "detection.md").read_text()
# format with placeholders at call time:
prompt = DETECTION.format(detection_confidence=0.85)
```

Or vendor copies into your harness (matches the `csd-form-analysis` precedent — see `agent-harness-chorus-csd-analyzer` for the vendoring pattern).

## Pairs well with

- [`agent-tool-pdf-vlm-renderer`](https://github.com/PatientVibes/agent-tool-pdf-vlm-renderer) — render PDF pages to VLM-ready PNGs.
- [`agent-tool-review-queue`](https://github.com/PatientVibes/agent-tool-review-queue) — route low-confidence extractions for human review.
- [`agent-tool-knowledge-wiki`](https://github.com/PatientVibes/agent-tool-knowledge-wiki) — feed `{wiki_context}` placeholder in EXTRACTION_WITH_CONTEXT.
- Skill: `verification-retry-loop` — the pattern that drives EXTRACTION_RETRY.

## Provenance

Extracted 2026-05-12 from `agent-harness-card-extractor/card_extractor/prompts.py`.
