---
name: code-research
description: Use Gemini CLI as a second-opinion / large-context research assistant on the current repo. Trigger when the user says "ask gemini", "have gemini look at", "second opinion from gemini", "research with gemini", "what does gemini think", or types `/code-research`. Also good when a question would benefit from Gemini's million-token context window (whole-codebase reasoning, cross-cutting design questions, "find every place that does X across the whole repo"). Skip for targeted greps (use Bash), single-file lookups (use Read), or questions Claude already has the relevant context for in this conversation — the round-trip isn't free.
tools: Bash, Read
---

# code-research — Gemini CLI as a research / second-opinion tool

Spawn `gemini -p` as a non-interactive child process to ask a second model a research or design question. Gemini's large context window (~1M tokens) means it can reason across far more of the repo at once than fits in Claude's working context, and it gives an independent read that catches things Claude's self-review misses.

This is a **read-only** tool by convention here. We always pass `--approval-mode plan` so Gemini can't edit, run, or mutate anything — we just want its analysis.

## Preconditions

- `gemini` is on PATH (`which gemini` should resolve to `~/.npm-global/bin/gemini`).
- Auth is configured. First-run requires the user to run `gemini` interactively once and complete the OAuth browser flow. If `gemini -p "ping"` returns an auth error, surface that to the user — don't try to fix auth from a non-interactive Bash call.
- Run from the repo root unless you have a reason to scope the workspace tighter. Gemini reads the cwd as its workspace.

## When to use this skill

**Strong fit:**
- "How is X implemented across the whole codebase?" / "Find every callsite of Y and summarize the patterns."
- Design questions where the answer depends on context Claude can't fit: "Should we move X into module Y, given how the rest of the repo is organized?"
- Second opinion on a non-trivial change: "Here's my diff/plan — what does gemini think?"
- Reading a foreign codebase fresh — Gemini can ingest more of it in one shot than Claude.
- Catching cross-cutting bugs Claude tends to miss in self-review (off-by-one, batch-isolation, PK-shape mistakes, race conditions).

**Bad fit — skip the skill, use the right tool:**
- "Where is `foo` defined?" → `grep` / `Read`.
- "Open this file." → `Read`.
- "Plan this implementation." → use `co-plan` skill (it's a different shape).
- Anything Claude already has the answer to in conversation context.
- **Extraction tasks against data files** — exact counts, exact list of items in a JSON/CSV, set membership, "how many entries match X". Gemini will confidently emit fabricated numbers and lists for these. Compute the facts in Python/jq/grep instead. If you need Gemini's judgment on the extracted facts, **pipe them in via stdin** (see below) — Gemini-as-classifier over verified data, not Gemini-as-extractor.

## How to invoke

Always use these flags together:

```
gemini -p "<prompt>" --approval-mode plan -o text
```

- `-p "<prompt>"` — non-interactive (headless) mode. Required.
- `--approval-mode plan` — read-only. Gemini cannot edit, exec, or mutate.
- `-o text` — plain text output to stdout. Easy to capture.
- Add `--include-directories <path>` if relevant context lives outside cwd.
- Add `-m gemini-2.5-pro` to pin the more capable model when the question is non-trivial; otherwise the default is fine.

For long prompts, use a heredoc and pipe to `-p`:

```bash
gemini --approval-mode plan -o text -p "$(cat <<'EOF'
Read src/procedures/purge_image_smc_insert.sql and src/procedures/purge_image_smc_error.sql.

Question: the Y15 LOCATOR derivation gates on OSYSID matching specific values. Across the rest of src/procedures/, are there other places that gate LOCATOR derivation on OSYSID, or is this branch unique? Answer with a list of file:line refs and a one-paragraph summary.
EOF
)"
```

If you need to feed Gemini a draft, your own analysis, or a diff, pass it through stdin — Gemini appends stdin to the `-p` prompt:

```bash
git diff master...HEAD | gemini --approval-mode plan -o text -p "Critique this diff. Look for batch-isolation bugs, PK-shape mistakes, and off-by-one errors. Be specific — quote file:line for each finding."
```

## Always use `@file` for file references

The single highest-leverage technique for reducing Gemini hallucination, per the tool's creator: **use `@path/to/file` syntax inside the prompt instead of writing prose like "load this file" or "read these files."** `@` forces immediate file injection at parse time; prose instructions let the model improvise (and confabulate).

**Wrong** — prose instruction, prone to hallucination:
```bash
gemini -p "Load data/foo.json and data/bar.json, then answer ..."
```

**Right** — explicit `@` injection:
```bash
gemini -p "@data/foo.json
@data/bar.json
Now answer ..."
```

Multiple `@` references work in one prompt: `Compare @./foo.py and @./bar.py and tell me the differences.` Gemini also respects `.gitignore` and `.geminiignore` when resolving `@` paths, so `@./` on a project root won't slurp `node_modules`.

**Stdin-grounding pattern (preferred for data tasks):** for anything that requires exact extraction first, compute the facts in Python and pipe them in. Don't ask Gemini to do the extraction itself.

```bash
python3 extract_candidate_misclassifications.py | gemini --approval-mode plan -o text -p "@data/contract_manifest.json
The list above is candidate misclassified tables (column 1) with their classification (column 2). Reason about which are real bugs vs false positives. Cite each call."
```

## Prompt construction

Gemini behaves like Claude in that prompt quality dominates output quality. A good code-research prompt has:

1. **Concrete files / paths** the question is about — naming them upfront keeps Gemini's first read targeted.
2. **A specific question** — "summarize the auth flow" beats "tell me about auth."
3. **An output shape** — "list file:line refs", "answer in three bullets", "give me a punch list of risks". Without this Gemini tends to write long essays.
4. **What you've already ruled out**, if any — saves a round trip.

Avoid:
- "Tell me about the codebase." (too open — Gemini will summarize generically)
- Multi-question prompts. Ask one thing at a time.
- Prompts that assume conversation history Gemini doesn't have. Gemini is fresh every invocation.

## Handling the response

Gemini CLI hallucinates **confidently**, without uncertainty signaling, and the failure mode is well-documented in the upstream tracker (e.g. [google-gemini/gemini-cli#13672 — INCIDENT REPORT: SYSTEM HALLUCINATION & QUALITY DEGRADATION](https://github.com/google-gemini/gemini-cli/issues/13672), [#2799](https://github.com/google-gemini/gemini-cli/issues/2799), [#5582](https://github.com/google-gemini/gemini-cli/issues/5582), [#12606](https://github.com/google-gemini/gemini-cli/issues/12606), [#14754](https://github.com/google-gemini/gemini-cli/issues/14754)). Verification is the only defense.

- Pipe to `head -200` or similar if you only need a summary. Gemini's responses can be long.
- **Anything Gemini reports as a fact about your data is a hypothesis, not a finding** — counts, lists, set membership, file:line refs, function names, table classifications, line numbers. Regenerate deterministically before acting on it. This is broader than just "verify file:line citations": Gemini will fabricate summary statistics ("1313 entries", "42 matches") and entire enumerated lists with the same confidence as line numbers.
- **File:line citations specifically** — Gemini in `--approval-mode plan` appears to have grep but not full file-read access in some configurations, and will confidently confabulate line numbers and surrounding code. In one observed run on a 16-line dispatcher proc, Gemini cited lines 110, 160, and 187 with fabricated content. Treat citations as claims to be checked against `Read`, not as ground truth.
- A confidently-structured response with crisp section headers and quoted SQL/code is **not** evidence Gemini actually read the files. Verify before acting.
- If you'd act on a finding, surface it to the user with the source ("Gemini flagged X at file:line — here's the relevant code, do you want to address it?"). Don't silently apply fixes Gemini suggested.
- If Gemini says "the code does X" and Claude's verified read says Y, do NOT split the difference. The right move when models disagree is to verify, not vote — and Claude's verified read wins over Gemini's grep+confabulate.

## Cost / round-trip awareness

Each `gemini -p` invocation is a real API call with real latency (often 10-60s for non-trivial prompts on a large repo). Don't fire it speculatively. Fire it when:
- The question is genuinely large-context (won't fit in Claude's window comfortably), or
- An independent read is the *point* (second-opinion review, cross-check), or
- The user explicitly asked for Gemini's input.

Otherwise prefer `Agent(Explore)`, `grep`, or direct `Read` — they're cheaper and sit in Claude's context.

## Failure modes

- **Auth error**: Surface to the user. They run `gemini` interactively once to complete browser OAuth.
- **Timeout / hang**: Bound the Bash call with `timeout: 120000` (2 min). Long prompts on large repos can take a while; if it's still running past 2 min something is wrong.
- **Empty / generic response**: Usually means the prompt was too vague. Tighten and retry once. Don't loop indefinitely.
- **Gemini wants to edit files**: It can't — `--approval-mode plan` blocks that. If you see it complain about read-only mode, the flag worked.

## Documented failure mode (2026-05-03)

A concrete case study illustrating why the verification rule above is non-negotiable.

**The task:** verify whether a regex bug in `build_contract_manifest_lib.py` (issue #61 in chorus-postgres) was currently active by cross-referencing two JSON files (`data/dao_sql_postgres_extensions.json`, `data/contract_manifest.json`). Three questions: total entry count, list of missed tables, list of misclassified-as-internal tables.

**The prompt (anti-pattern):** prose instruction "Load these two files in full" + three extraction questions. No `@` syntax. No stdin pre-extraction.

**Gemini's confidently-formatted response:**
- Total entries: **1313** (actual: 964)
- Comma-chained matches: **42** (actual: 174)
- Cited indices `555/631/844/1308/1310` (1308 and 1310 are out of range — array has 964 entries; in-range indices didn't match the regex anyway)
- Three misclassified tables: `W23U999S`, `W98U999S`, `WB5U999S` — none of which appear in the actual missed-tables set

**The actual ground truth** (computed via Python in ~30s): one real misclassification (`WR4U999S`) plus one override-compensated case (`WJ0U999S`). Gemini fabricated the entire answer.

**What we should have done:**
1. Compute the missed-tables set in Python first
2. Pipe it via stdin into Gemini, with `@data/contract_manifest.json` for cross-reference, asking only "of these missed tables, which look like real tables vs SQL keywords vs column-name false positives?" — Gemini-as-classifier on verified data, not Gemini-as-extractor.

The error mode here matches the documented pattern in [gemini-cli#13672](https://github.com/google-gemini/gemini-cli/issues/13672): "system relied on cached intuition rather than actual retrieval of specific content, leading to false claims that contradict explicitly-shown text." The structured response (with section headers, a markdown table, and quoted SQL) gave no surface signal of the underlying confabulation. The skill's verification rule caught it before incorrect evidence was posted to a public issue.
