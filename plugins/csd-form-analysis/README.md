# csd-form-analysis

Skill for analyzing SS&C AWD CSD binary forms during migration to Chorus Classic.

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install csd-form-analysis@patientvibes-skills
```

## What's inside

- `skills/csd-form-analysis/SKILL.md` — when-to-invoke + workflow checklist + ground rules summary.
- `skills/csd-form-analysis/prompts/system_prompt.md` — verbatim system prompt with `{knowledge}` placeholder for harness consumption.
- `skills/csd-form-analysis/knowledge/awd_reference.md` — AWD domain reference (loaded into the prompt).

## Consumed by

[`agent-harness-chorus-csd-analyzer`](https://github.com/PatientVibes/agent-harness-chorus-csd-analyzer) — vendors copies of the prompt and knowledge files so it can run standalone.

## Provenance

Extracted 2026-05-12 from `d:/ai-agents/chorus-agent/web/agent.py:419-472` + `d:/ai-agents/chorus-agent/knowledge/awd_reference.md` as part of the chorus-agent split. See `D:/ai-agents/docs/superpowers/specs/2026-05-12-reference-agents-migration-design.md`.
