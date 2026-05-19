---
name: pr-review
description: Code-reviews the current branch's diff via the `agent-tool-pr-reviewer` CLI (multi-model consensus mode by default — Gemini + Kimi + DeepSeek, keeps findings flagged by ≥2 models). Use as the external-reviewer leg when codex is unavailable, or any time another agent needs a deterministic cross-family PR review without an interactive session. Returns a structured findings summary (blocker / high / medium / low counts + verbatim evidence for blockers/highs) for the parent agent to triage.
tools: Bash, Read
---

# pr-review — deterministic cross-family PR review subagent

Run an AI-driven PR review on the current branch's diff against its base ref via the `agent-tool-pr-reviewer` CLI, then return a structured summary the parent agent can triage.

This subagent is the "agent we build" half of the cross-family reviewer pattern — it provides a deterministic, non-interactive alternative to running `codex review` or shelling out to `opencode run`. It uses our own pinned model basket (Gemini 2.5 Pro + Kimi K2.6 + DeepSeek V3.1) and our own filtering (date-FP guard, hedging-word guard, scope filter, verifier) so the output is stable across runs.

## Preconditions

- `agent-tool-pr-reviewer --version` succeeds. If missing, return failure: `agent-tool-pr-reviewer not on PATH; install with: uv tool install --editable D:/agent-tool-pr-reviewer`. Do NOT proceed.
- `OPENROUTER_API_KEY` is set in env, OR `~/.config/agent-tool-pr-reviewer/env` exists (mode 600). If neither, return failure and stop.
- Current working directory is a git repo with a resolvable base ref (`origin/HEAD` → `main` → `master`).

## Run

From the repo root:

```bash
agent-tool-pr-reviewer review --models default --out .pr-review-out
```

- `--models default` runs the multi-model consensus basket (Gemini + Kimi + DeepSeek) and keeps findings flagged by ≥2 models. This is the recommended mode for autonomous review — cross-family by construction, no Claude in the loop.
- `--out .pr-review-out` writes artifacts to a stable path the parent agent can read.

Capture the exit code:

- `0` — review completed, no blockers.
- `1` — review completed, one or more blocker findings present.
- `2` — configuration error (no base ref resolvable, budget exceeded, malformed `.ai-review/` rule, etc.). Surface stderr and return failure.

## Read artifacts

The run directory contains:
- `findings.json` — typed Pydantic Report (`metadata.schema_version: "2"` or higher).
- `review-output.md` — human-readable rendering.

If `metadata.schema_version` is `"1"` or missing, return failure: the run was produced by an older CLI; re-run with a current install.

## Return structured summary

Emit a single response to the parent agent containing:

```
Exit: <code>
Blockers: <count>   ← from findings.json severity == "blocker"
High:     <count>
Medium:   <count>
Low:      <count>
Date-FP guard dropped: <count from metadata.date_guard_dropped, 0 if absent>
Run dir: <path>

[For each blocker and high finding, in order:]
  file:line_start-line_end
  title: <one line>
  category: bug | project_rule(<rule_id>)
  severity: <severity>
  evidence: ```
    <verbatim from findings.json evidence field — DO NOT paraphrase>
  ```
  description: <one paragraph from findings.json>
  suggested_fix: <if present>
```

Then end with: `Artifacts: <path>/findings.json, <path>/review-output.md`.

## When called by another agent (e.g. ship)

The parent runs the step-7 triage filter (drop pre-existing issues, lint-catchable issues, pedantic nitpicks, etc.) and decides what to do with each finding. This subagent does NOT decide what to fix or merge — it just produces the structured review.

If exit code is `2` or the CLI is unavailable, return the failure cleanly so the parent can fall through to its next reviewer (e.g. `/code-review` plugin).

## When called directly by a user

Surface the findings the same way, then ask before applying any suggested fixes — the CLI never modifies code on its own. The skill version of this (`pr-review` in the same plugin) is the more user-friendly entry point; this agent is optimized for programmatic dispatch.

## Calibration note

In early trial data, `bug`-category findings had a higher false-positive rate than `project_rule` findings — particularly when claims involved external tooling (CLI flag validity, library defaults) or inferred patterns from asymmetry. Always surface the `evidence` quote verbatim so the parent (or user) can spot factual hallucinations at a glance. The v0.5.3 date-FP guard catches one specific class (Gemini's training-cutoff false flags on 2026 dates) but the broader external-tool-claim class is still on the parent to triage.
