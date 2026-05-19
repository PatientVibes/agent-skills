# code-research

Use Gemini CLI as a second-opinion / large-context research assistant. Plugin in the `patientvibes-skills` marketplace.

## Status: v1

The companion CLI is the Google `gemini` binary. Skill assumes `gemini` is on `PATH` and authenticated.

## Skills

### `code-research`

Triggered by phrases like "ask gemini", "have gemini look at", "second opinion from gemini", "research with gemini", or `/code-research`. Spawns `gemini -p` as a non-interactive child process to get an independent read with Gemini's ~1M token context window — useful for whole-codebase reasoning that doesn't fit in Claude's working context.

Different shape from `co-plan`: this skill is one-shot Q&A. `co-plan` is an iterative draft-critique-revise loop.

## When NOT to use

- Targeted greps → use `Bash`
- Single-file lookups → use `Read`
- Questions Claude already has the relevant context for — the round-trip isn't free

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install code-research@patientvibes-skills
```
