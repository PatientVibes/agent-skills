---
name: csd-form-analysis
description: Use when analyzing SS&C AWD CSD binary forms for migration to Chorus Classic — provides the system prompt, ground rules, and AWD domain knowledge to drive a LangGraph ReAct agent that calls a CSD parser's tools (list_form_fields, get_field_detail, etc.) to produce a per-form `FormAnalysis` and cross-form `CrossFormReport`.
---

# csd-form-analysis

## When to invoke

When analyzing one or more parsed AWD CSD/LKP binary forms before migrating them to Chorus Classic XML. The skill assumes the agent has tools exposed for the parsed forms (typically `list_form_fields`, `get_field_detail`, `get_domain_values`, `get_form_summary`, `search_cross_form`, `compare_forms`, `suggest_field_type_promotion`).

## Workflow checklist

For each form being analyzed:

1. Call `list_form_fields(form_name)` to get the authoritative field list. **Never reference a field code not in this list.**
2. Call `get_form_summary(form_name)` to check field counts, DLL hooks, and form type.
3. Call `suggest_field_type_promotion(form_name)` to identify concrete upgrade candidates (input → datePicker, input → combobox).
4. For any field where the type is uncertain, call `get_field_detail(field_code)`.
5. Summarize: business purpose, classification, field observations **for every field** (no truncation), type promotions with specific reasons, DLL-hook interpretations (only if hooks are present), risk areas grounded in actual field data.

For batches of forms, follow each per-form analysis with:

6. Use `search_cross_form` and `compare_forms` to investigate field reuse across forms.
7. Identify duplicates (forms sharing ≥50% of field codes), inconsistencies (same code, different control types across forms), and classifications.
8. Produce 3–7 specific migration recommendations.

## Ground rules

See `prompts/system_prompt.md` for the verbatim system prompt the harness loads at runtime (with `{knowledge}` substituted to the contents of `knowledge/awd_reference.md`). The six load-bearing rules:

1. Only reference fields that exist in the form.
2. Empty DLL hooks → report "No DLL hooks present"; don't invent hook names.
3. "Field not found" from a tool means the dictionary is offline, not that the field is invalid.
4. Suggest type promotions only with concrete reasons.
5. **Chorus system fields** (`UNIT`, `WRKT`, `STAT`, `AMTV`, `AMTT`) have universal meaning — hard-coded rules, never looked up in a client field registry.
6. **LOB fields** are client-defined — use the registry when available, flag for client confirmation when unavailable.

## Files

- `prompts/system_prompt.md` — the verbatim system prompt with `{knowledge}` placeholder.
- `knowledge/awd_reference.md` — AWD domain reference (loaded into the prompt at runtime).

## Consumed by

`agent-harness-chorus-csd-analyzer` (sibling repo at `D:/agent-harness-chorus-csd-analyzer/`, GitHub: `PatientVibes/agent-harness-chorus-csd-analyzer`). The harness vendors copies of `prompts/system_prompt.md` and `knowledge/awd_reference.md` so it runs standalone; this skill is the source of truth for both files.
