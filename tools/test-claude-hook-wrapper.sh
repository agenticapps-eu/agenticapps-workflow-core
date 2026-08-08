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
#   - arguments are forwarded to the gate, so `--ci` is not silently discarded
#   - the registration quotes the command and matches the edit tools
#
# Usage: bash tools/test-claude-hook-wrapper.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WRAPPER="$ROOT/.claude/hooks/openspec-change-gate.sh"
SETTINGS="$ROOT/.claude/settings.json"
[ -x "$WRAPPER" ] || { printf 'missing or non-executable: %s\n' "$WRAPPER" >&2; exit 1; }
# SETTINGS is no longer required to exist. Core registers no PreToolUse hook, so
# an absent settings file is the expected state and a present one is checked for
# what it must NOT contain.

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

# Fails OPEN AND REPORTS: the root resolved, the gate genuinely is not installed
# there. Exercised by copying the wrapper into a project-shaped tree with no gate.
#
# EXIT 1, NOT 0, since shim-contract 1.2.0. Fail-open means the edit proceeds —
# which exit 1 does, because 1 is non-blocking; only 2 blocks. It does not mean
# exit 0, and this assertion required 0 for as long as the wrapper printed a
# warning the operator could never read: a PreToolUse hook exiting 0 has its
# stderr discarded from the transcript. Asserting 0 here is what kept that
# defect in place.
mkdir -p "$WORK/emptyproj/.claude/hooks"
cp "$WRAPPER" "$WORK/emptyproj/.claude/hooks/"
absent_rc="$( cd "$OUTSIDE" && printf '{}' | env -u OPENSPEC_GATE -u CLAUDE_PROJECT_DIR \
        bash "$WORK/emptyproj/.claude/hooks/openspec-change-gate.sh" >/dev/null 2>"$WORK/absent-err.txt"; echo $?; )"
check "genuinely absent gate fails open, non-blocking (1)" 1 "$absent_rc"
if [ -s "$WORK/absent-err.txt" ]; then
  check "genuinely absent gate reports before exiting" 0 0
else
  check "genuinely absent gate reports before exiting" 0 1
fi

# An explicit override names the gate outright, so root resolution is moot.
mkgate 2
check "OPENSPEC_GATE override wins over an unresolvable root" 2 \
  "$(runw CLAUDE_PROJECT_DIR="$WORK/no/such/dir" OPENSPEC_GATE="$WORK/gate.sh")"

# REGRESSION: the wrapper ended in `exec "$GATE"` and dropped "$@", so every
# argument was discarded on the way to the gate. PreToolUse passes none and CI
# invokes the gate directly, so nothing was ungated by this — but
# `bash .claude/hooks/openspec-change-gate.sh --ci` reached the gate as a hook
# invocation with no payload and exited 0 in silence, reporting nothing about
# the changes it was asked to check. A green that checked nothing is the one
# result a gate may not return, and it is the same class of defect as a
# conformance harness that scores an artifact it never runs.
#
# EXIT STATUS CANNOT JUDGE THIS EITHER: both wrappers exit 0. The assertion is
# what the gate RECEIVED, so the stand-in records its own arguments. Two are
# passed, because forwarding "$1" alone would satisfy a single-argument case.
cat > "$WORK/gate.sh" <<EOF
#!/bin/sh
printf '%s|' "\$@" > "$WORK/args.txt"
exit 0
EOF
chmod +x "$WORK/gate.sh"
rm -f "$WORK/args.txt"
( cd "$OUTSIDE" && printf '{}' | env -u CLAUDE_PROJECT_DIR OPENSPEC_GATE="$WORK/gate.sh" \
    bash "$WRAPPER" --ci second-arg >/dev/null 2>&1 )
x=0; [ "$(cat "$WORK/args.txt" 2>/dev/null)" = "--ci|second-arg|" ] || x=1
check "wrapper forwards its arguments to the gate" 0 "$x"

x=0; grep -q 'OPENSPEC_GATE_SELF=' "$WRAPPER" && x=1
check "wrapper exports no dead OPENSPEC_GATE_SELF" 0 "$x"

printf "core's interposition points\n"

# WHAT CHANGED HERE, AND WHY THE ASSERTION IS INVERTED
#
# This section used to check that the PreToolUse registration was well formed —
# quoted command, matcher covering the four edit tools. The registration is
# gone: core-self-enforcement is amended to two points core owns, `pre-commit`
# and CI, with the machine-level floor for everything else. A per-host session
# hook cannot gate the session that installs it and does not exist for a human
# with an editor, which is why it went fleet-wide, and a core-only carve-out
# would have exempted the one repository that should be first under the floor.
#
# So the assertion is now that core registers NO PreToolUse hook against the
# gate. The requirement's own scenario says a hook found here is reported as a
# surface the capability no longer requires — never as satisfying part of it.
if [ ! -f "$SETTINGS" ]; then
  check "core registers no PreToolUse hook against the gate" 0 0
elif command -v python3 >/dev/null 2>&1; then
  x="$(python3 - "$SETTINGS" <<'PY'
import json,sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(1); raise SystemExit
for e in d.get("hooks", {}).get("PreToolUse", []):
    for h in e.get("hooks", []):
        if "openspec-change-gate" in h.get("command", ""):
            print(1); raise SystemExit
print(0)
PY
)"
  check "core registers no PreToolUse hook against the gate" 0 "${x:-1}"
else
  printf '  SKIP registration check (no python3)\n'
fi

# The wrapper itself STAYS, and this is the difference between a leftover and a
# decision. It is core's own instance of the project-hook shim contract — two
# suites read it as that, and `project-hook-binding` says in as many words that
# a copy documenting IN-FILE that it is intentionally unregistered has that
# decision preserved rather than reconciled away. A file that is merely
# unregistered is drift; one that says why is the variant the capability
# describes.
x=0; grep -qi 'deliberately unregistered\|intentionally unregistered' "$WRAPPER" || x=1
check "the wrapper documents in-file that it is deliberately unregistered" 0 "$x"

# The two that remain carry what the third used to. Asserted here because this
# is the moment they stop being defence in depth and become the whole defence.
x=0
grep -q '^on:' "$ROOT/.github/workflows/openspec-gate.yml" 2>/dev/null || x=1
grep -q 'pull_request' "$ROOT/.github/workflows/openspec-gate.yml" 2>/dev/null || x=1
grep -qE 'branches: \[ ?main' "$ROOT/.github/workflows/openspec-gate.yml" 2>/dev/null || x=1
grep -q -- '--ci' "$ROOT/.github/workflows/openspec-gate.yml" 2>/dev/null || x=1
check "CI runs the gate on pull requests and on pushes to main" 0 "$x"

# "Provides and registers", not "runs": the hook is written by an installer and
# is absent until that installer is run, so the obligation is on the installer
# existing, which is what core controls.
x=0; [ -x "$ROOT/tools/install-core-git-hooks.sh" ] || x=1
check "an installer exists that writes core's pre-commit hook" 0 "$x"

printf '\nTOTAL: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -ne 0 ]; then printf 'failed:%s\n' "$failed_names" >&2; exit 1; fi
exit 0
