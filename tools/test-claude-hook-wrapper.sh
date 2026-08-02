#!/usr/bin/env bash
# tools/test-claude-hook-wrapper.sh — behavioural tests for the PreToolUse
# wrapper at .claude/hooks/openspec-change-gate.sh and its registration.
#
# WHY THIS EXISTS. The conformance harness scores the GATE; the installer suite
# covers the commit hook. Neither executes the wrapper, which is the
# interposition point that runs on EVERY edit — and its two defects were both
# silent ungating, the one failure mode a gate may not have. It reported an
# ungated edit whenever the session's working directory moved outside the
# repository, and its registration was unquoted shell form, so a repository path
# containing a space would fail to exec with 127 — not 2, so the edit proceeded.
#
# The wrapper's contract, in the order it is tested:
#   - exit 2 from the gate propagates as exit 2 (BLOCK)
#   - exit 0 from the gate propagates as exit 0 (ALLOW)
#   - both hold from a working directory outside the repository
#   - an unresolvable project root fails CLOSED (exit 2) — not knowing where to
#     look is a defect, distinct from tooling being genuinely absent
#   - a genuinely absent gate fails OPEN (exit 0) with a warning
#   - the registration quotes the command and matches the edit tools
#
# Usage: bash tools/test-claude-hook-wrapper.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WRAPPER="$ROOT/.claude/hooks/openspec-change-gate.sh"
SETTINGS="$ROOT/.claude/settings.json"
[ -x "$WRAPPER" ] || { printf 'missing or non-executable: %s\n' "$WRAPPER" >&2; exit 1; }
[ -f "$SETTINGS" ] || { printf 'missing: %s\n' "$SETTINGS" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/wrapper-test.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
OUTSIDE="$WORK/outside"; mkdir -p "$OUTSIDE" || exit 1

pass=0; fail=0; failed_names=""
ok(){  pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad(){ fail=$((fail+1)); failed_names="$failed_names
    - $1: $2"; printf '  FAIL %s — %s\n' "$1" "$2"; }
check(){ [ "$3" = "$2" ] && ok "$1" || bad "$1" "exit $3, want $2"; }

# A stand-in gate, so the wrapper's propagation is tested rather than the real
# gate's verdict — which depends on whatever changes happen to be open.
mkgate(){ printf '#!/bin/sh\nexit %s\n' "$1" > "$WORK/gate.sh"; chmod +x "$WORK/gate.sh"; }

# Always from OUTSIDE the repository: the cwd-derived-root defect passed every
# test run from inside it, which is why it shipped.
runw(){ ( cd "$OUTSIDE" && printf '{}' | env "$@" bash "$WRAPPER" >/dev/null 2>&1; echo $?; ); }

printf 'wrapper behaviour\n'

mkgate 2
check "gate BLOCK (2) propagates from a foreign cwd" 2 \
  "$(runw CLAUDE_PROJECT_DIR="$ROOT" OPENSPEC_GATE="$WORK/gate.sh")"

mkgate 0
check "gate ALLOW (0) propagates from a foreign cwd" 0 \
  "$(runw CLAUDE_PROJECT_DIR="$ROOT" OPENSPEC_GATE="$WORK/gate.sh")"

# REGRESSION: the root came from the working directory, so this reported an
# ungated edit. With no CLAUDE_PROJECT_DIR the wrapper must fall back to its own
# location and still find the real in-tree gate.
#
# EXIT STATUS ALONE CANNOT JUDGE THIS. The broken wrapper also exited 0 here —
# by failing open — so an exit-code assertion passed against the very bug the
# case is named for. What distinguishes them is whether the gate was FOUND, so
# the warning is the assertion: its presence means resolution failed.
( cd "$OUTSIDE" && printf '{}' | env -u CLAUDE_PROJECT_DIR -u OPENSPEC_GATE \
    bash "$WRAPPER" >/dev/null 2>"$WORK/err.txt" ); r=$?
if grep -q 'gate not found' "$WORK/err.txt" 2>/dev/null; then
  bad "resolves the in-tree gate with no CLAUDE_PROJECT_DIR" "fell open: $(tr -d '\n' < "$WORK/err.txt")"
else
  check "resolves the in-tree gate with no CLAUDE_PROJECT_DIR" 0 "$r"
fi

# NOTE the `-u` flags come FIRST: env stops parsing options at the first
# NAME=VALUE, so `env FOO=1 -u BAR cmd` runs `-u` as the command and exits 127.
# Written the other way round, these cases exited 127 and the suite caught it.

# The fail-CLOSED guard on an unresolvable root is retained as defence in depth,
# but it is no longer reachable by any input a test can supply: the root is now
# derived from the wrapper's own location, which resolves whenever the wrapper
# is able to run at all. Asserting the guard is PRESENT is honest; asserting it
# fires would need a fabricated case that cannot occur.
x=0; grep -q 'exit 2' "$WRAPPER" || x=1
check "fail-closed guard on an unresolvable root is present" 0 "$x"

# REGRESSION: a STALE BUT EXISTING CLAUDE_PROJECT_DIR passed the is-a-directory
# check, resolved to a gate that was not there, and reported an ungated edit for
# a repository whose gate sits beside the wrapper. The variable is no longer
# consulted, so pointing it at a real but wrong directory must change nothing.
( cd "$OUTSIDE" && printf '{}' | env -u OPENSPEC_GATE CLAUDE_PROJECT_DIR="$WORK" \
    bash "$WRAPPER" >/dev/null 2>"$WORK/err.txt" ); r=$?
if grep -q 'gate not found' "$WORK/err.txt" 2>/dev/null; then
  bad "a stale CLAUDE_PROJECT_DIR does not ungate" "fell open: $(tr -d '\n' < "$WORK/err.txt")"
else
  check "a stale CLAUDE_PROJECT_DIR does not ungate" 0 "$r"
fi

# Fails OPEN: the root resolved, the gate genuinely is not installed there.
# Exercised by copying the wrapper into a project-shaped tree with no gate.
mkdir -p "$WORK/emptyproj/.claude/hooks"
cp "$WRAPPER" "$WORK/emptyproj/.claude/hooks/"
check "genuinely absent gate fails open (0)" 0 \
  "$( cd "$OUTSIDE" && printf '{}' | env -u OPENSPEC_GATE -u CLAUDE_PROJECT_DIR \
        bash "$WORK/emptyproj/.claude/hooks/openspec-change-gate.sh" >/dev/null 2>&1; echo $?; )"

# An explicit override names the gate outright, so root resolution is moot.
mkgate 2
check "OPENSPEC_GATE override wins over an unresolvable root" 2 \
  "$(runw CLAUDE_PROJECT_DIR="$WORK/no/such/dir" OPENSPEC_GATE="$WORK/gate.sh")"

x=0; grep -q 'OPENSPEC_GATE_SELF=' "$WRAPPER" && x=1
check "wrapper exports no dead OPENSPEC_GATE_SELF" 0 "$x"

printf 'registration\n'
if command -v python3 >/dev/null 2>&1; then
  # REGRESSION: unquoted shell form. A repository path containing a space made
  # the shell exec the wrong binary and exit 127 — which is not 2, so Claude
  # treated it as non-blocking and the edit went through ungated.
  reg="$(python3 - "$SETTINGS" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
e=d["hooks"]["PreToolUse"][0]
c=e["hooks"][0]["command"]
print("QUOTED" if c.startswith('"') and c.endswith('"') else "UNQUOTED")
print(e["matcher"])
PY
)" || reg=""
  q="$(printf '%s' "$reg" | sed -n 1p)"; m="$(printf '%s' "$reg" | sed -n 2p)"
  x=0; [ "$q" = "QUOTED" ] || x=1
  check "hook command is quoted for paths with spaces" 0 "$x"
  x=0
  for t in Edit Write MultiEdit NotebookEdit; do
    printf '%s' "$m" | grep -q "$t" || x=1
  done
  check "matcher covers the edit tools" 0 "$x"
else
  printf '  SKIP registration checks (no python3)\n'
fi

printf '\nTOTAL: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -ne 0 ]; then printf 'failed:%s\n' "$failed_names" >&2; exit 1; fi
exit 0
