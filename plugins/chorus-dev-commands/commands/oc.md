---
description: Delegate a task to opencode (OpenRouter-backed, cheaper) instead of handling it in this conversation
argument-hint: [--agent <name>] <task description>
---

Delegate the following task to opencode via Bash. Do **not** do the task yourself.

Task: $ARGUMENTS

## Steps

1. **Pick an agent.** If the user passed `--agent <name>` in the arguments, use that. Otherwise pick from `~/.config/opencode/opencode.json` based on the task shape:
   - `cheap` — DeepSeek V3.2 ($0.25/$0.38). Bulk mechanical edits, codemods, sweeps, "do this same thing 30 times"
   - `build` — Kimi K2.6 (default). General agentic coding, multi-file changes, when in doubt
   - `qwen` — Open Qwen3-Coder 480B (federated, flat pricing). Code-tuned, alternative to Kimi
   - `frontier` — DeepSeek V4 Pro. Hard reasoning, the "would otherwise want Opus" tier
   - `minimax` — MiniMax M2.7. Zen-curated cheap default

2. **Choose the working directory.** opencode operates on `cwd`. If the task targets a specific chorus repo, `cd` into it first; otherwise stay where you are. State the directory you picked.

3. **Run it.** Invoke:
   ```bash
   opencode run --agent <agent> "<task as a self-contained prompt>"
   ```
   Make the prompt self-contained — opencode does not see this conversation. Include any file paths, constraints, or context it needs.

4. **Report back.** Show the user opencode's output and a one-line summary. If opencode wrote files, list which files changed (`git status --short`). Do not do follow-up edits yourself — hand control back so the user can review and decide.

5. **If it fails or produces clearly wrong output**, say so plainly. Do not silently retry with a different model or fall back to doing it yourself unless the user asks.
