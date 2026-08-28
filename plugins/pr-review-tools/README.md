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

Dispatched by another agent (typically [`ship`](../ship/)) when it needs a deterministic PR review without an interactive session. Runs `agent-tool-pr-reviewer review --model openrouter:moonshotai/kimi-k3 --out .pr-review-out` (one dependable Claude-free model — Kimi K3), applies the hedging-word guard / date-FP guard / scope filter, and returns a structured findings summary the parent agent triages. The earlier 3-model consensus basket was removed in CLI 0.6.0 (it kept silently degrading); add `--verifier <a-different-model>` for a cross-family second opinion.

This is the "agent we build" — replaces `opencode run` as `ship`'s fallback reviewer. A single pinned Claude-free model + deterministic filtering makes it stable across runs and independent of the model being reviewed.

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

The agent additionally requires `OPENROUTER_API_KEY` for the default Kimi K3 model (in env, or at `~/.config/agent-tool-pr-reviewer/env` mode 600 — note the CLI does not auto-source that file; the agent sources it explicitly).

## See also

- CLI: [`D:\agent-tool-pr-reviewer\`](../../../agent-tool-pr-reviewer/)
- Spec: `D:\ai-agents\docs\superpowers\specs\2026-05-07-agent-tool-pr-reviewer-design.md`
- Catalog: `D:\ai-agents\README.md`
- Consumer of the agent: [`ship`](../ship/) — falls back to `pr-review` when Codex is unavailable
