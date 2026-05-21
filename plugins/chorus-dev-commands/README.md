# chorus-dev-commands

Three user-global slash commands that are tightly coupled to the **chorus-dev VM environment**. Not a portable plugin — it expects:

- Docker compose at `~/chorus-repos/chorus-platform` (where the 4 chorus DBs run)
- `opencode` at `~/.npm-global/bin/opencode` configured at `~/.config/opencode/opencode.json`
- `op` (1Password) CLI authenticated against the user's service account

## Commands

| Command | Purpose |
|---|---|
| `/check [--quick \| --full \| --e2e] [--repo <name>]` | Run the canonical gate pipeline for the current chorus repo. Auto-detects the repo from `cwd`. |
| `/db [postgres\|oracle\|awd\|chorus] <SQL or backslash-command>` | Read-only introspection of the chorus databases (mutations require confirmation). The DBs run inside chorus-platform's docker-compose — psql/sqlplus aren't installed locally so this shells into the containers via `docker exec`. |
| `/oc [--agent <name>] <task>` | Delegate a coding task to opencode (OpenRouter-backed, cheaper). opencode does not see Claude's conversation; the prompt must be self-contained. |

## Install

```bash
claude plugin install chorus-dev-commands@patientvibes-skills
```

This plugin is also part of the standard chorus-dev bootstrap — run [`bootstrap/seed-claude-skills.sh`](../../bootstrap/seed-claude-skills.sh) and it installs automatically.

## Inventory quirk

`claude plugin details chorus-dev-commands` reports `Skills (3)` rather than `Commands (3)` — Claude Code's plugin inventory currently conflates the two categories. The "Per-component" table shows the actual command names (`check`, `db`, `oc`). This is a Claude Code display detail, not a plugin defect.

## Provenance

Authored on the chorus-dev VM at `~/.claude/commands/{check,db,oc}.md`, then lifted into this plugin on 2026-05-20 as part of the [skills-standardization rollout](https://github.com/PatientVibes/ai-agents/blob/master/docs/superpowers/plans/2026-05-20-chorus-dev-commands-plugin-coplan-v3.md). After install + bootstrap, the raw files were moved to `~/.claude/commands/*.pre-plugin.bak.<date>` for rollback safety; once verified, those backups can be deleted.
