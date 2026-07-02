# ship

Autonomous branch → PR → external review → merge subagent. Plugin in the `patientvibes-skills` marketplace.

## Status: v2

Depends on the `pr-review` subagent in [`pr-review-tools`](../pr-review-tools/) as the external reviewer, with the `/code-review` plugin (`claude-plugins-official`) as the fallback. The `pr-review` subagent wraps the [`agent-tool-pr-reviewer`](../../../agent-tool-pr-reviewer/) CLI in multi-model consensus mode (Claude Opus 4.7 + GPT-5.3 Codex + Gemini 3.1 Pro). `gh` must be authenticated.

> **v2 change:** the `codex` CLI is no longer used (account access removed). The `pr-review` subagent is now the primary external reviewer.

**No opencode / ad-hoc OpenRouter reviewer in any path** — only the pinned `agent-tool-pr-reviewer` basket (via the `pr-review` subagent), whose models, filtering, and consensus are deterministic.

## Agents

### `ship`

Dispatched when the user has approved a plan and said "ship it", "go ahead", "implement and merge", or types `/ship`. Drives an approved change from a clean working tree to a merged PR with no human checkpoints in between, except for the explicit pause points documented in the agent's "Guardrails" section.

External-review ladder:

1. **Primary:** dispatch the `pr-review` subagent — runs `agent-tool-pr-reviewer review` with the pinned Claude-free basket (GPT-5.3 Codex + Gemini 3.1 Pro + DeepSeek V4 Pro consensus, ≥2-model agreement) — a second pair of eyes from different model families
2. **Fallback:** `/code-review` plugin from `claude-plugins-official` (5 parallel Claude agents — Claude-only, no cross-family perspective)
3. **All unavailable:** stops and asks the user

Merges only when local gates + CI + external review all pass.

## When NOT to dispatch

- The user hasn't explicitly authorized full automation through merge
- The plan hasn't been approved yet — plan first, then ship

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install ship@patientvibes-skills
```

For the fallback path to work, also install:
```
/plugin install pr-review-tools@patientvibes-skills
```
