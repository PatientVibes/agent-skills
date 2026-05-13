# human-review-loop

Pattern: gate agent output by confidence + route low-confidence items to a human review queue + feed corrections back as wiki rules.

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install human-review-loop@patientvibes-skills
```

## Quick read

See `skills/human-review-loop/SKILL.md` for when-to-apply, the canonical pattern, and anti-patterns.

## Pairs with

- `agent-tool-review-queue` (the queue infrastructure)
- `agent-tool-knowledge-wiki` (the learning destination)
- Skill `verification-retry-loop` (apply first; catch fixable issues before queuing for human)

## Provenance

Pattern extracted 2026-05-12 from `agent-harness-card-extractor`. See `D:/ai-agents/docs/superpowers/specs/2026-05-12-agent-toolbox-extraction-design.md`.
