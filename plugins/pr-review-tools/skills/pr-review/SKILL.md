---
name: pr-review
description: Run an AI-driven review on the current branch's PR via the agent-tool-pr-reviewer CLI. Use when the user asks to review a PR, audit a branch before merging, or critique their own changes before opening a PR.
---

# pr-review (PLACEHOLDER)

This skill is a structural placeholder.

The agent-tool-pr-reviewer CLI it depends on has not been designed yet —
that's a separate spec/brainstorm. Once that CLI exists, this skill will:

1. Run the reviewer against the current branch.
2. Read review-output.md and findings.json.
3. Summarize blocking and high-severity findings.
4. Ask before applying any fixes.

Until then, this skill is intentionally inert.
