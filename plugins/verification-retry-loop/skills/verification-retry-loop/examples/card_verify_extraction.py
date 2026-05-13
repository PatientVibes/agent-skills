"""Excerpt from agent-harness-card-extractor:
card_extractor/agent.py — _verify_extraction() + _retry_extraction() + the
calling retry block.

Reference example of the verification-retry-loop pattern applied to
VLM-driven insurance/government card extraction. NOT runnable on its own
— requires the harness's CardExtraction Pydantic model, AgentContext,
wiki, validation, and trace plumbing.
"""

# --- _verify_extraction function body -------------------------------------


def _verify_extraction(
    extraction: CardExtraction,
    wiki_hints: Optional[dict] = None,
    validation: Optional[ValidationResult] = None,
) -> list[str]:
    """Returns list of issue descriptions. Empty = passed."""
    issues: list[str] = []

    if extraction.card_type == "INSURANCE":
        if extraction.insurance.subscriber_name == "NONE" and extraction.insurance.member_id != "NONE":
            issues.append("subscriber_name is NONE but member_id is populated")
    elif extraction.card_type == "GOVERNMENT":
        if extraction.government.name == "NONE":
            issues.append("Government card with no name extracted")

    if validation is None:
        validation = validate_extraction(extraction, wiki_hints)
    for vi in validation.issues:
        if vi.severity == "error":
            issues.append(f"{vi.field}: {vi.issue}")

    return issues


# --- _retry_extraction helper --------------------------------------------


async def _retry_extraction(
    crop_path: Path,
    original: CardExtraction,
    issues: list[str],
    ctx: AgentContext,
    wiki_context: Optional[str] = None,
) -> CardExtraction:
    """Re-extract with issue feedback -- max 1 retry (chorus-agent pattern)."""
    llm = create_extraction_llm(ctx.config)
    structured_llm = llm.with_structured_output(CardExtraction, include_raw=True)

    issue_text = "\n".join(f"- {i}" for i in issues)
    retry_prompt = EXTRACTION_RETRY_PROMPT.format(issues=issue_text)

    msg = _build_image_message(crop_path, retry_prompt)

    try:
        t0 = time.time()
        result = await retry_async(
            lambda: structured_llm.ainvoke([msg]),
            max_retries=1,
        )
        latency = time.time() - t0
        return _parse_structured_result(
            result, CardExtraction, ctx.tracker, ctx.trace,
            "extract_retry", ctx.config.vlm_model,
            latency_s=latency, result_summary=f"crop={crop_path.name}",
        )
    except Exception as e:
        logger.warning("Retry extraction failed: %s -- keeping original", e)
        return original


# --- Calling retry block (from the per-crop extraction pipeline) ----------
# (Excerpted from the crop-processing function, after `extraction` has been
# produced by the first VLM call and optionally re-extracted with wiki rules.
# `validate_extraction` is run once to seed the verifier; if `_verify_extraction`
# returns issues AND retries are budgeted, `_retry_extraction` is invoked once
# and validation is re-run on the result.)

# Validate
validation = validate_extraction(extraction, wiki_hints)

# Verification loop (pass existing validation to avoid double-validation)
issues = _verify_extraction(extraction, wiki_hints, validation=validation)
if issues and ctx.max_retry_attempts > 0:
    logger.info("Verification issues on %s: %s -- retrying", crop_path.name, issues)
    extraction = await _retry_extraction(
        crop_path, extraction, issues, ctx, wiki_context,
    )
    validation = validate_extraction(extraction, wiki_hints)
