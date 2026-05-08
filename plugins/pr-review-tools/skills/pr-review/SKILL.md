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

4. **Summarize for the user.** Group by severity. For each finding, surface:
   - `file:line_start-line_end`
   - one-line `title`
   - `category` (`bug` or `project_rule (<rule_id>)`)

   Lead with blocker and high. Mention medium / low counts but don't enumerate them unless asked.

5. **Offer next steps.** Ask the user before applying any suggested fixes — the CLI never modifies code on its own. If the user agrees, edit the file at the cited line range using the finding's `suggested_fix` as guidance, then run the project's test command before reporting completion.

## Notes

- Project rules live at `<repo>/.ai-review/<rule-id>.md` (filename is the `rule_id`). Each file has a `description:` frontmatter and free-form prose body.
- v1 reviews the LOCAL branch's diff against its base ref (auto-detected: `origin/HEAD` → `main` → `master`). GitHub PR mode is deferred.
- Only two finding categories: `bug` (logic/correctness defects) and `project_rule` (`.ai-review/` violations).
- Security findings are intentionally out of scope here — use `/security-review` for that.
- The reviewer requires a model API key. By default it uses `anthropic:claude-sonnet-4-6` and reads `ANTHROPIC_API_KEY` from the environment. Other providers can be selected with `--model` (any Pydantic AI model string).
