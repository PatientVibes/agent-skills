#!/usr/bin/env bash
# seed-claude-skills.sh — bring a Claude Code environment to the
# PatientVibes standard layout. Idempotent: safe to re-run.
#
# Design: docs/superpowers/plans/2026-05-20-skills-standardization-coplan-v2.md
# Inventory: docs/superpowers/plans/2026-05-20-skills-standardization-inventory.md
# (in the github.com/PatientVibes/ai-agents catalog repo)
#
# Run from any directory. Reads `plugins.txt` next to itself.
#
#   bash seed-claude-skills.sh             # interactive default
#   bash seed-claude-skills.sh --dry-run   # show what would change, modify nothing
#   bash seed-claude-skills.sh --strict    # fail on warnings (CI mode)
#   bash seed-claude-skills.sh --skip-secrets  # don't scaffold ~/.config/<tool>/env
#
# Override the Claude binary location:
#   CLAUDE_BIN=/path/to/claude bash seed-claude-skills.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_FILE="${PLUGINS_FILE:-$SCRIPT_DIR/plugins.txt}"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"

# Marketplaces to register (source values follow `claude plugin marketplace add`).
declare -a MARKETPLACES=(
    "claude-plugins-official|anthropics/claude-plugins-official"
    "patientvibes-skills|PatientVibes/agent-skills"
)

# Tier-2 raw copies that become redundant once their Tier-1 plugin is installed
# AND has passed smoke-test. Removed from `~/.claude/skills/`.
declare -a TIER2_DEDUPE=(
    "co-plan|co-plan@patientvibes-skills"
    "code-research|code-research@patientvibes-skills"
    "graphify|graphify@patientvibes-skills"
    "ship|ship@patientvibes-skills"
    "repo-documentation-governance|repo-documentation-governance@patientvibes-skills"
    "skill-creator|skill-creator@claude-plugins-official"
)

# Per-repo `skill-creator` duplicates from the 2026-05-20 inventory.
declare -a PER_REPO_DUPES=(
    "$HOME/chorus-repos/chorus-admin-app/.claude/skills/skill-creator"
    "$HOME/chorus-repos/chorus-testing/.claude/skills/skill-creator"
    "$HOME/chorus-repos/chorus-forms/.claude/skills/skill-creator"
    "$HOME/chorus-repos/chorus-v2-api/.claude/skills/skill-creator"
    "$HOME/chorus-repos/chorus-forms-app/.claude/skills/skill-creator"
)

# Raw command files under ~/.claude/commands/ that are now provided by a
# plugin. Per the 2026-05-20 empirical probe (R3 result), raw files shadow
# plugin-provided slash commands — so removing the raw file is the
# ACTIVATION step, not just cleanup. The script moves to a `.pre-plugin.bak`
# rather than rm so the operator can roll back if the slash command
# misbehaves after activation. See docs/superpowers/plans/
# 2026-05-20-chorus-dev-commands-plugin-coplan-v3.md in the ai-agents catalog.
declare -a COMMAND_ACTIVATION=(
    "check.md|chorus-dev-commands@patientvibes-skills"
    "db.md|chorus-dev-commands@patientvibes-skills"
    "oc.md|chorus-dev-commands@patientvibes-skills"
)

# Tools the harness ecosystem auto-sources secrets from
# (see agent-harness-repo-doc-governance v0.1.7 / agent-tool-llm-proofreader).
# The script scaffolds the directory + file at mode 600 and writes a commented
# template — NEVER writes secret values.
declare -a SECRET_FILES=(
    "$HOME/.config/repo-doc-gov/env"
    "$HOME/.config/agent-tool-llm-proofreader/env"
)

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

DRY_RUN=0
STRICT=0
SKIP_SECRETS=0
WARNINGS=0

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

if [ -t 1 ]; then
    RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'; DIM=$'\033[2m'; NC=$'\033[0m'
else
    RED=""; YELLOW=""; GREEN=""; BLUE=""; DIM=""; NC=""
fi

log_info()  { printf '%sinfo%s   %s\n' "$BLUE" "$NC" "$*"; }
log_ok()    { printf '%sok%s     %s\n' "$GREEN" "$NC" "$*"; }
log_skip()  { printf '%sskip%s   %s\n' "$DIM" "$NC" "$*"; }
log_warn()  { printf '%swarn%s   %s\n' "$YELLOW" "$NC" "$*" >&2; WARNINGS=$((WARNINGS+1)); }
log_error() { printf '%serror%s  %s\n' "$RED" "$NC" "$*" >&2; }
log_step()  { printf '\n%s== %s ==%s\n' "$BLUE" "$*" "$NC"; }

die() {
    log_error "$@"
    exit 1
}

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s[dry-run]%s %s\n' "$DIM" "$NC" "$*"
        return 0
    fi
    "$@"
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Seed a Claude Code environment to the PatientVibes standard layout.

Options:
  --dry-run         Show what would change; modify nothing.
  --strict          Treat warnings as failures (CI mode). Exit non-zero if
                    any warning fires.
  --skip-secrets    Don't scaffold ~/.config/<tool>/env files.
  -h, --help        Show this message.

Environment:
  CLAUDE_BIN        Path to the claude binary (default: ~/.local/bin/claude).
  PLUGINS_FILE      Path to plugins.txt (default: next to this script).
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)      DRY_RUN=1 ;;
        --strict)       STRICT=1 ;;
        --skip-secrets) SKIP_SECRETS=1 ;;
        -h|--help)      usage; exit 0 ;;
        *)              log_error "unknown arg: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Step 1 — locate claude
# ---------------------------------------------------------------------------

step_locate_claude() {
    log_step "1. Locate claude CLI"
    if [ ! -x "$CLAUDE_BIN" ]; then
        if command -v claude >/dev/null 2>&1; then
            CLAUDE_BIN=$(command -v claude)
            log_info "using \`claude\` from PATH: $CLAUDE_BIN"
        else
            die "claude CLI not found at $CLAUDE_BIN and not on PATH. Set CLAUDE_BIN or install Claude Code."
        fi
    fi
    local version
    version=$("$CLAUDE_BIN" --version 2>&1 | head -1)
    log_ok "claude found at $CLAUDE_BIN ($version)"
}

# ---------------------------------------------------------------------------
# Step 2 — register marketplaces
# ---------------------------------------------------------------------------

marketplace_registered() {
    local name=$1
    "$CLAUDE_BIN" plugin marketplace list 2>/dev/null \
        | grep -Eq "^[[:space:]]*[^[:space:]]*[[:space:]]*${name}([[:space:]]|$)"
}

step_register_marketplaces() {
    log_step "2. Register marketplaces"
    local entry name source
    for entry in "${MARKETPLACES[@]}"; do
        name="${entry%%|*}"
        source="${entry#*|}"
        if marketplace_registered "$name"; then
            log_skip "marketplace already registered: $name"
        else
            log_info "registering marketplace: $name ($source)"
            run "$CLAUDE_BIN" plugin marketplace add "$source"
        fi
    done
}

# ---------------------------------------------------------------------------
# Step 3 — install + smoke-test plugins
# ---------------------------------------------------------------------------

plugin_installed() {
    local plugin_at_market=$1
    "$CLAUDE_BIN" plugin list 2>/dev/null \
        | grep -Fq " ${plugin_at_market}"
}

plugin_smoke_test() {
    # `claude plugin details <name>` returns the component inventory.
    # If install succeeded but the plugin is corrupt / has no SKILL.md /
    # has no components, this either errors or returns an empty inventory.
    # Either fails the smoke test.
    local plugin_at_market=$1
    local name="${plugin_at_market%@*}"
    local out
    out=$("$CLAUDE_BIN" plugin details "$name" 2>&1) || {
        log_error "smoke: 'claude plugin details $name' exited non-zero"
        printf '%s\n' "$out" >&2
        return 1
    }
    # The inventory line "Skills (N) ..." / "Agents (N) ..." / "Hooks (N) ..."
    # is present. If all three are zero, that's a hollow plugin.
    if printf '%s' "$out" | grep -Eq 'Skills \(0\).*Agents \(0\).*Hooks \(0\).*MCP servers \(0\)'; then
        log_error "smoke: $name installed but has zero components — likely manifest issue"
        return 1
    fi
    return 0
}

# Plugins that PASSED smoke tests in this run. Tier-2 dedupe (step 4) only
# removes raw copies whose corresponding plugin is in this set.
declare -A SMOKE_PASSED=()

step_install_plugins() {
    log_step "3. Install + smoke-test plugins"
    [ -r "$PLUGINS_FILE" ] || die "plugins.txt not found: $PLUGINS_FILE"

    local line plugin_at_market
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(printf '%s' "$line" | tr -d '[:space:]')"
        [ -z "$line" ] && continue
        plugin_at_market="$line"

        local already
        if plugin_installed "$plugin_at_market"; then
            already=1
            log_skip "already installed: $plugin_at_market"
        else
            already=0
            log_info "installing: $plugin_at_market"
            if ! run "$CLAUDE_BIN" plugin install "$plugin_at_market"; then
                log_error "install failed: $plugin_at_market"
                die "halting before any Tier-2 removal. Re-run after fixing the install."
            fi
        fi

        # Smoke test is read-only (`claude plugin details`). Safe to run for
        # any plugin that's actually installed. In dry-run mode, the install
        # was simulated — for not-yet-installed plugins, we can't smoke-test
        # so we assume the install + smoke would pass and proceed with dry
        # output for downstream steps.
        if [ "$DRY_RUN" -eq 1 ] && [ "$already" -eq 0 ]; then
            log_info "[dry-run] smoke test would run after real install"
            SMOKE_PASSED["$plugin_at_market"]=1
        elif plugin_smoke_test "$plugin_at_market"; then
            log_ok "smoke: $plugin_at_market"
            SMOKE_PASSED["$plugin_at_market"]=1
        else
            die "smoke test failed: $plugin_at_market — halting before any Tier-2 removal. Investigate the plugin (claude plugin details ${plugin_at_market%@*})."
        fi
    done < "$PLUGINS_FILE"
}

# ---------------------------------------------------------------------------
# Step 4 — remove stale Tier-2 raw copies
# ---------------------------------------------------------------------------

step_remove_stale_tier2() {
    log_step "4. Remove stale Tier-2 raw copies"
    local entry raw_name plugin_at_market raw_dir
    local skills_dir="$HOME/.claude/skills"
    for entry in "${TIER2_DEDUPE[@]}"; do
        raw_name="${entry%%|*}"
        plugin_at_market="${entry#*|}"
        raw_dir="$skills_dir/$raw_name"

        if [ ! -d "$raw_dir" ]; then
            log_skip "no Tier-2 raw copy to remove: $raw_name"
            continue
        fi
        if [ -z "${SMOKE_PASSED[$plugin_at_market]:-}" ]; then
            log_warn "Tier-1 plugin not verified ($plugin_at_market); leaving raw copy $raw_dir in place"
            continue
        fi
        log_info "removing stale Tier-2 copy: $raw_dir (Tier-1 plugin verified)"
        run rm -rf "$raw_dir"
    done
}

# ---------------------------------------------------------------------------
# Step 5 — vendored-SHA verification (best effort, warn-only)
# ---------------------------------------------------------------------------

step_verify_vendored() {
    log_step "5. Verify addyosmani-vendored SHAs (warn-only)"
    local vendored="$HOME/.claude/skills/VENDORED.md"
    if [ ! -f "$vendored" ]; then
        log_warn "no VENDORED.md at $vendored — can't verify vendored SHAs"
        return 0
    fi
    # Lightweight check: each named skill dir referenced in VENDORED.md
    # exists under ~/.claude/skills/. Real SHA-chain verification needs
    # the upstream repos cloned at the noted SHA, which is out of scope
    # for the bootstrap script (it's the operator's job at re-vendor time).
    local skill
    for skill in accessibility browser-testing-with-devtools core-web-vitals \
                 frontend-ui-engineering performance-optimization; do
        if [ ! -d "$HOME/.claude/skills/$skill" ]; then
            log_warn "vendored skill missing from ~/.claude/skills/: $skill"
        else
            log_ok "vendored skill present: $skill"
        fi
    done
}

# ---------------------------------------------------------------------------
# Step 6 — scaffold ~/.config/<tool>/env at mode 600
# ---------------------------------------------------------------------------

scaffold_one_env_file() {
    local target=$1
    local dir
    dir=$(dirname "$target")
    if [ -f "$target" ]; then
        # File exists — verify mode 600; never overwrite content.
        if [ "$(stat -c '%a' "$target" 2>/dev/null || stat -f '%Lp' "$target")" != "600" ]; then
            log_warn "$target has loose permissions; chmod 600 recommended (NOT changing automatically)"
        else
            log_skip "secrets file present + mode 600: $target"
        fi
        return 0
    fi
    log_info "scaffolding secrets file: $target (mode 600)"
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s[dry-run]%s  mkdir -p %s && create %s (chmod 600) with template\n' \
            "$DIM" "$NC" "$dir" "$target"
        return 0
    fi
    mkdir -p "$dir"
    cat > "$target" <<EOF
# $(basename "$dir") secrets — auto-source by the matching agent-tool CLI.
# Fill in values. NEVER commit this file. Mode 600.
#
# Example:
#   OPENROUTER_API_KEY=sk-or-...
#   ANTHROPIC_API_KEY=sk-ant-...
EOF
    chmod 600 "$target"
}

step_scaffold_secrets() {
    log_step "6. Scaffold ~/.config/<tool>/env (mode 600)"
    if [ "$SKIP_SECRETS" -eq 1 ]; then
        log_skip "--skip-secrets — not scaffolding"
        return 0
    fi
    local target
    for target in "${SECRET_FILES[@]}"; do
        scaffold_one_env_file "$target"
    done
}

# ---------------------------------------------------------------------------
# Step 7 — assert secrets reachable (warn-only)
# ---------------------------------------------------------------------------

step_assert_secrets_reachable() {
    log_step "7. Check secrets reachable (warn-only)"
    if [ -n "${OPENROUTER_API_KEY:-}" ] || [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        log_ok "LLM key present in env"
    elif command -v op >/dev/null 2>&1; then
        log_info "op CLI present — relying on ~/.bashrc op signin for key resolution"
    else
        log_warn "no LLM key in env AND no op CLI — tools using config-env-loading may need manual setup"
    fi
}

# ---------------------------------------------------------------------------
# Step 8 — MCP / model-routing presence (warn-only)
# ---------------------------------------------------------------------------

step_check_mcp() {
    log_step "8. MCP + model-routing config presence (warn-only)"
    local opencode_cfg="$HOME/.config/opencode/opencode.json"
    if [ -f "$opencode_cfg" ]; then
        log_ok "opencode config: $opencode_cfg"
    else
        log_warn "no opencode config at $opencode_cfg — /oc slash command won't work"
    fi
}

# ---------------------------------------------------------------------------
# Step 9 — per-repo skill-creator dedupe
# ---------------------------------------------------------------------------

step_activate_plugin_commands() {
    log_step "8.5. Activate plugin-provided slash commands (mv raw → .pre-plugin.bak)"
    local entry raw_name plugin_at_market raw_path bak_path bak_ts
    local commands_dir="$HOME/.claude/commands"
    bak_ts=$(date +%Y%m%dT%H%M%S)
    local activated=0
    for entry in "${COMMAND_ACTIVATION[@]}"; do
        raw_name="${entry%%|*}"
        plugin_at_market="${entry#*|}"
        raw_path="$commands_dir/$raw_name"

        if [ -z "${SMOKE_PASSED[$plugin_at_market]:-}" ]; then
            log_warn "Tier-1 plugin not verified ($plugin_at_market); leaving raw command $raw_path in place"
            continue
        fi
        if [ ! -f "$raw_path" ]; then
            log_skip "no raw command to activate over: $raw_path"
            continue
        fi
        bak_path="${raw_path}.pre-plugin.bak.${bak_ts}"
        log_info "activating plugin command: $raw_path → $(basename "$bak_path")"
        run mv "$raw_path" "$bak_path"
        activated=$((activated + 1))
    done
    if [ "$activated" -gt 0 ]; then
        log_info "$activated raw command file(s) backed up; plugin versions are now live"
        log_info "  → verify each plugin command in a Claude Code session (/check, /db, /oc)"
        log_info "  → once verified, delete the *.pre-plugin.bak.* backups manually"
    fi
}

step_dedupe_per_repo() {
    log_step "9. Dedupe per-repo skill-creator (defers to user-level Tier-1)"
    # Only dedupe if the Tier-1 plugin verified — same guard as step 4.
    if [ -z "${SMOKE_PASSED[skill-creator@claude-plugins-official]:-}" ]; then
        log_warn "skill-creator plugin not verified; leaving per-repo copies alone"
        return 0
    fi
    local path
    for path in "${PER_REPO_DUPES[@]}"; do
        if [ ! -d "$path" ]; then
            log_skip "no per-repo copy: $path"
            continue
        fi
        log_info "removing per-repo duplicate: $path"
        run rm -rf "$path"
    done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    printf '%sseed-claude-skills.sh%s — PatientVibes Claude Code standard layout\n' "$BLUE" "$NC"
    [ "$DRY_RUN" -eq 1 ] && printf '%sDRY RUN — nothing will be modified%s\n' "$YELLOW" "$NC"
    [ "$STRICT" -eq 1 ]  && printf '%sSTRICT — warnings will fail the run%s\n' "$YELLOW" "$NC"

    step_locate_claude
    step_register_marketplaces
    step_install_plugins
    step_remove_stale_tier2
    step_verify_vendored
    step_scaffold_secrets
    step_assert_secrets_reachable
    step_check_mcp
    step_activate_plugin_commands
    step_dedupe_per_repo

    printf '\n'
    if [ "$WARNINGS" -gt 0 ]; then
        log_warn "$WARNINGS warning(s) fired during this run"
        if [ "$STRICT" -eq 1 ]; then
            die "--strict: exiting non-zero due to warnings"
        fi
    fi
    log_ok "Done."
}

main "$@"
