---
name: pr-review
description: Run an AI-driven review on the current branch's diff (vs its base ref) via the agent-tool-pr-reviewer CLI. Use when the user asks to review a PR, audit a branch before merging, or critique their own changes before opening a PR.
---

# pr-review

Run an AI-driven review on the current branch's diff against its base ref via the
`agent-tool-pr-reviewer` CLI, then surface blocker and high-severity findings.

## Steps

1. **Verify the CLI is installed.** Run `agent-tool-pr-reviewer --version`.
   If the binary is missing, tell the user:
   `The agent-tool-pr-reviewer CLI is not on PATH. Install with: uv tool install --editable D:/agent-tool-pr-reviewer`.
   Then stop.

2. **Run the reviewer.** From the repo root the user invoked the skill in:

   ```bash
   agent-tool-pr-reviewer review
   ```

   Capture the printed run directory path and the exit code.

   - Exit `0`: review completed, no blockers.
   - Exit `1`: review completed, one or more blocker findings present.
   - Exit `2`: configuration error (no base ref resolvable, budget exceeded, malformed `.ai-review/` rule, etc.). Surface the stderr message and stop.

3. **Read the artifacts.** The run directory contains:
   - `findings.json` — the typed Report (Pydantic-validated upstream).
   - `review-output.md` — the human-readable rendering.

   Alternatively, read `<repo>/.ai-review/runs/latest.txt` to get the basename of the freshest run dir.

   **Schema-version check first.** Read `findings.json` and inspect `metadata.schema_version`.
   - If `"2"` (or higher), proceed normally.
   - If `"1"`, tell the user: "This run was produced by an older CLI version (v0.1.0) and lacks evidence quotes. Re-run `agent-tool-pr-reviewer review` to get evidence-enriched findings." Then stop — do not summarize the old run.
   - If absent or any other value, tell the user the file looks malformed and stop.

4. **Summarize for the user.** Group by severity. For each finding (lead with blocker and high), surface:
   - `file:line_start-line_end`
   - one-line `title`
   - `category` (`bug` or `project_rule (<rule_id>)`)
   - the `evidence` quote — show the literal lines from `findings.json`'s `evidence` field verbatim, in a code block, so the user can spot factual hallucinations at a glance
   - one-paragraph `description`

   Mention medium / low counts but don't enumerate them unless asked.

   **For `bug`-category findings specifically:** the evidence quote is the user's primary triage signal. Read it before describing the finding, and if the description references external tooling (CLI flags, library APIs, container behavior, etc.) or speculates about downstream effects, flag that to the user explicitly so they verify the claim against the actual tool docs before acting.

   Exit code from the CLI run: `0` (no blockers), `1` (blockers present), `2` (config error).

5. **Offer next steps.** Ask the user before applying any suggested fixes — the CLI never modifies code on its own. If the user agrees, edit the file at the cited line range using the finding's `suggested_fix` as guidance, then run the project's test command before reporting completion.

## Notes

- Project rules live at `<repo>/.ai-review/<rule-id>.md` (filename is the `rule_id`). Each file has a `description:` frontmatter and free-form prose body.
- v1 reviews the LOCAL branch's diff against its base ref (auto-detected: `origin/HEAD` → `main` → `master`). GitHub PR mode is deferred.
- Only two finding categories: `bug` (logic/correctness defects) and `project_rule` (`.ai-review/` violations).
- Security findings are intentionally out of scope here — use `/security-review` for that.
- The reviewer requires a model API key. By default it uses `anthropic:claude-sonnet-4-6` and reads `ANTHROPIC_API_KEY` from the environment. Other providers can be selected with `--model` (any Pydantic AI model string).
- **Calibration note (added 2026-05-08):** in early trial data, `bug`-category findings had a higher false-positive rate than `project_rule` findings — particularly when they made claims about external tools (CLI flag validity, library defaults) or inferred patterns from asymmetry. Surface the `evidence` quote verbatim and prefer the user verify before acting on bug findings.
