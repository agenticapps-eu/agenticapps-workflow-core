#!/usr/bin/env bash
# project-hooks.test.sh — behaviour matrix for the canonical project-hook
# implementations in reference-implementations/project-hooks/.
#
# Drives each implementation through its public interface (a tool payload on
# stdin) and asserts the exit code. No network, no writes outside a temp dir.
#
# This file covers the IMPLEMENTATIONS. The shims are covered separately by
# tools/project-hook-shim.test.sh, which is written test-first per the change's
# tdd="true" tasks; these implementations were reconciled from existing project
# copies (change tasks 1.2–1.9, none marked tdd), so this matrix is a
# regression fence around a reconciliation, not a TDD cycle.
#
# Usage: tools/project-hooks.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SENTINEL="$ROOT/reference-implementations/project-hooks/database-sentinel.sh"

pass=0
fail=0

# $1=payload JSON  $2=expected exit code  $3=description
assert_exit() {
  local out rc
  out=$(printf '%s' "$1" | "$SENTINEL" 2>&1)
  rc=$?
  if [ "$rc" -eq "$2" ]; then
    echo "  PASS  $3"
    pass=$((pass + 1))
  else
    echo "  FAIL  $3"
    echo "        expected exit $2, got $rc"
    [ -n "$out" ] && echo "        output: $(printf '%s' "$out" | head -1)"
    fail=$((fail + 1))
  fi
}

# Build payloads with jq so a quote inside a SQL string cannot produce a
# malformed fixture that the hook rejects for the wrong reason.
edit()  { jq -nc --arg t "${2:-Edit}" --arg f "$1" '{tool_name:$t,tool_input:{file_path:$f}}'; }
bash_() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }

echo "database-sentinel — Bash arm (task 1.6: the SQL protections are unchanged)"
assert_exit "$(bash_ 'psql -c "DROP TABLE users"')"        2 "DROP TABLE blocked"
assert_exit "$(bash_ 'psql -c "drop   table users"')"      2 "DROP TABLE blocked (case/space insensitive)"
assert_exit "$(bash_ 'psql -c "TRUNCATE TABLE sessions"')" 2 "TRUNCATE TABLE blocked"
assert_exit "$(bash_ 'psql -c "DELETE FROM users;"')"      2 "DELETE FROM without WHERE blocked"
assert_exit "$(bash_ 'psql -c "DELETE FROM users WHERE id=1;"')" 0 "DELETE FROM with WHERE allowed"
assert_exit "$(bash_ 'ls -la')"                            0 "ordinary Bash allowed"

echo
echo "database-sentinel — .env arm (task 1.7: the wildcard is a strict superset)"
# Every path the five enumerated copies blocked must still block.
for p in .env .env.local .env.production .env.staging .env.development \
         apps/api/.env apps/api/.env.local apps/api/.env.production \
         apps/api/.env.staging apps/api/.env.development; do
  assert_exit "$(edit "$p")" 2 "blocked (was enumerated): $p"
done
# The novel suffixes the enumeration missed — the reason for the wildcard.
for p in .env.test .env.ci .env.preview apps/web/.env.vercel; do
  assert_exit "$(edit "$p")" 2 "blocked (novel suffix, newly covered): $p"
done
# The allowance the wildcard requires, to keep parity with the enumerated copies.
for p in .env.example .env.template apps/api/.env.example apps/api/.env.template; do
  assert_exit "$(edit "$p")" 0 "allowed (example/template): $p"
done
assert_exit "$(edit 'src/index.ts')" 0 "ordinary source file allowed"

echo
echo "database-sentinel — tool coverage (task 1.3a difference 2)"
assert_exit "$(edit .env Edit)"      2 "Edit covered"
assert_exit "$(edit .env Write)"     2 "Write covered"
assert_exit "$(edit .env MultiEdit)" 2 "MultiEdit covered"
assert_exit "$(edit .env Read)"      0 "Read not covered (out of matcher scope)"

echo
echo "database-sentinel — migrations arm is GONE (tasks 1.4, 1.5)"
# All seven project copies blocked these unless a sentinel no surviving command
# writes was present. Six of seven had no such sentinel.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
( cd "$tmp" || exit 1
  assert_exit "$(edit 'migrations/001_init.sql')"       0 "migrations/ edit allowed with no sentinel present"
  assert_exit "$(edit 'db/migrations/002_add.sql')"     0 "*/migrations/ edit allowed with no sentinel present"
) || true
# Re-run in-tree too: the arm is deleted, so CWD must not matter at all.
assert_exit "$(edit 'migrations/001_init.sql')" 0 "migrations/ edit allowed regardless of CWD"

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
