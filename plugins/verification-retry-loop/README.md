# verification-retry-loop

The "extract → verify → retry once with feedback" pattern for structured LLM output.

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install verification-retry-loop@patientvibes-skills
```

## Quick read

See `skills/verification-retry-loop/SKILL.md` for when-to-apply, the canonical pattern, and anti-patterns. See `skills/verification-retry-loop/examples/` for the two production implementations the pattern was abstracted from.

## Pairs with

- `agent-tool-llm-utils` (retry_async — for network-level retries, separate concern)
- `agent-tool-review-queue` (route unsalvageable items)
- `agent-tool-pipeline-trace` (record verification outcomes)

## Provenance

Pattern extracted 2026-05-12 from agent-harness-chorus-csd-analyzer + agent-harness-card-extractor. See `D:/ai-agents/docs/superpowers/specs/2026-05-12-agent-toolbox-extraction-design.md`.
