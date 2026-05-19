---
name: co-plan
description: Co-plan a non-trivial change with Gemini CLI as a second-opinion planner. Trigger when the user says "co-plan with gemini", "plan this with gemini", "let's get gemini's take on the plan", "plan this together", or types `/co-plan`. Use this for architectural decisions, multi-step migrations, or any plan where a second model's review materially reduces the chance of a missed dependency, wrong-approach choice, or unconsidered failure mode. Skip for trivial fixes — the round-trip cost isn't worth it. Different shape from `code-research` (which is one-shot Q&A); this skill is an iterative draft-critique-revise loop.
tools: Bash, Read, Write
---

# co-plan — Claude + Gemini collaborative planning

A two-model planning loop: Claude drafts a plan, Gemini critiques it, Claude revises, repeat until convergence (or the user calls it). The output is a single agreed plan ready for the user to approve.

This skill exists for the same reason `ship` runs Codex review on every PR — Claude reviewing its own plan is a weak signal. Gemini, with no conversation history and a fresh million-token read of the repo, catches a different class of mistake (missed dependencies, wrong sequencing, ignored constraints buried in some corner of the codebase, misjudged blast radius).

## Preconditions

- `gemini` is on PATH and authenticated. Same auth check as `code-research` skill — if `gemini -p "ping"` returns an auth error, ask the user to run `gemini` interactively once.
- Run from the repo root.
- The user has stated the goal of the change clearly. If the goal is fuzzy ("clean up the auth code"), nail it down with the user *before* invoking this skill — Gemini can't fix a vague goal, and the round trips will burn cycles to no purpose.

## When to use this skill

**Strong fit:**
- Architectural decisions with multiple defensible options ("should we extract X into a service or keep it inline?").
- Multi-step migrations / refactors where ordering matters.
- Plans that touch unfamiliar parts of the codebase where Claude's context is thin.
- High-blast-radius changes where the cost of a missed dependency is large.

**Bad fit — skip:**
- Bug fixes with an obvious root cause and a one-line fix.
- Plans that fit cleanly in Claude's existing context and don't benefit from a second read.
- The user already approved a plan — at that point, just implement (or use `ship`).

## Flow

### 1. Gather context

Read the files the change touches. Know what the current code does before drafting. If the surface area is large, run `Agent(Explore)` first or do a `code-research` pass to get a map.

### 2. Draft v1 of the plan

Write Claude's plan as a markdown document. Structure:
- **Goal** — one sentence, what the change accomplishes.
- **Constraints** — what must NOT change (contract surfaces, public APIs, data shape).
- **Approach** — chosen strategy in 2-5 sentences. Name the alternatives you considered and why you rejected them.
- **Steps** — ordered, each step is a concrete action against named files.
- **Risks / unknowns** — what could go wrong, what you're unsure about.
- **Verification** — how the user (and CI) will know it worked.

Save it to a temp file (`/tmp/coplan-v1.md` or similar) so it can be piped to Gemini cleanly.

### 3. Send to Gemini for critique

**Use `@file` syntax for any document Gemini needs to consult**, not prose like "read CLAUDE.md" or "check the ADRs." `@` forces immediate file injection at parse time; prose instructions let Gemini improvise (and confabulate). This is the single highest-leverage technique for reducing Gemini hallucination — see the `code-research` skill's "Always use `@file` for file references" section.

```bash
cat /tmp/coplan-v1.md | gemini --approval-mode plan -o text -m gemini-2.5-pro -p "$(cat <<'EOF'
You are a second-opinion reviewer on the plan piped above. Project context:

@CLAUDE.md
@docs/adr/

Answer:

1. Are there missed dependencies or files this plan should touch but doesn't? (List file:line if so — and `@`-quote the file in your answer so I can spot-check.)
2. Is the step ordering correct, or will an earlier step break something a later step relies on?
3. Are there constraints in the codebase the plan is violating? (Cross-reference against the injected CLAUDE.md and ADRs.)
4. Are the risks listed comprehensive? What did the author miss?
5. Is the verification plan sufficient to catch the failure modes you identified?

Be specific — quote file:line. If the plan is solid, say so plainly; don't manufacture concerns. Output as numbered findings, severity-tagged: CRITICAL / IMPORTANT / NIT.
EOF
)"
```

If the plan touches specific files Claude already identified, `@`-inject those too (e.g. `@src/auth/middleware.py @src/auth/session.py`). The more concrete the file injection, the lower the surface for confabulation.

Use `-m gemini-2.5-pro` for the planning loop — it's the more capable model and the round-trip is worth the latency for plan-grade decisions.

Capture the full output. Don't truncate.

### 4. Triage Gemini's findings

Sort each finding into a bucket:

| Bucket | Action |
|---|---|
| **CRITICAL — real flaw** (missed dependency, wrong order, violates a documented constraint) | Revise the plan. Re-loop. |
| **IMPORTANT — valid concern** | Address in plan v2 if cheap; otherwise document as accepted-risk and move on. |
| **NIT** (style, micro-optimization) | Skip. |
| **DISAGREEMENT** (Gemini's reading of the codebase looks wrong, or its suggestion conflicts with explicit user direction) | Verify by reading the code Gemini cites. If Gemini is wrong, note that in the plan and don't comply. If Claude is wrong, revise. Don't silently defer either way. |

**Anything Gemini reports as a fact about the codebase is a hypothesis until verified.** This includes file:line refs, function/file names, claims like "this constraint is documented in ADR-0007", counts ("there are 5 callers"), and enumerated lists. Gemini hallucinates these confidently, without uncertainty signaling, and the failure mode is well-documented in the upstream tracker (e.g. [google-gemini/gemini-cli#13672](https://github.com/google-gemini/gemini-cli/issues/13672), [#2799](https://github.com/google-gemini/gemini-cli/issues/2799), [#5582](https://github.com/google-gemini/gemini-cli/issues/5582)). A confidently-structured response with crisp section headers and quoted code is **not** evidence Gemini actually read the files. Verify before revising the plan. The `code-research` skill documents a concrete case (2026-05-03 chorus-postgres run) where Gemini fabricated counts, indices, and an entire 3-table misclassification list — worth reading once for calibration.

### 5. Revise → optional second loop

Write `coplan-v2.md` with the revisions. If the changes were substantial (touch >30% of the steps, or change the chosen approach), run *one* more Gemini pass on v2. If v2 is small tweaks to v1, skip the re-loop — diminishing returns and you're paying real latency.

Cap at **two Gemini passes** by default. If the plan still isn't converging after two rounds, that's a signal the goal itself is contested or under-specified — surface to the user instead of looping.

### 6. Present the final plan to the user

Show the user the converged plan with a one-paragraph summary of what Gemini flagged and how it was addressed. Format:

> **Plan:** [link to /tmp/coplan-vN.md or inline if short]
>
> **Gemini's review:** Flagged N issues — M addressed, (M-N) discussed and accepted as-is. Disagreements: [list, if any].
>
> **Ready to implement?**

Wait for explicit user approval before any implementation. This skill produces a plan; it does NOT execute it. (For execute-and-ship, hand off to the `ship` skill once the user approves.)

## Don'ts

- **Don't loop more than twice.** If two rounds don't converge, the goal is the problem.
- **Don't silently apply Gemini's revisions.** The user sees both v1 and what changed in v2 (or just vN with a delta summary).
- **Don't treat Gemini's vote as binding.** It's a second opinion. When models disagree, verify by reading code, then make the call yourself and explain it to the user.
- **Don't skip the verification section.** A plan without "how we'll know it worked" is half a plan.
- **Don't use this skill for trivial work.** A typo fix doesn't need a planning loop.

## Failure modes

- **Auth error** → user runs `gemini` interactively once.
- **Gemini returns generic feedback** ("looks reasonable to me") — usually means the plan was vague or the prompt didn't ask sharp enough questions. Tighten and retry once.
- **Gemini cites paths that don't exist (or claims constraints/ADRs that don't exist)** — verify with `Read` before acting. This is the named "confidently confabulate" failure mode upstream ([gemini-cli#13672](https://github.com/google-gemini/gemini-cli/issues/13672), [#2799](https://github.com/google-gemini/gemini-cli/issues/2799)); Gemini will invent files, ADR numbers, function names, and constraint citations with the same confidence it uses for real ones. Don't loop on hallucinated findings — and don't let a hallucinated "constraint violation" derail an otherwise-sound plan.
- **Plan keeps growing each round** — that's scope creep. Hold v1's scope; defer Gemini's adjacent suggestions to follow-up tickets.
