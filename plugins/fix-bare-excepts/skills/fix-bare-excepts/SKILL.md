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

## Known Hotspots

- `src/chorus_mcp_server/tools/entities/__init__.py` — 8+ bare excepts in metadata loading
- `src/chorus_mcp_server/soap_client.py` — broad retry exception types
- `src/chorus_mcp_server/_server.py` — mixed catch levels
