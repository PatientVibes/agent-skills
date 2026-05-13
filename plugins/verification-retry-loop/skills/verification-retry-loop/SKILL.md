---
name: verification-retry-loop
description: Use when an agent does structured Pydantic extraction from an LLM and deterministic post-checks are cheap. Pattern: extract → verify deterministically → if issues, re-extract once with issues fed back into the prompt → accept the second attempt. Bounded retries — never loop more than once on verification.
---

# verification-retry-loop

## When to apply

Apply when ALL of these hold:

1. The agent does **structured Pydantic extraction** via LangChain's `with_structured_output()` or equivalent.
2. The output has **deterministic post-checks** that are cheap to run (regex, set membership, simple invariants — not "ask another LLM").
3. The cost of a wrong answer is **higher than the cost of one retry** (e.g., it ships to a user, hits production, gets persisted).
4. Issues found by the verifier are **describable in natural language** (so they can be fed back into the prompt).

Skip when:

- The extraction is cheap and you have other downstream validation.
- The verifier disagrees with itself (paradoxical — retries won't help).
- The output is high-volume / low-stakes (retries dominate cost).

## The pattern

```python
async def extract_with_verification(model, prompt, input_data, verify_fn, max_retries=1):
    """Extract → verify → retry once with issue feedback → accept."""
    structured = model.with_structured_output(YourPydanticModel)

    # First attempt
    result = await structured.ainvoke(prompt + input_data)

    issues = verify_fn(result, input_data)
    if not issues or max_retries == 0:
        return result

    # Second attempt with issues fed back
    issue_text = "\n".join(f"- {i}" for i in issues)
    retry_prompt = f"""
The previous extraction had quality issues. Fix them:
{issue_text}

Re-extract the same input.
"""
    try:
        retry_result = await structured.ainvoke(retry_prompt + input_data)
        return retry_result
    except Exception:
        # Retry failed; fall back to first attempt
        return result
```

## Key invariants

1. **One retry only.** Never loop. If the verifier disagrees with both attempts, accept the second and surface the issues elsewhere (e.g., review queue).
2. **Verifier is deterministic.** No LLM calls inside the verifier — that's its own verification problem. Use regex, set checks, cross-references against known-good data.
3. **Issues fed back as natural language.** The retry prompt names what was wrong. The LLM responds to "here's what you got wrong: X" better than to "try again."
4. **First-attempt result is the fallback.** If the retry attempt itself errors out (e.g., schema validation fails on the retry response), keep the first-attempt result rather than dropping.
5. **Confidence ≠ correctness.** A successful verification means "no detectable issues," not "definitely correct." Still gate by confidence threshold + route to a review queue for high-stakes cases.

## Real-world examples

Two existing implementations in PatientVibes harnesses:

- **`agent-harness-chorus-csd-analyzer`** (`src/chorus_csd_analyzer/agent.py`) — `_verify_analysis()` checks: field-coverage ratio, references to non-existent field codes, DLL hooks hallucinated against an empty actual list. Single retry. See `examples/chorus_verify_analysis.py` for an excerpt.

- **`agent-harness-card-extractor`** (`card_extractor/agent.py`) — `_verify_extraction()` checks: required fields populated, no placeholder IDs (`"000000000"`, `"NONE"` in wrong slots), wiki-derived regex pattern matches. Single retry. See `examples/card_verify_extraction.py` for an excerpt.

## Pairs well with

- `agent-tool-llm-utils` — `retry_async` for the LLM call itself (separate concern: transient network failures vs. verifier-detected output issues).
- `agent-tool-review-queue` — route unsalvageable items (still bad after retry) to human review.
- `agent-tool-pipeline-trace` — record verification outcomes (`event_type="verification_pass"` / `"verification_retry"` / `"verification_failed"`) for later analysis.

## Anti-patterns

- **Multi-retry loops.** Two attempts is the contract. Three+ wastes tokens and rarely converges.
- **LLM verifier.** "Ask another LLM if this is right" is its own verification problem. Verifier must be deterministic code.
- **Silent retry.** Log when a retry is triggered and what issues prompted it. Otherwise you can't tune the verifier or detect regressions.

## Provenance

Pattern extracted 2026-05-12 from the two reference harnesses where it co-evolved. The skill documents the canonical shape; consumers vendor or re-implement against their own verifier + extraction types.

See `D:/ai-agents/docs/superpowers/specs/2026-05-12-agent-toolbox-extraction-design.md`.
