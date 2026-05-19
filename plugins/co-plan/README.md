# co-plan

Iterative Claude ↔ Gemini collaborative planning loop. Plugin in the `patientvibes-skills` marketplace.

## Status: v1

The companion CLI is the Google `gemini` binary. Skill assumes `gemini` is on `PATH` and authenticated.

## Skills

### `co-plan`

Triggered by phrases like "co-plan with gemini", "plan this with gemini", "let's get gemini's take on the plan", or `/co-plan`. Two-model planning loop: Claude drafts a plan, Gemini critiques it, Claude revises, repeat until convergence. Output is a single agreed plan ready for user approval.

Use for architectural decisions, multi-step migrations, or any plan where a second model's review materially reduces the chance of a missed dependency, wrong-approach choice, or unconsidered failure mode.

## When NOT to use

- Trivial fixes — the round-trip cost isn't worth it
- One-shot research questions → use [`code-research`](../code-research/) instead

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install co-plan@patientvibes-skills
```
