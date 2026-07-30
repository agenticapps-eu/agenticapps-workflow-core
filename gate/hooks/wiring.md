# Wiring the gate per agent (all point at the ONE script)

Install the script globally once, then wire each surface to call it.

```bash
mkdir -p ~/.agenticapps/bin
install -m 0755 gate/openspec-change-gate.sh ~/.agenticapps/bin/
# run-plan-review.sh ships from reference-implementations/run-plan-review/
```

## Claude Code — `.claude/settings.json`
```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write|NotebookEdit",
        "hooks": [ { "type": "command",
                     "command": "$HOME/.agenticapps/bin/openspec-change-gate.sh" } ] }
    ]
  }
}
```

## Codex — `.codex/hooks.json`
```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "apply_patch",
        "hooks": [ { "type": "command",
                     "command": "$HOME/.agenticapps/bin/openspec-change-gate.sh" } ] }
    ]
  }
}
```
(Codex reads the payload on stdin; the script parses `file_path`/`path` either way.)

## opencode — UNCONFIRMED
opencode exposes a plugin/hook system via `opencode.json`; the exact PreToolUse-equivalent
event name and payload are not yet verified. **Verify during the opencode host step**, then
point it at the same script. Until confirmed, rely on the **pre-commit + CI** floor below —
that already enforces opencode's edits.

## pi — UNCONFIRMED
pi (`badlogic/pi`) reads AGENTS.md + SKILL.md; its runtime hook surface is not yet verified.
Same posture: confirm the hook event during the pi host step; the pre-commit + CI floor
enforces pi in the meantime.

## The agent-agnostic floor (do this first, it covers every agent AND humans)
```bash
# per repo:
cp gate/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
cp gate/hooks/openspec-gate.ci.yml .github/workflows/openspec-gate.yml
```
The per-agent PreToolUse hooks are faster feedback on top; the pre-commit + CI checks are
the reliable guarantee (a PreToolUse hook can't even gate its own installing session).
