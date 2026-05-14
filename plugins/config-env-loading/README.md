# config-env-loading

Convention for loading API keys + secrets in `agent-tool-*` / `agent-harness-*` CLIs.

## Install

```bash
/plugin marketplace add D:/agent-skills
/plugin install config-env-loading@patientvibes-skills
```

## Quick read

See `skills/config-env-loading/SKILL.md` for the directory layout, the ~20-line Python loader, the 1Password integration recipe, and anti-patterns.

The convention in one sentence: **a CLI reads its API key from `os.environ` first; if absent, falls back to sourcing `~/.config/<tool-name>/env` (mode 600).**

## Why a skill instead of a shared helper module

The loader is ~20 lines of zero-dependency Python. Vendoring is cheaper than a shared package — three consumers can each copy-paste without versioning friction. If/when 4+ consumers exist and the loader gains real complexity (per-platform paths, schema validation), promote to a tool repo.

## Provenance

Convention proved out in `agent-tool-llm-proofreader` (2026-05-09). Documented as a skill 2026-05-14 once the second consumer (anticipated: kindle-pipeline subprocess orchestrator, then any future API-key-needing tool) made the pattern worth naming.

See `D:/ai-agents/todo.md` section A2 history and `[[project_patientvibes_personal_org]]` memory.
