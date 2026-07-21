---
name: pr-review
description: Code-reviews the current branch's diff via the `agent-tool-pr-reviewer` CLI (one pinned strong Claude-free reviewer — GPT-5.3 Codex — plus a pinned Gemini verifier pass that drops unsupported findings). Use as the external-reviewer leg when codex is unavailable, or any time another agent needs a deterministic cross-family PR review without an interactive session. Returns a structured findings summary (blocker / high / medium / low counts + verbatim evidence for blockers/highs) for the parent agent to triage.
tools: Bash, Read
---

# pr-review — deterministic cross-family PR review subagent

Run an AI-driven PR review on the current branch's diff against its base ref via the `agent-tool-pr-reviewer` CLI, then return a structured summary the parent agent can triage.

This subagent is the "agent we build" half of the cross-family reviewer pattern — it provides a deterministic, non-interactive alternative to running `codex review` or shelling out to `opencode run`. It pins one strong Claude-free code-review model (GPT-5.3 Codex — same family as the primary codex reviewer, so finding style stays consistent) plus a pinned Gemini verifier pass, and applies its own filtering (date-FP guard, hedging-word guard, scope filter) so the output is stable across runs and reviews stay independent of the model doing the work.

> History: this agent originally ran `--models default` (3-model consensus). CLI v0.5.3 silently re-pointed that basket to include Claude Opus 4.7, so the basket was pinned Claude-free (2026-07-02: GPT-5.3 Codex + Gemini 3.1 Pro + Kimi K2.6), then simplified to one strong reviewer + verifier (2026-07-21). Never rely on the CLI's `default` — pin models explicitly.

## Preconditions

- `agent-tool-pr-reviewer --version` succeeds. If missing, return failure: `agent-tool-pr-reviewer not on PATH; install with: uv tool install --editable D:/agent-tool-pr-reviewer`. Do NOT proceed.
- `OPENROUTER_API_KEY` is set in env, OR `~/.config/agent-tool-pr-reviewer/env` exists (mode 600). If neither, return failure and stop. **The CLI does NOT auto-source the env file** — source it explicitly as shown below.
- Current working directory is a git repo with a resolvable base ref (`origin/HEAD` → `main` → `master`).

## Run

From the repo root:

```bash
[ -n "$OPENROUTER_API_KEY" ] || { set -a; . ~/.config/agent-tool-pr-reviewer/env; set +a; }
agent-tool-pr-reviewer review \
  --model openrouter:openai/gpt-5.3-codex \
  --verifier openrouter:google/gemini-3.1-pro-preview \
  --out .pr-review-out
```

- The env-file sourcing line is required: the CLI does **not** auto-source `~/.config/agent-tool-pr-reviewer/env` (observed exit-2 `ModelResolutionError` on 2026-07-21 when the key wasn't already exported).
- `--model openrouter:openai/gpt-5.3-codex` pins the single strong reviewer, **no Claude in the loop** — reviews stay independent of the model doing the work. Do NOT use `--models default`: since CLI v0.5.3 (June 2026) the curated default includes Claude Opus 4.7, which is not Claude-free and costs more.
- `--verifier openrouter:google/gemini-3.1-pro-preview` replaces the noise filter that ≥2-model consensus used to provide: it only ever *drops* findings whose evidence isn't verbatim in the diff or that it judges speculative — it cannot add findings. Do NOT use `--verifier default`: it expands to a Claude model, voiding the Claude-free property.
- `--out .pr-review-out` writes artifacts to a stable path the parent agent can read.
- **Copy the `--model` and `--verifier` lines verbatim.** Do not substitute `--models default`, and do not omit `--model` (omitting it selects the curated Claude-containing default — observed 2026-07-15 on two consecutive dispatches, so "cross-family review" meant Claude reviewing its own diff). The step below exists to catch exactly that.

### Verify the models before reporting — MANDATORY

The pinned Claude-free reviewer is the whole point of this subagent, and a
dropped `--model` flag fails **silently** (the run succeeds and returns
findings; only the model differs). So do not trust that you passed it — check
the run's own record:

```bash
python3 -c "
import json,sys,glob
f=sorted(glob.glob('.pr-review-out/**/findings.json',recursive=True))[-1]
m=json.load(open(f))['metadata']
used=(m.get('models') or [m.get('model')]) + [m.get('verifier')]
print('reviewer+verifier:', used)
bad=[x for x in used if x and ('claude' in x.lower() or 'anthropic' in x.lower())]
sys.exit(1 if bad else 0)
"
```

If it exits non-zero, a Claude model is in the loop: the cross-family property
is void. **Re-run with the pinned `--model` and `--verifier` lines before
reporting anything.** If it still resolves with Claude present, return failure
and say so plainly — report the models you got. Never present a
Claude-containing run as a cross-family review.

### Known limitation — state it in every report

The CLI is **diff-only**: it ingests the diff text (typically 8–20K input
tokens) with **no repo access**. It cannot verify that a `file:line` cite is
real, that a claim matches the surrounding code, or that a related call site was
missed — the questions that matter most on large or translation-heavy
codebases. Treat a 0-findings result as **weak evidence, not a clean bill of
health**, and say so in the summary. When the change is load-bearing, recommend
the parent also run a reviewer with repo access (`opencode run --agent
gemini-flash|cheap` is OpenRouter-backed and non-Claude; the reasoning-heavy
opencode agents — `frontier`, `kimi`, `minimax` — have been observed to hang, so
prefer the flash lanes).

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

Emit a single response to the parent agent containing the structured summary
below. **Quote the `evidence` field inside a five-backtick fence (`\`\`\`\`\`…\`\`\`\`\``)
so that any triple-backtick content inside the evidence (common when reviewing
markdown or code-block-heavy files) does not prematurely close the fence.**

`````
Exit: <code>
Basket: <metadata.models verbatim>   ← MUST be Claude-free; see "Verify the basket"
Evidence strength: diff-only (no repo access) — 0 findings is weak evidence
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
  evidence:
    `````
    <verbatim from findings.json evidence field — DO NOT paraphrase. Use a
    five-backtick fence as shown so triple-backtick content inside the
    evidence does not break the outer fence.>
    `````
  description: <one paragraph from findings.json>
  suggested_fix: <if present>
`````

Then end with: `Artifacts: <path>/findings.json, <path>/review-output.md`.

## When called by another agent (e.g. ship)

The parent runs the step-7 triage filter (drop pre-existing issues, lint-catchable issues, pedantic nitpicks, etc.) and decides what to do with each finding. This subagent does NOT decide what to fix or merge — it just produces the structured review.

If exit code is `2` or the CLI is unavailable, return the failure cleanly so the parent can fall through to its next reviewer (e.g. `/code-review` plugin).

## When called directly by a user

Surface the findings the same way, then ask before applying any suggested fixes — the CLI never modifies code on its own. The skill version of this (`pr-review` in the same plugin) is the more user-friendly entry point; this agent is optimized for programmatic dispatch.

## Calibration note

In early trial data, `bug`-category findings had a higher false-positive rate than `project_rule` findings — particularly when claims involved external tooling (CLI flag validity, library defaults) or inferred patterns from asymmetry. Always surface the `evidence` quote verbatim so the parent (or user) can spot factual hallucinations at a glance. The v0.5.3 date-FP guard catches one specific class (Gemini's training-cutoff false flags on 2026 dates) but the broader external-tool-claim class is still on the parent to triage.
