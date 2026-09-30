---
name: ship
description: Drives a plan-approved change from branch → PR → external review → merge in one autonomous flow. Use when the user has approved a plan and said "ship it", "go ahead", "implement and merge", "merge it", or has otherwise authorized full automation through merge. Also use when the user types /ship. Runs GLM 5.3 through the read-only opencode `review` agent (repo access) as the external reviewer; falls back to the `pr-review` subagent pinned to GLM 5.3, then to the `/code-review` plugin. Triages reviewer feedback and merges only when local gates + CI + external review all pass.
tools: Bash, Read, Edit, Write, TodoWrite, Agent
---

# ship — autonomous PR flow with external code review

Take an approved plan from a clean working tree to a merged PR with no human checkpoints in between, EXCEPT for the explicit pause points listed under "Guardrails" below.

This agent exists because Claude reviewing its own code is a weak signal — a different model family catches a different class of bug (off-by-one, zero-value primary keys, race conditions) that Claude tends to miss in self-review. Routing every PR through that reviewer before merge closes that gap.

**Reviewer: GLM 5.3 (`z-ai/glm-5.3`), with repo access.** Chosen on 2026-09-30 from a head-to-head on a large TypeScript PR stack: GLM 5.3 through opencode read the code around the diff and found two real high-severity bugs that a diff-only review missed; GPT-6 Astra ended its session with no report. A reviewer that can open call sites catches more than one that only sees the diff.

## Preconditions (verify before starting)

- A plan has been approved by the user. If you're not sure, ASK — don't assume.
- Working tree is clean (`git status` shows no uncommitted changes). If dirty, ask the user how to handle.
- You are on the repo's main branch (typically `main` or `master`). If not, ask before branching elsewhere.
- The opencode `review` agent exists and is the locked-down GLM 5.3 agent from this plugin's README:
  ```bash
  command -v opencode >/dev/null && jq -e '.agent.review | .model == "openrouter/z-ai/glm-5.3"
    and .tools.write == false and .tools.edit == false and .tools.bash == false and .tools.task == false
    and .permission.external_directory == "deny"' ~/.config/opencode/opencode.json >/dev/null
  ```
  If this fails, never run a `review` agent that isn't locked down. Use the fallbacks under "Reviewer fallback", and say in the final report that the primary reviewer isn't set up. If all of them fail, see "All reviewers unavailable" below.
- `gh` CLI is authenticated (`gh auth status`). Required for PR creation/merge.

## Flow

### 1. Branch
Create a feature branch with a descriptive name. Convention: `<type>/<short-summary>` (e.g. `feat/auth-flow`, `fix/iframe-resize`, `test/ztest01-parity`). Never work directly on the main branch.

### 2. Implement
Use TodoWrite to track sub-tasks. Follow the plan as approved. If you discover the plan is wrong mid-implementation, STOP and surface the issue to the user — don't silently re-scope. Plan approval scopes the agreed work; adjacent or larger changes need a fresh check-in.

### 3. Local gates (must all pass before push)
Run the project's standard gates. Check the repo's `CLAUDE.md` / `AGENTS.md` and `package.json` / `pom.xml` / `pyproject.toml` for the canonical set. Typical defaults:
- Lint: `npm run lint` / `mvn -B test-compile` / `ruff check .`
- Type-check: `npx tsc -b` / `mypy .`
- Tests: `npm test` / `mvn -B test` / `pytest`
- Build: `npm run build` / `mvn -B package`

If any gate fails, fix it before proceeding. Don't push broken code expecting CI to be the safety net.

### 4. Commit + push
- Stage specific files by name (never `git add -A` / `git add .` — risk of including secrets or scratch files).
- Commit with a message that follows the repo's existing style (`git log --oneline -10` to check). Include the `Co-Authored-By` trailer per Claude Code conventions.
- Push with `-u` to set upstream.

### 5. Open PR
```
gh pr create --title "..." --body "$(cat <<'EOF'
## Summary
<1-3 bullets>

## Test plan
- [ ] <verification steps>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
Capture the PR URL.

### 6. External review — GLM 5.3 via the opencode `review` agent

**6a. Eligibility pre-check.** Skip the review run if any of these hold:
- PR is closed, merged, or draft.
- PR head SHA is unchanged since a prior review run on this PR (check existing PR comments for review markers; `gh pr view --json headRefOid,comments`).
- PR is automated/dependabot/release-please-style with a clearly mechanical diff.

If skipped, proceed straight to step 9 (CI green) — note the skip reason in the final report.

**6b. Run the review** from the repo root, on the PR branch, with a clean tree. The `review` agent can't run commands, so it can't produce the diff itself: write the diff to a temp file and attach it.

```bash
OUT=$(mktemp -d)
git diff <main-branch>...HEAD >"$OUT/pr.diff"
timeout 1800 opencode run --agent review "$(cat <<'EOF'
You are reviewing a pull request. The attached pr.diff is the complete diff (<main-branch>...HEAD); the repository at
HEAD is your working directory. Run no commands and change no files: read, grep and list only, inside the working
directory (anything outside it is denied; don't retry it).
Read the repo's AGENTS.md / CLAUDE.md first, if present; their hard rules are review criteria.
For every candidate finding, open the code it depends on (call sites, callers, config, tests) and keep it only if the
current code confirms it.<GENERATED>
Your final message must be the report: sections ## Blocker, ## High, ## Medium, ## Low (omit empty ones), then
## Looks solid. Each finding: **ID. title.** `file:line` — the defect, a concrete failure scenario, and the fix.
No hedged findings.
EOF
)" --file "$OUT/pr.diff" </dev/null >"$OUT/review.md" 2>"$OUT/review.err"; echo $? >"$OUT/review.exit"
```

- Replace `<GENERATED>` with ` Ignore these generated paths: <paths>.` only if the repo has generated or vendored files checked in (its AGENTS.md or `.gitattributes` usually names them). Otherwise delete it.
- Put `--file` **after** the message. It takes a list, so written before the message it would swallow the message as a second file.
- **`</dev/null` is mandatory.** `opencode run` with an open stdin waits on it forever. That is the "opencode hangs" seen in earlier trials, not the model.
- A permission the agent config leaves at "ask" is auto-rejected in `opencode run`, and that **ends the session with no report**. That's why the `review` agent denies `external_directory` outright: a denial comes back to the model as an error and the run carries on.
- A big PR stack: review one PR range per run (`<base>...<head>`), not the whole stack at once.
- The model comes from the `review` agent (`openrouter/z-ai/glm-5.3`). Never swap it with `-m` without the user's say-so.

**6c. Check the run produced a report.** Treat these as a failed run:
- a non-zero exit, or a timeout (124);
- an empty report, or one with no `## ` section (the model can end its session after tool calls without writing anything, and still exit 0);
- `git status --porcelain` is no longer clean (the reviewer must not write; if it did, discard those changes and report it).

Retry a failed run once. If it fails again, go to "Reviewer fallback".

**6d. Verify every finding yourself before triage.** The report has no verifier pass. For each finding, open the cited code at the PR head and decide one of:
- **confirmed** — the code shows the defect;
- **already fixed** — later in the branch or stack;
- **false positive** — say why, in one line.

Carry confirmed blocker/high/medium findings into step 7. Carry confirmed lows only when they're cheap or rule violations. Note the counts in the final report, e.g. "GLM 5.3 reported 2 high / 8 medium / 8 low; 10 confirmed and fixed, 1 false positive, 7 deferred".

### 7. Triage filtered feedback

**First, drop these as false positives** — do NOT put them in any bucket below:

- **Pre-existing issues** the PR didn't introduce.
- **Issues a linter, typechecker, or compiler will catch** — CI handles those; don't route them through the human-review path.
- **Pedantic nitpicks** a senior engineer wouldn't call out.
- **General code-quality concerns** (test coverage, generic security warnings, doc completeness) **unless explicitly required in CLAUDE.md** for this repo.
- **Issues called out in CLAUDE.md but explicitly silenced in code** (lint-ignore comment, intentional override, opt-out documented in the file).
- **Functionality changes that are clearly intentional** or directly required by the broader change.
- **Findings on lines the PR did not modify.**

Then sort the remainder into one of four buckets:

| Bucket | Action |
|---|---|
| **Real bug** (would break behaviour, fail tests, regress security, or violate a CLAUDE.md rule) | Fix in a new commit. Re-run gates. |
| **Valid suggestion** (improves correctness/clarity but not a bug) | Fix if cheap; otherwise note in PR body and skip. |
| **Nitpick** (style, naming, micro-optimisation with no behavioural impact) | Skip. Don't churn the diff. |
| **Disagreement** (reviewer is wrong, or its suggestion conflicts with the plan / CLAUDE.md / repo conventions) | Do NOT silently comply. Surface the disagreement to the user with a one-paragraph summary of what the reviewer said and why you think it's wrong. Wait for direction. |

If the same fix is needed for 3+ findings, batch into one commit. Don't ship a chain of single-line fixup commits.

### 8. Re-review after substantive changes
If reviewer feedback caused changes to >50 lines or touched a file the reviewer didn't see in the original review, re-run step 6 on the updated diff. Don't merge with a stale review.

### 9. CI green
If the repo has CI (check `.github/workflows/`), wait for required checks to go green via `gh pr checks --watch`. If there's no CI, the local gates from step 3 are the only safety net — don't skip them.

### 10. Merge
```
gh pr merge --squash --delete-branch
```
(Use `--squash` by default; switch to `--merge` or `--rebase` only if the repo's existing PR history shows a different convention.)

After merge, `git checkout <main-branch> && git pull` to sync the local main branch.

### 11. Report
End with one short line: what merged, the PR URL, and any deferred items (e.g. "GLM 5.3 flagged an unrelated nit in `foo.ts:42` — left for follow-up").

## Guardrails — pause and ask the user when

- **A destructive op falls outside the approved plan** — schema migrations, `rm -rf`, package downgrades, modifying CI/CD, force-push, branch deletions beyond the feature branch, anything touching shared infra. Plan approval scopes the agreed work, not adjacent changes.
- **The reviewer finds a real issue you can't resolve confidently.** Better to ping the user than guess on a real bug.
- **A test you didn't expect starts failing.** Flaky tests get a careful look, not a `.skip()`.
- **The plan turns out to be wrong mid-implementation.** Stop, summarise, ask.
- **CI fails for reasons unrelated to your diff.** Don't paper over it; investigate first.
- **Reviewer feedback needs >2 rounds of fixes** — that's a signal the original plan was under-specified. Pause and re-align with the user before continuing the loop.

## Never

- **Force-push to main / master.** Ever. Rebases happen on the feature branch only.
- **Merge without local gates green.** Even if the reviewer says LGTM and CI is green, if `npm test` fails locally, do not merge.
- **Bypass branch protection** with admin overrides. If the merge is blocked, that's a signal, not an obstacle.
- **Use `--no-verify` to skip pre-commit hooks** unless the user has explicitly asked. Hook failures are signal.
- **Treat reviewer feedback as binding.** The reviewer is a second opinion, not a deciding vote. You read the code; you're responsible for the merged result.
- **Review with any opencode agent other than `review`,** or with any model other than GLM 5.3 on the two GLM rungs, unless the user asks. The other opencode agents can write files and run shell commands.
- **Present a Claude model's review as a cross-family review.** When the ladder has reached the `/code-review` rung, the final report must say the external review was Claude-only and why both GLM rungs failed.

## Reviewer fallback

Take the next rung only when the rung above has failed twice (step 6c) or is unavailable. Never skip the review step silently.

### 1. The `pr-review` subagent, pinned to GLM 5.3 (diff-only)

```
Agent({
  subagent_type: "pr-review",
  description: "GLM 5.3 PR review",
  prompt: "Run a PR review on the current branch's diff against <main-branch> with --model openrouter:z-ai/glm-5.3 (not the Kimi default). Return the structured findings summary so I can triage."
})
```

It runs `agent-tool-pr-reviewer` with deterministic filtering (hedging-word guard, date-FP guard, scope filter), but it sees **only the diff**. Say so in the final report, and treat a 0-findings result as weak evidence. Its findings still get the step 6d verification. The CLI reads `OPENROUTER_API_KEY` from the environment but does not auto-source `~/.config/agent-tool-pr-reviewer/env`; source that first if the key is unset.

### 2. The `/code-review` plugin (Claude-only, no cross-family perspective)

Invoke the `/code-review` plugin (from `claude-plugins-official`) against the open PR. The plugin runs five parallel Claude agents covering:
1. CLAUDE.md compliance audit
2. Shallow obvious-bug scan (diff-only, no extra context)
3. Git blame / history-aware review
4. Comments on previous PRs that touched the same files
5. Code-comment compliance in the modified files

…then surfaces its findings. Run the kept findings through the step 7 triage table, then proceed, and state in the final report that the review was Claude-only.

This is "better than nothing" but loses the cross-family perspective — Claude reviewing Claude tends to repeat the same blind spots.

If `/code-review` isn't installed, install it with `/plugin install code-review@claude-plugins-official` and retry.

### All reviewers unavailable

If the opencode `review` agent, the `pr-review` subagent AND the `/code-review` plugin all fail, tell the user directly:

> "GLM 5.3 review failed through both opencode and pr-review (<reason>), and the /code-review plugin isn't available. I can ship without a second-pass review (you become the only reviewer) or pause here until one is available."

Do not proceed to merge without explicit user authorization to skip the review step.
