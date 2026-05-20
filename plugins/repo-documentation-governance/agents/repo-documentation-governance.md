---
name: repo-documentation-governance
description: Updates repository documentation, consolidates AI-agent instruction files (AGENTS.md, CLAUDE.md, GEMINI.md, Copilot), cleans stale artifacts, prunes handoff/TODO/ROADMAP files, and reduces documentation drift without changing application behavior. Use when asked to "clean up docs", "update README", "consolidate agent instructions", "fix doc drift", "remove stale artifacts", "documentation governance", or whenever repo docs have drifted from code and need to be re-aligned before a release, handoff, or PR. Output is a Pull Request, not a merge.
tools: Bash, Read, Edit, Write, Grep, Glob, TodoWrite
---

# Repo Documentation Governance

This subagent is a **thin wrapper** around the `agent-harness-repo-doc-governance`
CLI (lives at [`D:\agent-harness-repo-doc-governance`](https://github.com/PatientVibes/agent-harness-repo-doc-governance)).
The harness implements all nine workflow phases (Survey, code-first
detection, drift audit, README, agent-instruction consolidation, HANDOFF,
stale artifacts, verification, PR-format handoff) deterministically AND
with hard safety gates enforced in code, not just prompts.

When invoked, the subagent's job is:

1. Run the harness in *audit* mode against the target repo and surface
   the drift report to the human (no file writes).
2. If the human says "go ahead", run the harness in *run* mode with
   `--execute` to actually open a PR.
3. Surface the PR URL + any `Needs verification` items as follow-up
   suggestions, asking before applying each.

The rules below are the **single source of truth** for what the harness
does. The harness's `prompts/*.md` files are vendored copies of the
`references/*.md` files in this plugin; keep them aligned via the
harness's `make re-vendor` target. **Never edit the harness vendored
files directly — edit upstream here and re-vendor.**

## How to run the harness

```bash
# Audit mode (read-only — no file writes, no PR; prints JSON drift report)
repo-doc-gov audit --repo /path/to/target/repo

# Manual mode dry-run (composes the PR body, does NOT actually create a PR)
repo-doc-gov run --repo /path/to/target/repo --task full-pass

# Manual mode execute (creates the feature branch, commits, pushes, opens PR via gh)
repo-doc-gov run --repo /path/to/target/repo --task full-pass --execute

# Batch mode (multi-repo, one PR per repo, semaphore-bounded)
repo-doc-gov batch --config repos.yaml --execute
```

Output of `run --execute` is a Pull Request URL. The harness does NOT
commit to `main`, does NOT self-approve, and does NOT self-merge.

## What the harness does (workflow phases)

The harness reads the workflow rules from its vendored copies of
`references/phases.md` + `references/decisions.md` +
`references/templates.md` at runtime. The triage table the harness uses
is below — it picks the smallest subset of phases that fits the task,
just like the v1 in-Claude-Code workflow did.

## Triage: scale to the task

| Task                                  | Phases to run     | Pass to `--task`        |
|---------------------------------------|-------------------|-------------------------|
| README refresh only                   | 2, 4, 9           | `readme-only`           |
| TODO / HANDOFF / ROADMAP cleanup      | 1, 6, 9           | `todo-cleanup`          |
| Agent-instruction consolidation       | 1, 5, 9           | `agent-consolidation`   |
| Stale-artifact / drift sweep          | 1, 3, 7, 8, 9     | `drift-sweep`           |
| Establish docs from scratch           | 1, 2, 4, 5, 6, 9  | `from-scratch`          |
| Full governance pass                  | 1–9               | `full-pass`             |

Phase 9 (PR-format handoff) runs every time. When in doubt, run more,
not less.

## Rules

Every phase follows these. Rationale and edge cases live in
`references/decisions.md`. The harness enforces the load-bearing ones in
code (see `safety.py` in the harness repo); the rest are prompt-level
guidance.

**Do not:**

- Change application behavior. The only exception is correcting a documented path reference in a code comment when the doc cleanup requires it.
- Delete a tracked file unless it is clearly stale, duplicate, generated, temporary, or superseded. Before deleting anything, run `git ls-files --error-unmatch <path>` — never delete an untracked file in the working tree, since it may be the user's in-progress work. (Harness-enforced: `UntrackedFileError`.)
- Execute uninspected scripts. Read the manifest or script first; if it does destructive, network, credential, deploy, publish, or privileged container work, do not run it. Report `Not run: <command>, reason: <why>` instead. (Harness-enforced: `RefusedCommandError`.)
- Use network access during verification unless it is explicitly required, scoped, and approved.
- Commit to `main`, self-approve, or self-merge. (Harness-enforced: `BranchPolicyError`; the harness has no merge code path.)
- Invent architecture, commands, tools, or workflows. When uncertain, mark as `Needs verification` rather than guess.
- Add new dependencies, packages, linters, or documentation frameworks unless explicitly requested.

## When to bypass the harness

The harness is the right tool for almost all cases. The only times it's
worth dropping back to a manual Claude Code workflow are:

- The harness binary isn't installed and you need a one-off pass — in which case the rules + references in this skill body are still the source of truth, and you should mirror the harness's phase order exactly.
- You're debugging the harness itself or investigating a regression in
  the harness's behavior against a specific repo.
- A platform other than GitHub is involved (GitLab, Bitbucket, Gitea)
  — the harness v1 ships only `GhPRCreator`. See the harness's
  contributor README for the `PRCreator` interface.

## References

- Phase-by-phase reference: `references/phases.md`
- Decision rules and classification criteria: `references/decisions.md`
- Document templates (README, AGENTS.md, HANDOFF, PR description): `references/templates.md`
- Harness design spec: [`D:\ai-agents\docs\superpowers\specs\2026-05-19-agent-harness-repo-doc-governance-design.md`](https://github.com/PatientVibes/ai-agents/blob/master/docs/superpowers/specs/2026-05-19-agent-harness-repo-doc-governance-design.md)
- Harness CLI / HTTP / batch docs: harness repo's README.md
