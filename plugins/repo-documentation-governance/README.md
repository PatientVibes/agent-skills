# repo-documentation-governance

Repo documentation cleanup and AI-agent instruction consolidation subagent. Plugin in the `patientvibes-skills` marketplace.

## Status: v1

No external CLI dependencies. Works on any repo with an AGENTS.md / CLAUDE.md / GEMINI.md / Copilot instruction file.

## Agents

### `repo-documentation-governance`

Dispatched on phrases like "clean up docs", "update README", "consolidate agent instructions", "fix doc drift", "remove stale artifacts", or "documentation governance". Makes the repository easier for humans and AI agents to understand without changing application behavior — inspect first, change second, prefer one canonical source per topic over many drifting ones.

The output of this agent is a Pull Request, not a merge. The agent does not commit to `main`, self-approve, or self-merge.

Workflow scales to the task: a README refresh runs phases 2/4/9, a full governance pass runs all 9 phases (Survey → Code-first source of truth → Drift audit → README → Agent instructions → Handoff/TODO/ROADMAP → Stale artifacts → Verification → PR-format handoff).

Includes supporting references at `agents/references/` (decisions, phases, templates) that the agent loads on demand at the relevant phase, and a triggering eval at `evals/triggering.json`.

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install repo-documentation-governance@patientvibes-skills
```
