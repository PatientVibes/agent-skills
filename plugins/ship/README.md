# ship

Autonomous branch → PR → external review → merge subagent. Plugin in the `patientvibes-skills` marketplace.

## Status: v1

Depends on `codex` (primary external reviewer) and the `pr-review` subagent in [`pr-review-tools`](../pr-review-tools/) (fallback). The `pr-review` subagent wraps the [`agent-tool-pr-reviewer`](../../../agent-tool-pr-reviewer/) CLI in multi-model consensus mode (Gemini + Kimi + DeepSeek). `gh` must be authenticated.

**No opencode / OpenRouter dependency in the fallback path** — the OpenRouter models have smaller context windows and intermittent reliability issues that make them unfit for this flow.

## Agents

### `ship`

Dispatched when the user has approved a plan and said "ship it", "go ahead", "implement and merge", or types `/ship`. Drives an approved change from a clean working tree to a merged PR with no human checkpoints in between, except for the explicit pause points documented in the agent's "Guardrails" section.

External-review ladder:

1. **Primary:** `codex review --base <main>` — second-pair-of-eyes from a different model family
2. **Fallback 1:** dispatch the `pr-review` subagent — runs `agent-tool-pr-reviewer --models default` (Gemini + Kimi + DeepSeek consensus, ≥2-model agreement)
3. **Fallback 2:** `/code-review` plugin from `claude-plugins-official` (5 parallel Claude agents — Claude-only, no cross-family perspective)
4. **All unavailable:** stops and asks the user

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
