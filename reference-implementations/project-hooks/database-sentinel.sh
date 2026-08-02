#!/usr/bin/env bash
# database-sentinel — best-effort defence in depth at the tool-call boundary.
#
# database-sentinel-version: 1.0.0
#
# THIS IS THE CANONICAL IMPLEMENTATION. Projects bind it through a shim; see
# ./README.md for the shim contract and ./shim-template.sh for the shim itself.
# Editing a project's copy edits nothing — the copy is a shim that `exec`s this.
#
# Fires on PreToolUse matcher: Bash|Edit|Write|MultiEdit
# Reads the tool payload from stdin (JSON).
# Exit 2 = BLOCK, with the stderr message routed back to the agent.
# Exit 0 = ALLOW.
#
# Latency budget: sub-100ms. Regex only; no DB calls, no network.
#
# WHAT THIS IS NOT: a security boundary. See "Coverage boundary" in README.md.
# In short — Bash can write .env directly without presenting a file_path, and
# indirection such as `psql -f script.sql` never presents the SQL to the regex
# below. Rely on it as a speed bump, not as a control.
#
# Reconciled from three drifted project copies on 2026-08-02; the per-difference
# decisions are recorded in README.md under "Reconciliation record".

set -e

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Bash tool — block dangerous SQL.
if [ "$TOOL" = "Bash" ]; then
  # DROP TABLE, TRUNCATE TABLE, DELETE FROM <table> without WHERE.
  # Case-insensitive. Allow DELETE FROM ... WHERE ... (legitimate use).
  if echo "$COMMAND" | grep -qiE 'drop[[:space:]]+table|truncate[[:space:]]+table'; then
    echo "❌ Database Sentinel: blocked dangerous SQL DDL" >&2
    echo "   Command: $COMMAND" >&2
    echo "   Reason: matches DROP/TRUNCATE TABLE pattern" >&2
    echo "   Override: run via psql directly outside Claude Code, OR" >&2
    echo "             reference an ADR that accepts the destructive operation" >&2
    exit 2
  fi
  if echo "$COMMAND" | grep -qiE 'delete[[:space:]]+from[[:space:]]+[a-z_][a-z0-9_]*[[:space:]]*(;|$)'; then
    echo "❌ Database Sentinel: blocked DELETE without WHERE clause" >&2
    echo "   Command: $COMMAND" >&2
    echo "   Reason: deletes all rows. Add a WHERE clause or run outside Claude Code." >&2
    exit 2
  fi
fi

# Edit/Write/MultiEdit — protect sensitive paths.
#
# The .env arm is a WILDCARD (callbot's semantics), not the four-suffix
# enumeration five projects carried. A guard against secret leakage that only
# knows the suffixes someone thought of in May misses precisely the novel one.
if [ "$TOOL" = "Edit" ] || [ "$TOOL" = "Write" ] || [ "$TOOL" = "MultiEdit" ]; then
  case "$FILE" in
    *.env.example|*.env.template|*/.env.example|*/.env.template)
      # Allowed: example/template files are safe to edit.
      ;;
    .env|.env.*|*/.env|*/.env.*)
      echo "❌ Database Sentinel: blocked edit to env file" >&2
      echo "   File: $FILE" >&2
      echo "   Reason: env files contain secrets — use Infisical or similar" >&2
      echo "   Allowed: .env.example, .env.template" >&2
      exit 2
      ;;
    # NO migrations/ ARM. All seven project copies carried one that blocked
    # every migrations/ edit unless `.planning/current-phase/migrations-approved`
    # existed, and told the operator to fix it with `/gsd-discuss-phase` — a
    # command removed on 2026-07-28. Six of the seven repos lack the sentinel,
    # so the clause blocks unconditionally there. It is dropped, not carried.
    # See README.md "Reconciliation record", difference 3.
  esac
fi

exit 0
