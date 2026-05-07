# agent-skills

Chris Moore's personal Claude Code plugin marketplace.

This repo is the distribution mechanism for reusable skills (and eventually
commands, agents, hooks, MCP servers) that Claude Code can install via its
plugin system. It is paired with `D:\ai-agents\`, which is the human-readable
catalog/index of all my agent assets.

## Layout

```
.claude-plugin/marketplace.json   # marketplace metadata + plugin list
plugins/                          # one directory per plugin
  pr-review-tools/                # AI-driven PR review skills (placeholder)
```

## Install (local)

From any directory in Claude Code:

```
/plugin marketplace add D:/agent-skills
/plugin install pr-review-tools@agent-skills
```

`/plugin marketplace add` registers this repo as a marketplace. After that,
any plugin listed in `.claude-plugin/marketplace.json` is installable by name.

## Plugin status

| Plugin | Status | Description |
|---|---|---|
| pr-review-tools | placeholder | AI-driven PR review skills. The agent-tool-pr-reviewer CLI it depends on has not been built yet. |

## See also

- `D:\ai-agents\` — master catalog of all agent assets (this marketplace, planned tool repos, and reference agents).
