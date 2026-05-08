# agent-skills

Chris Moore's personal Claude Code plugin marketplace.

This repo is the distribution mechanism for reusable skills (and eventually commands, agents, hooks, MCP servers) that Claude Code can install via its plugin system. It is paired with `D:\ai-agents\`, which is the human-readable catalog of all my agent assets.

## Layout

```
.claude-plugin/marketplace.json   # marketplace metadata + plugin list
plugins/                          # one directory per plugin
  pr-review-tools/                # AI-driven PR review skill (v1)
    .claude-plugin/plugin.json
    skills/pr-review/SKILL.md
    README.md
```

## Install (local)

From any directory in Claude Code:

```
/plugin marketplace add D:/agent-skills
/plugin install pr-review-tools@patientvibes-skills
```

`/plugin marketplace add` registers this repo as a marketplace. After that, any plugin listed in `.claude-plugin/marketplace.json` is installable by name.

The marketplace's internal name is `patientvibes-skills` (set in `marketplace.json`); the repo directory is `agent-skills`. Both names refer to the same thing; use the marketplace name in `/plugin install`.

## Plugins

| Plugin | Status | Description | Depends on |
|---|---|---|---|
| `pr-review-tools` | v1 | AI-driven PR review skill calling the `agent-tool-pr-reviewer` CLI | [`agent-tool-pr-reviewer`](../agent-tool-pr-reviewer/) |

## Adding a new plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` and a skills/commands subtree per Claude Code's plugin contract.
2. Add an entry to `.claude-plugin/marketplace.json` under `plugins`.
3. Run `/plugin marketplace update patientvibes-skills` in any Claude Code session to refresh.

## See also

- [`D:\ai-agents\`](../ai-agents/) — master catalog of all my agent assets (this marketplace, the CLIs, the reference agents).
- [`D:\agent-tool-pr-reviewer\`](../agent-tool-pr-reviewer/) — the CLI the `pr-review` skill depends on.
- [Claude Code plugin marketplace docs](https://docs.claude.com/en/docs/claude-code/plugins) — the plugin contract this repo conforms to.
