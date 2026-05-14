---
name: config-env-loading
description: Use when designing a new agent-tool-* / agent-harness-* CLI that reads API keys or secrets from the environment. Convention - tool reads from os.environ first; if the required key is unset, falls back to sourcing ~/.config/<tool-name>/env (mode 600). Avoids .env-in-cwd footguns and pairs cleanly with `op item get` 1Password workflows.
---

# config-env-loading

## When to apply

Apply when ALL of these hold:

1. The CLI is a personal-tool / single-user binary (not a server-class long-running process).
2. The tool needs a small number of secrets (1-3 keys, typically a single `*_API_KEY`).
3. The secrets come from a developer-machine source (1Password, manual paste, etc.) — not from a deployed secret manager (AWS / Vault / etc.).

Skip when:

- The tool is a deployable service — it should use the platform's secret manager.
- The tool already requires a config file with non-secret settings (different concern — use a `~/.config/<tool>/config.toml` rather than mixing secrets into the loader).
- The tool is invoked from a CI pipeline as its primary deployment surface — set env vars in the CI config and skip the fallback.

## The convention

**Location:** `~/.config/<tool-name>/env`

- `<tool-name>` matches the binary name (e.g., `agent-tool-llm-proofreader`, NOT the Python module name).
- One directory per tool. Don't nest under a shared `~/.config/patientvibes/` umbrella — keeps `Remove-Item` cleanup per-tool and makes ownership obvious.

**Permissions:**

- Directory `0700`.
- File `0600`.
- On Windows, file ACLs achieve the same effect via SecretManagement; the cross-platform default mode (`0o600`) is benign on NTFS even though it's not enforced.

**File format:** a minimal subset of shell `source`-able lines:

```bash
# Full-line comments allowed (must start with #)
KEY=value
export OTHER_KEY="value with spaces"
```

The loader handles: blank lines, full-line `#` comments, `export ` prefix, and one pair of surrounding single/double quotes on the value.

**Not supported** (out of scope — escape to a proper shell script if you need them): inline comments after a value (`KEY=value # comment` will include ` # comment` in the value), process substitution, variable interpolation, multi-line values, heredocs.

## The pattern

Drop this near the top of your CLI's `main()`:

```python
import os
from pathlib import Path


def _load_env_file_if_present(tool_name: str, required_key: str) -> None:
    """Source ~/.config/<tool_name>/env if `required_key` isn't already set.

    Mirrors a minimal `source <file>` for `KEY=value` and `export KEY=value`
    lines. Handles a single pair of surrounding quotes, `#` comments, and
    blank lines. Anything more exotic is out of scope.

    Invariants:
      - No-op if `required_key` is already in the environment OR the file
        doesn't exist.
      - Pre-existing env vars are NEVER overwritten (shell-exported values
        always win, for ALL keys — not just `required_key`).
      - Bad lines are silently skipped. The CLI's downstream KeyError on
        the missing key is the actionable error.
    """
    if os.environ.get(required_key):
        return
    env_path = Path.home() / ".config" / tool_name / "env"
    if not env_path.is_file():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):]
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        k = k.strip()
        if not k or k in os.environ:
            # Don't clobber pre-set env vars — caller's shell wins.
            continue
        v = v.strip()
        # Strip ONE pair of matching surrounding quotes (not all of them).
        if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
            v = v[1:-1]
        os.environ[k] = v


def main() -> int:
    _load_env_file_if_present("my-tool-name", "MY_TOOL_API_KEY")
    # ... rest of CLI ...
```

## One-time setup (operator's view)

Document this in the tool's README:

```bash
# 1Password integration - run once per machine, secret goes to disk encrypted-at-rest
KEY=$(op item get MyProvider --vault "Service Account" --field api-key --reveal)
mkdir -p ~/.config/my-tool-name
chmod 700 ~/.config/my-tool-name
cat > ~/.config/my-tool-name/env <<EOF
export MY_TOOL_API_KEY='$KEY'
EOF
chmod 600 ~/.config/my-tool-name/env
unset KEY
```

PowerShell equivalent (Windows):

```powershell
$token = Get-Secret -Name OP_SERVICE_ACCOUNT_TOKEN -AsPlainText
$env:OP_SERVICE_ACCOUNT_TOKEN = $token
$key = op item get MyProvider --vault "Service Account" --field api-key --reveal
$dir = "$HOME/.config/my-tool-name"
New-Item -ItemType Directory -Force $dir | Out-Null
"export MY_TOOL_API_KEY='$key'" | Set-Content "$dir/env" -Encoding utf8
```

## Why this shape

- **`os.environ` wins.** A user who exports the key in their shell for a one-off run overrides the file. CI pipelines that set env vars don't pay the file-stat cost.
- **`~/.config/<tool>/env` not `~/.<tool>rc`.** XDG-compliant; co-locates with other `~/.config/<tool>/` artifacts (cache, state) the tool may grow into. Avoids the cluttered home-directory dotfile pattern.
- **`<tool-name>` is the binary name.** Operators install via `uv tool install` which gives them a binary; they don't think in Python module names. Matching the binary makes the env-file path discoverable from the install command.
- **File, not directory of files.** One `env` file per tool is enough for 1-3 keys. Multiple files complicate setup without buying anything.
- **20 lines vendored, not a shared package.** Loader has zero dependencies and zero conditional behavior. A versioned dependency would be more friction than the copy-paste.

## Pairs well with

- **1Password CLI (`op`)** for the secret source. `op item get --reveal` pipes cleanly into the heredoc.
- **`[[reference_op_service_account_token]]`** memory for the PowerShell SecretManagement bootstrap.
- **`agent-tool-llm-proofreader`** as the canonical implementation. See `src/llm_proofreader/proofreader.py:_load_env_file_if_present()`.

## Anti-patterns

- **`.env` in CWD.** Footgun: leaks into git via accidental staging, leaks into Docker via `COPY .` , reads differently depending on where the user runs the command. Don't.
- **Shell-rc export.** Putting `export OPENROUTER_API_KEY=...` in `~/.bashrc` works but spreads secrets into every subshell + child process. Tool-scoped files are tighter.
- **World-readable mode (`0644`).** Even on a single-user laptop. The 0600 / 0700 modes are habit-forming and matter the moment the file syncs to a shared drive or backup.
- **Mixing secrets with non-secret config.** If the tool grows a `config.toml`, keep secrets in `env` and settings in `config.toml`. Don't dual-purpose the env file.
- **A shared `patientvibes-secrets` umbrella file.** Each tool's secrets are independent. Cross-tool coupling makes uninstall painful and gives the wrong tools access to the wrong keys.
- **Schema validation at load time.** The loader silently skips malformed lines. The downstream `os.environ["MY_KEY"]` `KeyError` is the actionable error — don't add a validation layer that produces less-actionable messages.

## Provenance

Convention proven in `agent-tool-llm-proofreader` (2026-05-09 migration). Documented as a skill 2026-05-14. Two anticipated next consumers: any future `agent-tool-*` that needs OpenRouter, and the cloud-side multi-model dispatch in `agent-tool-pr-reviewer` (which currently expects `OPENROUTER_API_KEY` already-exported and could adopt the fallback).
