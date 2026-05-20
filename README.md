# agent-skills

Chris Moore's personal Claude Code plugin marketplace.

This repo is the distribution mechanism for reusable skills, subagents (and eventually commands, hooks, MCP servers) that Claude Code can install via its plugin system. It is paired with `D:\ai-agents\`, which is the human-readable catalog of all my agent assets.

## Layout

A plugin can ship a `skills/` subtree, an `agents/` subtree, or both. Skills load inline via the `Skill` tool; subagents dispatch via the `Agent` tool with `subagent_type`.

```
.claude-plugin/marketplace.json   # marketplace metadata + plugin list
plugins/                          # one directory per plugin
  pr-review-tools/                # skill + agent in the same plugin
    .claude-plugin/plugin.json
    skills/pr-review/SKILL.md     # user-invoked review entry point
    agents/pr-review.md           # programmatic dispatch (used by `ship`)
    README.md
  ship/                           # agent-only plugin
    .claude-plugin/plugin.json
    agents/ship.md
    README.md
  repo-documentation-governance/  # agent + supporting references + evals
    .claude-plugin/plugin.json
    agents/repo-documentation-governance.md
    agents/references/            # decisions.md, phases.md, templates.md
    evals/triggering.json
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

### code-review

| Plugin | Ships | Status | Description | Depends on |
|---|---|---|---|---|
| `pr-review-tools` | skill + agent | v1 | `pr-review` skill (user-invoked review) + `pr-review` subagent (programmatic dispatch, used by `ship` as Codex fallback) | [`agent-tool-pr-reviewer`](../agent-tool-pr-reviewer/) + `OPENROUTER_API_KEY` |

### agent-collaboration

| Plugin | Ships | Status | Description | Depends on |
|---|---|---|---|---|
| `code-research` | skill | v1 | One-shot Gemini CLI Q&A for large-context / cross-codebase research questions | `gemini` CLI on `PATH` |
| `co-plan` | skill | v1 | Iterative Claude ↔ Gemini draft-critique-revise planning loop. Gemini-specific by design — 1M context + the harness conventions | `gemini` CLI on `PATH` |

### automation

| Plugin | Ships | Status | Description | Depends on |
|---|---|---|---|---|
| `ship` | agent | v1 | Autonomous branch → PR → external review → merge after plan approval. Codex primary → `pr-review` subagent fallback (no opencode/OpenRouter dependency) | `codex`, `gh`, `pr-review-tools` plugin |
| `repo-documentation-governance` | agent | v1 | Repo doc cleanup + AGENTS/CLAUDE/GEMINI/Copilot consolidation. Nine-phase workflow scaling to the task. Outputs a PR, not a merge | none |

### knowledge-graph

| Plugin | Ships | Status | Description | Depends on |
|---|---|---|---|---|
| `graphify` | skill | v1 | Any folder of files → navigable knowledge graph (HTML + GraphRAG JSON + report) | `graphify` CLI on `PATH` |

### code-quality

| Plugin | Ships | Status | Description | Depends on |
|---|---|---|---|---|
| `fix-bare-excepts` | skill | v1 | Python — narrow bare `except:` and broad `except Exception` catches to specific exception types; add logging where exceptions were silently swallowed | Python codebase being inspected |

### reference-agents

| Plugin | Ships | Status | Description | Depends on |
|---|---|---|---|---|
| `csd-form-analysis` | skill | v1 | SS&C AWD CSD binary forms analysis with a LangGraph ReAct agent | [`agent-harness-chorus-csd-analyzer`](../agent-harness-chorus-csd-analyzer/) |
| `vlm-card-extraction-prompts` | skill | v1 | Six production-tuned VLM prompts for scanned-document extraction | [`agent-harness-card-extractor`](../agent-harness-card-extractor/) |

### patterns

| Plugin | Ships | Status | Description | Depends on |
|---|---|---|---|---|
| `verification-retry-loop` | skill | v1 | Pattern: extract → verify → retry-once-with-feedback | none |
| `human-review-loop` | skill | v1 | Pattern: confidence-gate output, route low-confidence to a queue, feed corrections back as wiki rules | [`agent-tool-review-queue`](../agent-tool-review-queue/) + [`agent-tool-knowledge-wiki`](../agent-tool-knowledge-wiki/) |
| `config-env-loading` | skill | v1 | Convention for `~/.config/<tool-name>/env` (mode 600) as API-key fallback in agent-tool-* / agent-harness-* CLIs | none |

## Adding a new plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` and a skills/commands subtree per Claude Code's plugin contract.
2. Add an entry to `.claude-plugin/marketplace.json` under `plugins`.
3. Run `/plugin marketplace update patientvibes-skills` in any Claude Code session to refresh.

## See also

- [`D:\ai-agents\`](../ai-agents/) — master catalog of all my agent assets (this marketplace, the CLIs, the reference agents).
- [`D:\agent-tool-pr-reviewer\`](../agent-tool-pr-reviewer/) — the CLI the `pr-review` skill depends on.
- [Claude Code plugin marketplace docs](https://docs.claude.com/en/docs/claude-code/plugins) — the plugin contract this repo conforms to.
