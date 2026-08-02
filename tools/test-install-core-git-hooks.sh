#!/usr/bin/env bash
# tools/test-install-core-git-hooks.sh — behavioural tests for the hook installer.
#
# WHY THIS EXISTS. The change-gate conformance harness scores the GATE artifact.
# It does not execute this repository's PreToolUse wrapper or its hook
# installer, so CI reported 71/71 green while the installer carried seven real
# defects — four of which wrote a file into the working tree, or destroyed a
# hook it did not own, and exited 0 calling it success. A green board through
# seven live bugs is the signal that the board was measuring the wrong thing.
#
# Every case below is a REGRESSION TEST for a defect that was actually
# reproduced on this branch, not a hypothetical. Sources: CodeRabbit on PR #56
# (tracking-status containment), the §07 Stage-2 review (gemini: existence
# containment; codex: symlink, substring marker, atomic write, cwd resolution).
#
# The scratch repositories are cloned into a directory whose name contains a
# space, a `[` and a `*`, because unquoted-path defects are exactly the class
# that passes every test run under a tidy path.
#
# Usage: bash tools/test-install-core-git-hooks.sh
# Exit 0 = all cases pass. Exit 1 = at least one failed (names are printed).
set -uo pipefail

INSTALLER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/install-core-git-hooks.sh"
[ -x "$INSTALLER" ] || { printf 'missing or non-executable: %s\n' "$INSTALLER" >&2; exit 1; }
SRC="$(cd "$(dirname "$INSTALLER")/.." && pwd -P)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/install-hooks-test.XXXXXX")" || exit 1
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
BASE="$WORK/we ird [x]*dir"
mkdir -p "$BASE" || exit 1

pass=0; fail=0; failed_names=""
ok(){   pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad(){  fail=$((fail+1)); failed_names="$failed_names
    - $1: $2"; printf '  FAIL %s — %s\n' "$1" "$2"; }
check(){ # name expected_exit actual_exit extra_desc extra_ok(0/1)
  if [ "$3" != "$2" ]; then bad "$1" "exit $3, want $2"; return; fi
  if [ "${5:-0}" != "0" ]; then bad "$1" "$4"; return; fi
  ok "$1"
}

# A fresh clone per case: state must never leak between them.
fresh_repo(){
  local d="$BASE/$1"
  rm -rf "$d"
  git clone -q --no-local "$SRC" "$d" 2>/dev/null || return 1
  # Test the installer as it exists in the WORKING TREE, not as committed —
  # otherwise a fix under review is not what is being tested.
  cp "$INSTALLER" "$d/tools/install-core-git-hooks.sh" || return 1
  printf '%s' "$d"
}

MARKER='# managed-by: agenticapps-workflow-core tools/install-core-git-hooks.sh'

printf 'installer behaviour\n'

# --- ordinary lifecycle -----------------------------------------------------
d="$(fresh_repo lifecycle)" || exit 1
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -x "$d/.git/hooks/pre-commit" ] || x=1
check "fresh install (path with space, [ and *)" 0 "$r" "hook not executable" "$x"

( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
check "second run is a no-op" 0 "$r"

( cd "$d" && sed -i.bak '$d' .git/hooks/pre-commit && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; grep -qxF "$MARKER" "$d/.git/hooks/pre-commit" || x=1
check "stale marked hook is upgraded" 0 "$r" "marker missing after upgrade" "$x"

chmod -x "$d/.git/hooks/pre-commit"
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -x "$d/.git/hooks/pre-commit" ] || x=1
check "lost execute bit is repaired" 0 "$r" "still not executable" "$x"

# --- ownership --------------------------------------------------------------
d="$(fresh_repo foreign)" || exit 1
printf '#!/bin/sh\nexit 9\n' > "$d/.git/hooks/pre-commit"; chmod +x "$d/.git/hooks/pre-commit"
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; grep -q "exit 9" "$d/.git/hooks/pre-commit" || x=1
check "unmarked foreign hook is refused" 1 "$r" "foreign hook was destroyed" "$x"

# REGRESSION: `grep -qF` matched the marker as a substring anywhere in the file,
# so a hook merely MENTIONING it was claimed and overwritten.
d="$(fresh_repo substring)" || exit 1
printf '#!/bin/sh\necho "%s is only documentation"\nexit 42\n' "$MARKER" > "$d/.git/hooks/pre-commit"
chmod +x "$d/.git/hooks/pre-commit"
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; grep -q "exit 42" "$d/.git/hooks/pre-commit" || x=1
check "marker as substring does not claim ownership" 1 "$r" "foreign hook was destroyed" "$x"

# REGRESSION: -e is false for a dangling symlink, so the installer took the
# "nothing here" branch and the redirect followed the link into the worktree.
d="$(fresh_repo symlink)" || exit 1
ln -sf "$d/created-in-worktree" "$d/.git/hooks/pre-commit"
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -e "$d/created-in-worktree" ] && x=1
check "dangling symlink is refused, not followed" 1 "$r" "wrote through symlink into worktree" "$x"

# --- containment ------------------------------------------------------------
# SETUP IS NOT THE MEASUREMENT. Folding `mkdir`/`git config` into the same
# subshell as the installer makes a failed SETUP indistinguishable from a
# correct refusal: `r` is non-zero either way, and "no hook was written" is
# equally true when the installer never ran. Setup aborts the suite; only the
# installer's own status reaches `r`.
setup(){ ( cd "$1" && shift && "$@" ) || { printf 'SETUP FAILED in %s: %s\n' "$1" "$*" >&2; exit 1; }; }

d="$(fresh_repo intree_exists)" || exit 1
setup "$d" mkdir -p .githooks
setup "$d" git config core.hooksPath .githooks
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -e "$d/.githooks/pre-commit" ] && x=1
check "in-tree hooksPath (existing) is refused" 1 "$r" "wrote into worktree" "$x"

# REGRESSION: canonicalisation could not resolve an absent path and the
# single-level parent fallback failed too, yielding a path outside the tree.
d="$(fresh_repo intree_missing)" || exit 1
setup "$d" git config core.hooksPath .githooks/missing/hooks
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -e "$d/.githooks/missing/hooks/pre-commit" ] && x=1
check "in-tree hooksPath (deep-missing) is refused" 1 "$r" "wrote into worktree" "$x"

# REGRESSION: the re-appended components were concatenated without normalising
# `..`, so a path that LOOKS outside the tree and resolves back into it was
# accepted — mkdir -p then created the absent segment and the hook landed in the
# working tree at exit 0. The outward-and-back direction is the dangerous one.
# The path must start OUTSIDE the root TEXTUALLY, or the naive prefix test
# refuses it for the wrong reason and the case proves nothing — which is what
# an earlier draft of this test did, passing against the very bug it names.
# Hence a sibling of the repo, not a child of it.
d="$(fresh_repo dotdot_back_in)" || exit 1
setup "$d" git config core.hooksPath "$BASE/absent/../dotdot_back_in/.githooks"
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -e "$d/.githooks/pre-commit" ] && x=1
check "hooksPath escaping via .. back into the tree is refused" 1 "$r" "wrote into worktree" "$x"

# The same normalisation must not over-refuse: a `..` path that genuinely
# resolves OUTSIDE the tree still installs, at the normalised location.
d="$(fresh_repo dotdot_outside)" || exit 1
setup "$d" git config core.hooksPath "$WORK/absent-sibling/../landing/hooks"
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -x "$WORK/landing/hooks/pre-commit" ] || x=1
check "hooksPath with .. resolving outside still installs" 0 "$r" "not installed at the normalised path" "$x"

d="$(fresh_repo outside_missing)" || exit 1
out="$WORK/outside/a/b"
setup "$d" git config core.hooksPath "$out"
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -x "$out/pre-commit" ] || x=1
check "outside-tree hooksPath (deep-missing) installs" 0 "$r" "hook missing or not executable" "$x"

# --- worktrees --------------------------------------------------------------
# The case that would have shipped broken: `.git` is a FILE in a linked
# worktree, so a literal .git/hooks/ path does not exist there.
d="$(fresh_repo worktree)" || exit 1
wt="$WORK/linked-wt"
( cd "$d" && git worktree add -q "$wt" -b wtb >/dev/null 2>&1 )
( cd "$wt" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
x=0; [ -x "$d/.git/hooks/pre-commit" ] || x=1
check "linked worktree installs into main checkout" 0 "$r" "hook not in main checkout" "$x"

# --- generated hook ---------------------------------------------------------
# The gate has IGNORED OPENSPEC_GATE_SELF since 1.5.0; exporting it while
# claiming it excludes a host's own reviews is the hazard the gate names.
d="$(fresh_repo generated)" || exit 1
( cd "$d" && bash tools/install-core-git-hooks.sh >/dev/null 2>&1 ); r=$?
# Assert the hook EXISTS before grepping it. Passing a hardcoded 0 and grepping
# a file that may not be there made this case green whenever the installer had
# silently done nothing — absence of a bad string is not evidence.
x=0; [ -f "$d/.git/hooks/pre-commit" ] || x=1
check "generated hook is written" 0 "$r" "no hook to inspect" "$x"
x=0; grep -q "OPENSPEC_GATE_SELF=" "$d/.git/hooks/pre-commit" 2>/dev/null && x=1
check "generated hook exports no dead OPENSPEC_GATE_SELF" 0 "$r" "dead export present" "$x"

x=0; ( cd "$d" && OPENSPEC_GATE=/nonexistent/gate .git/hooks/pre-commit >/dev/null 2>&1 ) || x=$?
check "generated hook fails OPEN on a missing gate" 0 "$x"

printf '\nTOTAL: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -ne 0 ]; then printf 'failed:%s\n' "$failed_names" >&2; exit 1; fi
exit 0
