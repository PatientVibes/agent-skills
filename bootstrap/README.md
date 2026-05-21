# bootstrap/ — `seed-claude-skills.sh`

Idempotent setup script for a Claude Code environment on the PatientVibes standard layout. Run it on a fresh VM, an existing dirty machine, or a CI runner; it converges to the same target state defined by [`plugins.txt`](./plugins.txt).

## What it does

1. Locates the `claude` CLI (defaults to `~/.local/bin/claude`; override with `CLAUDE_BIN`).
2. Registers the expected marketplaces (`anthropics/claude-plugins-official` + `PatientVibes/agent-skills`).
3. Installs each plugin in `plugins.txt`, **runs a smoke test (`claude plugin details`)** after each install, and halts on the first failure.
4. Removes stale Tier-2 raw copies under `~/.claude/skills/` only after the matching Tier-1 plugin passes its smoke test. (Halt-before-rm: if smoke fails, the raw copy stays put so you're recoverable.)
5. Verifies the addyosmani-vendored skills under `~/.claude/skills/` are still present (warn-only — full SHA verification is a re-vendor-time concern).
6. Scaffolds `~/.config/<tool>/env` at **mode 600** for each tool expected by `config-env-loading` (currently `repo-doc-gov` and `agent-tool-llm-proofreader`). Never overwrites existing files; never writes secret values.
7. Warns if no LLM key is reachable (env or `op` CLI).
8. Warns if `opencode` / model-routing config is missing.
9. Removes the 5 known per-repo `skill-creator` duplicates under `~/chorus-repos/*/.claude/skills/` (gated on the user-level skill-creator plugin verifying).

The design and inventory are in the [ai-agents catalog](https://github.com/PatientVibes/ai-agents/tree/master/docs/superpowers/plans):

- [`2026-05-20-skills-standardization-coplan-v2.md`](https://github.com/PatientVibes/ai-agents/blob/master/docs/superpowers/plans/2026-05-20-skills-standardization-coplan-v2.md) — converged plan.
- [`2026-05-20-skills-standardization-inventory.md`](https://github.com/PatientVibes/ai-agents/blob/master/docs/superpowers/plans/2026-05-20-skills-standardization-inventory.md) — definitive before/after table.

## Quick start

```bash
# From a clone of agent-skills:
bash bootstrap/seed-claude-skills.sh                   # apply
bash bootstrap/seed-claude-skills.sh --dry-run         # preview, modify nothing
bash bootstrap/seed-claude-skills.sh --strict          # CI mode (warnings fail)
bash bootstrap/seed-claude-skills.sh --skip-secrets    # skip step 6
```

The script is idempotent — running it twice produces no changes the second time. Safe to re-run after editing `plugins.txt` to add or remove a plugin.

## Per-environment notes

### chorus-dev

`claude` is at `~/.local/bin/claude` (v2.1.140 as of 2026-05-20). Default `CLAUDE_BIN` matches; no override needed.

### Fresh VM / WSL

Install Claude Code first (either via the VS Code extension's native binary or `npm i -g @anthropic-ai/claude-code` — verify the resulting path matches `CLAUDE_BIN`). Then run the script.

### CI runner

Run with `--strict --skip-secrets`. The runner is expected to provide secrets via env vars (no `~/.config/<tool>/env` scaffolding needed) and to fail fast on any warning.

## What the script does NOT do

- Provision MCP server configs (Figma, Gmail, Calendar, etc.). These are per-user permission grants and out of scope.
- Write secret values. The script creates `~/.config/<tool>/env` files at mode 600 but never populates them — the operator fills them via `op`, env-var export, or a mounted secrets file.
- Update `~/.claude/CLAUDE.md`. That's a separate documentation step in the standardization plan.
- Manage per-repo `<repo>/.claude/skills/` content (other than the known `skill-creator` dupes). Repo-specific skills live with the repo.
