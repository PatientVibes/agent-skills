---
name: human-review-loop
description: Use when an agent's outputs have variable confidence and some downstream consumer needs high precision. Pattern: gate output by a confidence threshold; route below-threshold items to a human review queue; feed corrections back as wiki rules so the agent learns over time.
---

# human-review-loop

## When to apply

Apply when ALL of these hold:

1. The agent emits a **confidence score** with each output (either from the LLM directly or computed via a deterministic validator).
2. The output has **downstream consumers** who can act on incorrect data — so silently passing through bad outputs has real cost.
3. **A human (or another agent) is available** to review queued items asynchronously.
4. **Corrections are reusable** — the same kind of mistake will recur, and a wiki rule could catch it next time.

Skip when:

- The pipeline is high-volume / low-stakes (false positives are cheap; review queue would never get drained).
- There's no learning loop — corrections happen one-off without feeding back.
- The confidence signal is uninformative (everything either confidently right or confidently wrong; the threshold can't separate the cases).

## The pattern

```python
async def extract_with_review(item, agent, queue, wiki, confidence_threshold=0.7):
    """Extract → validate → if confident: accept; if not: queue for review."""
    extraction = await agent.extract(item)
    validation = deterministic_validate(extraction)

    # Adjust confidence by validation issues
    adjusted = max(0.0, min(1.0, extraction.confidence + validation.confidence_adjustment))

    if not validation.valid or adjusted < confidence_threshold:
        queue.flag_for_review(
            source_ref=item.id,
            extraction=extraction,
            validation=validation.model_dump(),
            context=f"page={item.page} confidence={adjusted:.2f}",
        )
        return None  # don't surface low-confidence to downstream

    return extraction


# Separately, a review handler:
async def process_reviews(queue, wiki):
    """Periodic batch: human has reviewed; promote corrections to wiki."""
    for path in queue.list_pending():
        item = queue.read_pending(path)
        # Human reviews item via UI/CLI/etc.
        corrected = await get_human_correction(item)
        if corrected:
            queue.mark_reviewed(path, corrected=corrected)
            # Promote learnings back to the wiki for next time
            wiki.promote_human_correction(
                entity_key=item.extras.get("entity_key", "unknown"),
                sub_kind=item.extras.get("sub_kind"),
                frontmatter_patch=derive_pattern_from_correction(item.extraction, corrected),
            )
```

## Key invariants

1. **Confidence threshold is tunable.** Start at 0.7; adjust based on review-queue volume + downstream tolerance.
2. **Validation can adjust confidence.** A confidence-1.0 extraction that fails a regex check should drop below threshold.
3. **Low-confidence outputs DO NOT surface to downstream.** Queue them; don't pass-through-with-warning. The pattern only works if downstream trusts what it gets.
4. **Corrections feed back as wiki rules, not as one-off patches.** "User corrected member_id `02-1234567` to `021234567`" → wiki rule `patterns.member_id = r'^\d{9}$'`. Next time, validation catches it deterministically.
5. **Review queue is asynchronous.** The agent doesn't block waiting for human review. Items accumulate; a separate process drains them.

## Real-world example

**`agent-harness-card-extractor`** (`card_extractor/agent.py`) — the `_extract_single_card` flow applies this pattern:
- Adjusts confidence by validation result.
- Routes invalid extractions to `ReviewQueue.flag_for_review()`.
- Suppresses (returns None) for invalid extractions; keeps low-confidence-but-valid in the output stream with a flag.
- A separate `process_pass2` script drains the review queue and promotes corrections to the wiki.

## Pairs well with

- [`agent-tool-review-queue`](https://github.com/PatientVibes/agent-tool-review-queue) — the queue infrastructure.
- [`agent-tool-knowledge-wiki`](https://github.com/PatientVibes/agent-tool-knowledge-wiki) — the learning destination for corrections.
- Skill `verification-retry-loop` — apply BEFORE this; catch fixable issues with one retry before queuing for human.

## Anti-patterns

- **Synchronous review.** Agent blocks waiting for human input → throughput floor of human attention span.
- **Mixed-confidence outputs surfaced together.** "Here's 100 extractions; the last 10 are low-confidence" → downstream forgets and uses all of them.
- **One-off corrections without learning.** Corrections that don't promote to wiki rules → the same mistake recurs next batch.
- **Review queue grows unbounded.** No drainage process → eventually nobody opens it → the gate becomes a /dev/null.

## Provenance

Pattern extracted 2026-05-12 from `agent-harness-card-extractor`. See `D:/ai-agents/docs/superpowers/specs/2026-05-12-agent-toolbox-extraction-design.md`.
