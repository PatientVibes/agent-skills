---
description: Run the canonical "is this branch clean?" gate pipeline for the current chorus repo
argument-hint: [--quick | --full | --e2e] [--repo <name>]
---

Run the gate pipeline for the current repo. Detect the repo from `cwd`, run the right commands, report a clean pass/fail summary.

Args: $ARGUMENTS

## Detection

Identify the repo by markers in `cwd` (or up to two parent dirs):
- `pom.xml` with `<artifactId>chorus-comms</artifactId>` → **chorus-comms**
- `pom.xml` with `<artifactId>v2-api</artifactId>` → **chorus-v2-api**
- `package.json` + `vite.config.ts` → **chorus-forms-app**
- `Makefile` + `docker-compose.yml` + `wildfly/` → **chorus-platform**
- `flyway/` + `src/procedures/` → **chorus-postgres**
- `harmony-api/` + `streaming/` → **chorus-harmony**

If `--repo <name>` is passed, `cd` into that repo first. If detection fails, list candidates and ask.

## Gate levels

- **`--quick`** (default if user passed nothing high-stakes): typecheck + lint only. Fast, no test execution.
- **standard** (default when no flag): quick + unit tests. The "is this branch clean?" canonical gate.
- **`--full`**: standard + integration tests + extra checks (long).
- **`--e2e`**: standard + Playwright/end-to-end (slowest).

## Per-repo commands

### chorus-comms (Java 25, Spring Boot 3.5)
- quick: `mvn -B -q compile test-compile`
- standard: `mvn -B test`
- full: `mvn -B verify`
- (e2e: same as standard — no separate e2e suite)

If `JAVA_HOME` is unset and bare `java -version` reports <25, prefix with `JAVA_HOME=$HOME/.jdk/jdk-25.0.2`.

### chorus-v2-api (Java 17, Spring Boot 3.2)
- quick: `mvn -B -q compile test-compile`
- standard: `mvn -B test`
- full: `mvn -B verify`

### chorus-forms-app (React 19 + TS + Vite)
- quick: `npx tsc -b` then `npx eslint .`
- standard: quick + `npx vitest run`
- full: standard + `npx tsc --noEmit -p tsconfig.test.json` + `npm run build`
- e2e: standard + `npx playwright test`

### chorus-platform (infra)
- quick: validate every compose file (`docker compose -f <file> config -q` for each `docker-compose*.yml` found via `find . -maxdepth 4 -name "docker-compose*.yml"`) + `bash -n` on every `*.sh`
- standard: quick + `make test-api` (requires `CHORUS_PASSWORD` env)
- full: standard + `make test`
- e2e: standard + `make test-e2e`

### chorus-postgres
- quick: `python3 -m pytest tests/ --collect-only -q` (verifies test discovery)
- standard: `python3 -m pytest tests/ -q`
- full: standard + `python3 scripts/validate_schema.py` + `python3 scripts/validate_procedures.py`

### chorus-harmony
- quick (harmony-api): `cd harmony-api && npx eslint .`
- standard (harmony-api): quick + `cd harmony-api && npx vitest run`
- quick (full repo): `bash -n` every `*.sh` under `harmony/`, `streaming/`, `deploy/`
- if cwd is repo root, run both quick passes; otherwise scope to the subdir.

## Execution rules

1. **Run gates sequentially**, not in parallel — if `tsc` fails there's no point running tests.
2. **Bail on first failure** in the chain. Print which step failed and the last ~30 lines of output.
3. **Report cleanly** at the end: a checklist showing each step's status (✓/✗) and total time. Example:

   ```
   chorus-comms (standard gate):
     ✓ compile + test-compile  (4.2s)
     ✗ mvn -B test             (38.1s) — 3 failures in DocumentDeliveryServiceTest
   ```

4. **Don't auto-fix.** Surface failures for the user to act on. Do not edit code, retry with different args, or "smart-skip" tests.

5. **Don't run `--full` or `--e2e` unprompted.** Standard is the default; longer tiers only when the user explicitly asks.

6. **Stream long output to a temp file** and `tail -20` for display so the conversation doesn't fill with build noise. Show the file path in case the user wants the full log.
