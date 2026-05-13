# vlm-card-extraction-prompts

Six production-tuned VLM prompts for scanned-document extraction. Marketplace plugin.

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install vlm-card-extraction-prompts@patientvibes-skills
```

## What's inside

- `skills/vlm-card-extraction-prompts/SKILL.md` — when-to-invoke + recommended pipeline + pairing notes.
- `skills/vlm-card-extraction-prompts/prompts/*.md` — six prompts:
  - `detection.md`
  - `verification.md`
  - `extraction.md`
  - `extraction_with_context.md`
  - `extraction_retry.md`
  - `audit.md`

## Pairs with

- `agent-tool-pdf-vlm-renderer` — render input
- `agent-tool-review-queue` — route low-confidence outputs
- `agent-tool-knowledge-wiki` — feed extraction-with-context

## Provenance

Extracted 2026-05-12 from `agent-harness-card-extractor`. See `D:/ai-agents/docs/superpowers/specs/2026-05-12-agent-toolbox-extraction-design.md`.
