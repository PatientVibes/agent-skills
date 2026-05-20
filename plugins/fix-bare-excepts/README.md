# fix-bare-excepts

Python exception-handling hygiene skill. Plugin in the `patientvibes-skills` marketplace.

## Status: v1

Promoted from chorus-mcp-server's project-scoped `.claude/skills/fix-bare-excepts/` on 2026-05-19. No genericization required — the original SKILL is framework- and project-agnostic; it just enforces standard Python exception-handling discipline.

## Skill

### `fix-bare-excepts`

Scans a codebase (or a specific file/dir passed via `$ARGUMENTS`) for bare `except:` clauses and overly broad `except Exception` catches, and narrows them to the appropriate specific exception type. Adds logging where exceptions were silently swallowed.

Mappings the skill applies:

| Pattern | Replacement |
|---|---|
| Bare `except:` | `except Exception as e:` + log |
| `except Exception as e: pass` | Add `logger.debug(...)` before `pass`, or remove if truly unnecessary |
| Import failures | `except ImportError` |
| Network issues | `except (ConnectionError, TimeoutError, httpx.HTTPError)` |
| JSON/XML parsing | `except (ValueError, KeyError, lxml.etree.XMLSyntaxError)` |
| Pydantic validation | `except pydantic.ValidationError` |

**Test files are excluded by convention** — tests may intentionally catch broadly to assert error paths.

## When to use

- Onboarding into a Python codebase and the first sweep finds dozens of bare excepts
- Triaging a production exception that was silently swallowed
- Linter complaints about `E722` (bare except) or `BLE001` (broad exception catch)
- Pre-merge cleanup pass on a PR that introduced new exception handling

## When NOT to use

- The codebase isn't Python (this is Python-specific — the patterns and exception types referenced are Python-stdlib + popular-library)
- The "broad catch" is intentional and documented (e.g. top-level error boundaries, retry-with-backoff outer loops)

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install fix-bare-excepts@patientvibes-skills
```
