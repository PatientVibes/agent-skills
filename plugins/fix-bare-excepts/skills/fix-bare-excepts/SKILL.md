---
name: fix-bare-excepts
description: Find and fix bare except clauses and overly broad exception handling across the codebase
argument-hint: "[file-or-directory]"
allowed-tools: Read, Edit, Grep, Glob, Bash, Agent
---

# Fix Bare Except Clauses

Scan the codebase (or the specified file/directory via `$ARGUMENTS`) for bare `except:` clauses and overly broad `except Exception` catches, then fix them.

## Rules

1. **Bare `except:`** → Replace with `except Exception as e:` and add logging
2. **`except Exception as e: pass`** → Add `logger.debug(f"...")` before pass, or remove if truly unnecessary
3. **`except Exception as e:` catching too broadly** → Narrow to specific exception types where the intent is clear:
   - Import failures → `except ImportError`
   - Network issues → `except (ConnectionError, TimeoutError, httpx.HTTPError)`
   - JSON/XML parsing → `except (ValueError, KeyError, lxml.etree.XMLSyntaxError)`
   - Pydantic validation → `except pydantic.ValidationError`
4. **Never change exception handling in test files** — tests may intentionally catch broadly
5. **Preserve existing error messages** — only improve the catch clause, don't rewrite the handler body unless it's a bare `pass`

## Process

1. Search for bare `except:` and `except Exception` patterns
2. Read surrounding context (10 lines before/after) to understand intent
3. Apply the narrowest appropriate exception type
4. Ensure a logger exists in the file (import if needed)
5. Report a summary: files changed, patterns fixed, any that were left intentional

## Common hotspot patterns

Look at these areas of a Python codebase first — they tend to accumulate broad excepts:

- **Entity loaders and metadata initialization** — try-except-pass blocks around dynamic imports and registry registration
- **HTTP / SOAP / RPC clients with retry logic** — broad `except Exception` around request loops; should narrow to `(ConnectionError, TimeoutError, httpx.HTTPError, requests.RequestException)` (or equivalent for the client library)
- **Server bootstrap / startup code** — wholesale `except:` around config loading, plugin registration, and dependency wiring
- **Tool dispatch / command handlers** — broad catches around handler invocation that swallow real bugs as "unknown tool" errors

When inspecting these areas, prefer narrowing to the exception type that actually matches the failure mode the code is guarding against. If the original author's intent isn't clear, log at `DEBUG` and re-raise rather than silently passing.
