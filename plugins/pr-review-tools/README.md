# pr-review-tools

AI-driven pull request review skill for Claude Code. Plugin in the `patientvibes-skills` marketplace.

## Status: v1

The companion CLI ([`agent-tool-pr-reviewer`](../../../agent-tool-pr-reviewer/)) is built and on PATH after `uv tool install --editable D:/agent-tool-pr-reviewer`. The skill body is wired up.

## Skills

### `pr-review`

Triggered when the user asks Claude Code to review the current branch's diff. Steps:

1. Verifies `agent-tool-pr-reviewer --version` succeeds; surfaces an install hint if the binary is missing.
2. Runs `agent-tool-pr-reviewer review` from the repo root.
3. Reads the freshest run's artifacts via `<repo>/.ai-review/runs/latest.txt` → `findings.json` + `review-output.md`.
4. Surfaces blocker and high findings to the user (file:line, title, category, rule_id).
5. Asks before applying any suggested fixes — the CLI never modifies code on its own.

Project-specific rules live in `<repo>/.ai-review/<rule-id>.md`. See the [CLI README](../../../agent-tool-pr-reviewer/README.md#rule-file-format) for the file format.

## Install

This plugin installs as part of the `patientvibes-skills` marketplace:

```
/plugin marketplace add D:/agent-skills
/plugin install pr-review-tools@patientvibes-skills
```

The skill itself depends on the CLI being installed separately:

```
uv tool install --editable D:/agent-tool-pr-reviewer
```

## See also

- Skill body: [`skills/pr-review/SKILL.md`](skills/pr-review/SKILL.md)
- CLI: [`D:\agent-tool-pr-reviewer\`](../../../agent-tool-pr-reviewer/)
- Spec: `D:\ai-agents\docs\superpowers\specs\2026-05-07-agent-tool-pr-reviewer-design.md`
- Catalog: `D:\ai-agents\README.md`
