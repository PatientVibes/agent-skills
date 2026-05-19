# pr-review-tools

AI-driven pull request review for Claude Code. Plugin in the `patientvibes-skills` marketplace.

## Status: v1

The companion CLI ([`agent-tool-pr-reviewer`](../../../agent-tool-pr-reviewer/)) is built and on PATH after `uv tool install --editable D:/agent-tool-pr-reviewer`. Both the skill and the agent are wired up.

This plugin ships **two entry points** that share the same underlying CLI:

| Entry | When | Loaded as |
|---|---|---|
| `pr-review` skill | User asks Claude to review the current branch | `Skill` tool — content loaded inline |
| `pr-review` agent | Another agent (e.g. `ship`) needs a programmatic, deterministic PR review as a fallback when Codex is unavailable | `Agent` tool — dispatched as an isolated subagent |

## Skills

### `pr-review`

Triggered when the user asks Claude Code to review the current branch's diff. Steps:

1. Verifies `agent-tool-pr-reviewer --version` succeeds; surfaces an install hint if the binary is missing.
2. Runs `agent-tool-pr-reviewer review` from the repo root.
3. Reads the freshest run's artifacts via `<repo>/.ai-review/runs/latest.txt` → `findings.json` + `review-output.md`.
4. Surfaces blocker and high findings to the user (file:line, title, category, rule_id, evidence quote).
5. Asks before applying any suggested fixes — the CLI never modifies code on its own.

Body: [`skills/pr-review/SKILL.md`](skills/pr-review/SKILL.md).

## Agents

### `pr-review`

Dispatched by another agent (typically [`ship`](../ship/)) when it needs a deterministic, cross-family PR review without an interactive session. Runs `agent-tool-pr-reviewer review --models default` (Gemini 2.5 Pro + Kimi K2.6 + DeepSeek V3.1, keeps findings flagged by ≥2 models), applies the hedging-word guard / date-FP guard / scope filter / verifier, and returns a structured findings summary the parent agent triages.

This is the "agent we build" — replaces `opencode run` as `ship`'s fallback reviewer. The pinned model basket and deterministic filtering make it more reliable than OpenRouter-routed alternatives that can drift on context-window or rate-limit issues.

Body: [`agents/pr-review.md`](agents/pr-review.md).

Project-specific rules live in `<repo>/.ai-review/<rule-id>.md`. See the [CLI README](../../../agent-tool-pr-reviewer/README.md#rule-file-format) for the file format.

## Install

This plugin installs as part of the `patientvibes-skills` marketplace:

```
/plugin marketplace add D:/agent-skills
/plugin install pr-review-tools@patientvibes-skills
```

The skill and agent both depend on the CLI being installed separately:

```
uv tool install --editable D:/agent-tool-pr-reviewer
```

The agent additionally requires `OPENROUTER_API_KEY` (in env, or at `~/.config/agent-tool-pr-reviewer/env` mode 600) for the consensus model basket.

## See also

- CLI: [`D:\agent-tool-pr-reviewer\`](../../../agent-tool-pr-reviewer/)
- Spec: `D:\ai-agents\docs\superpowers\specs\2026-05-07-agent-tool-pr-reviewer-design.md`
- Catalog: `D:\ai-agents\README.md`
- Consumer of the agent: [`ship`](../ship/) — falls back to `pr-review` when Codex is unavailable
