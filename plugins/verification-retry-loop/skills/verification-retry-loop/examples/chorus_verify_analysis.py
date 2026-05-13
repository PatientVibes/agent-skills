"""Excerpt from agent-harness-chorus-csd-analyzer:
src/chorus_csd_analyzer/agent.py — _verify_analysis() + retry block.

Reference example of the verification-retry-loop pattern applied to
CSD form analysis. NOT runnable on its own — requires the harness's
chorus_forms upstream dependency and AgentContext.
"""

# --- _verify_analysis function body ---------------------------------------


def _verify_analysis(analysis: FormAnalysis, form: CsdForm) -> list[str]:
    """Verify a FormAnalysis against the source form data.

    Returns a list of issues found. Empty list means verification passed.
    """
    issues = []
    field_codes = {f.code for f in form.fields}
    analyzed_codes = {item.field for item in analysis.fieldAnalysis}

    # Check: how many fields were actually analyzed (not backfilled stubs)?
    non_stub = [
        item for item in analysis.fieldAnalysis
        if item.notes and "requires client field registry" not in item.notes
    ]
    coverage = len(non_stub) / len(form.fields) if form.fields else 1.0
    if coverage < 0.5:
        issues.append(
            f"Low field coverage: only {len(non_stub)}/{len(form.fields)} fields "
            f"have substantive analysis (need at least 50%)"
        )

    # Check: type promotions reference real field codes
    for promo in analysis.typePromotions:
        promo_codes = [c for c in field_codes if c in promo]
        if not promo_codes:
            issues.append(f"Type promotion references unknown field: {promo[:80]}")

    # Check: DLL hooks match actual hooks from the form
    actual_hooks = set(form.meta.dll_hooks)
    if not actual_hooks and analysis.dllHookInterpretation:
        issues.append(
            f"Analysis lists {len(analysis.dllHookInterpretation)} DLL hooks "
            f"but form has none"
        )

    # Check: risk areas don't reference non-existent field codes
    for risk in analysis.riskAreas:
        # Look for 4-char uppercase codes in the risk text
        import re
        codes_in_risk = re.findall(r'\b[A-Z][A-Z0-9#]{2,3}\b', risk)
        for code in codes_in_risk:
            if code not in field_codes and code not in {
                "AWD", "CSD", "LOB", "DLL", "API", "XML", "TIN", "SSN",
            }:
                issues.append(f"Risk area references unknown code '{code}': {risk[:60]}")
                break

    return issues


# --- Surrounding retry block from _analyze_single_form --------------------
# (Excerpted from inside `_analyze_single_form`, immediately after the first
# structured-extraction attempt has produced `analysis: FormAnalysis`. The
# retry calls `structured_llm.ainvoke(...)` a second time with the issue
# list fed back via a SystemMessage. One retry only — on retry exception,
# the first-attempt `analysis` is kept.)

# Verify extraction quality and retry once if issues found
issues = _verify_analysis(analysis, form)
if issues:
    logger.info("Verification found %d issues for %s, retrying extraction", len(issues), stem)
    issue_text = "\n".join(f"- {i}" for i in issues)
    try:
        retry_result = await structured_llm.ainvoke([
            SystemMessage(content=(
                f"The previous extraction had quality issues. Fix them:\n"
                f"{issue_text}\n\n"
                f"Re-extract the analysis for this form with {len(form.fields)} fields. "
                f"Include an entry in fieldAnalysis for EVERY field. "
                f"Only reference field codes that exist in the form. "
                f"Only list DLL hooks if the form actually has them."
            )),
            final_message,
        ])
        if isinstance(retry_result, FormAnalysis):
            analysis = retry_result
        elif isinstance(retry_result, dict):
            analysis = FormAnalysis(**retry_result)
        else:
            parsed = getattr(retry_result, "parsed", retry_result)
            if isinstance(parsed, FormAnalysis):
                analysis = parsed
            elif isinstance(parsed, dict):
                analysis = FormAnalysis(**parsed)

        if tracker is not None:
            um = getattr(retry_result, "usage_metadata", None)
            if um:
                tracker.record(source="agent_structured", form_name=f"{stem}_retry",
                               model=model,
                               input_tokens=um.get("input_tokens", 0),
                               output_tokens=um.get("output_tokens", 0))
    except Exception as retry_err:
        logger.warning("Verification retry failed for %s: %s", stem, retry_err)
