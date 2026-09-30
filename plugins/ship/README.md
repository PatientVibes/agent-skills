# ship

Autonomous branch → PR → external review → merge subagent. Plugin in the `patientvibes-skills` marketplace.

## Status: v3

The external reviewer is **GLM 5.3** (`z-ai/glm-5.3` on OpenRouter), run through a locked-down, read-only opencode agent named `review` so it can open the code around the diff. `gh` must be authenticated.

> **v3 change (2026-09-30):** opencode is back, but only through the read-only `review` agent. In a head-to-head on a large TypeScript PR stack, GLM 5.3 with repo access found two real high-severity bugs that a diff-only review missed; GPT-6 Astra ended with no report. The "opencode hangs" seen earlier was `opencode run` waiting on an open stdin, and `</dev/null` fixes it.
>
> **v2 change:** the `codex` CLI is no longer used (account access removed).

## Agents

### `ship`

Dispatched when the user has approved a plan and said "ship it", "go ahead", "implement and merge", or types `/ship`. Drives an approved change from a clean working tree to a merged PR with no human checkpoints in between, except for the explicit pause points documented in the agent's "Guardrails" section.

External-review ladder:

1. **Primary:** `opencode run --agent review` (GLM 5.3, repo access, read-only). Ship then verifies every finding against the code itself.
2. **Fallback:** the `pr-review` subagent with `--model openrouter:z-ai/glm-5.3` (diff-only, deterministic filtering)
3. **Fallback:** `/code-review` plugin from `claude-plugins-official` (5 parallel Claude agents — Claude-only, no cross-family perspective)
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

### The opencode `review` agent (required for the primary reviewer)

Add this to `~/.config/opencode/opencode.json` under `"agent"`. Turning off `task` matters: without it, the agent can hand a write to a general subagent and get around the lock (seen in testing).

```json
"review": {
  "description": "Read-only code reviewer on GLM 5.3. Used by /ship.",
  "model": "openrouter/z-ai/glm-5.3",
  "permission": { "edit": "deny", "bash": "deny", "webfetch": "deny", "task": "deny" },
  "tools": { "write": false, "edit": false, "patch": false, "bash": false, "task": false, "webfetch": false }
}
```

Smoke test, from a repo: `opencode run --agent review "Read package.json, reply with its name, then try to create zz-probe.txt; report DENIED if you cannot." </dev/null`. It should reply with the name and DENIED, and leave no file behind.

For the fallback path to work, also install:
```
/plugin install pr-review-tools@patientvibes-skills
```
