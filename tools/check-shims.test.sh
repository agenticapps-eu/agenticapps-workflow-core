#!/usr/bin/env bash
# check-shims.test.sh — the declaration is the instrument, so an unreadable one
# must not read as a clean fleet.
#
# Covers projects-bind-not-copy task 2b.6. Written and observed RED against the
# implementation that printed the conformance sentence over an empty set.
#
# THE DEFECT THIS FIXES IS A SENTENCE, NOT A CRASH. `decl()` reads the
# declaration with `sed ... 2>/dev/null | awk 'NF'`, so a MISSING file yields
# exactly what an EMPTY file yields: nothing. The inner loop then never runs,
# `bad` stays 0, and the tool prints "Every declared hook is bound with the
# authority's bytes" and exits 0 — a conformance statement about a scan that
# examined no hooks. This change creates that condition, because removing
# `database-sentinel` and the gate's project binding leaves the set empty rather
# than shortened, so it carries the fix.
#
# The suite builds a SCRATCH CORE TREE rather than pointing the real script at a
# fake declaration through an environment variable. check-shims.sh resolves its
# declaration from its own location, and a test-only override would put a branch
# in a production script that exists for the tests and can be wrong in
# production — the seam this fleet already refused once.
#
# Usage: tools/check-shims.test.sh
#   CHECK_SHIMS_BIN=/bin/true tools/check-shims.test.sh
#     Points the suite at a deliberately wrong implementation. Every assertion
#     below MUST fail under it.
#
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REAL="${CHECK_SHIMS_BIN:-$ROOT/tools/check-shims.sh}"

pass=0
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; fail=$((fail + 1)); }
said() { printf '%s' "$OUT" | grep -qF "$1"; }

CONFORMANCE='Every declared hook is bound with the authority'

# A core-shaped tree holding a copy of the script under test, so the script
# resolves its declaration exactly as it does in production — from its own
# location — while the declaration is ours to write.
#
#   $1 = case name   $2 = declaration content, or the literal ABSENT
new_core() {
  local d="$TMP/$1"
  mkdir -p "$d/tools" "$d/reference-implementations/project-hooks"
  cp "$REAL" "$d/tools/check-shims.sh" 2>/dev/null || return 1
  chmod +x "$d/tools/check-shims.sh"
  # The template's presence is a separate precondition the script already
  # checks; every case here needs it satisfied so the assertion is about the
  # declaration rather than about the template.
  printf '#!/usr/bin/env bash\n# @@HOOK@@\n' > "$d/reference-implementations/project-hooks/shim-template.sh"
  if [ "$2" != ABSENT ]; then
    printf '%s' "$2" > "$d/reference-implementations/project-hooks/SHIMMED-HOOKS"
  fi
  # FLEET is a separate declaration and defaults to empty here, so a case says
  # which repositories it wants walked. Core is always a target regardless.
  : > "$d/reference-implementations/project-hooks/FLEET"
  [ -n "${3:-}" ] && printf '%s\n' "$3" > "$d/reference-implementations/project-hooks/FLEET"
  printf '%s' "$d"
}

run_check() {
  local core="$1" root="$2"
  OUT=$( "$core/tools/check-shims.sh" "$root" 2>&1 ); RC=$?
}

# ---------------------------------------------------------------------------
echo "A. An empty declaration reports that it checked nothing (task 2b.6)"
# ---------------------------------------------------------------------------
# This is the condition this change CREATES. Both declared entries go —
# database-sentinel with the host surface, the gate's project binding replaced
# by the machine-level git hook — so the set is empty rather than shorter.
core=$(new_core empty "# every entry retired
")
mkdir -p "$TMP/root-empty"
run_check "$core" "$TMP/root-empty"

if ! said "$CONFORMANCE"; then
  ok "an empty declaration does not print the conformance sentence"
else
  bad "an empty declaration does not print the conformance sentence" \
      "it claimed a clean fleet having examined no hooks" "$OUT"
fi

if said "no hooks" || said "nothing" || said "empty"; then
  ok "and it says the declaration is empty rather than staying silent"
else
  bad "and it says the declaration is empty rather than staying silent" \
      "silence and 'everything passed' read identically" "$OUT"
fi

# Not an error: an empty declaration is the intended END STATE of this change.
# Failing on it would make the fleet's correct condition unreportable.
if [ "$RC" -eq 0 ]; then
  ok "and an empty declaration is not itself a failure"
else
  bad "and an empty declaration is not itself a failure" "rc=$RC" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "B. An absent declaration is an error, distinctly from an empty one"
# ---------------------------------------------------------------------------
# `sed ... 2>/dev/null` makes these two states produce identical output, which
# is why the distinction has to be drawn before the read rather than after it.
# A declaration that is GONE means the instrument is broken; one that is EMPTY
# means the fleet is clean. Reporting them the same way is how a deleted file
# becomes a passing scan.
core=$(new_core absent ABSENT)
mkdir -p "$TMP/root-absent"
run_check "$core" "$TMP/root-absent"

if [ "$RC" -ne 0 ]; then
  ok "an absent declaration exits non-zero"
else
  bad "an absent declaration exits non-zero" \
      "rc=0 — a missing instrument reported as a clean fleet" "$OUT"
fi

if ! said "$CONFORMANCE"; then
  ok "and does not print the conformance sentence"
else
  bad "and does not print the conformance sentence" "$OUT"
fi

if said SHIMMED-HOOKS; then
  ok "and names the file it could not read"
else
  bad "and names the file it could not read" \
      "the operator cannot act on 'something was missing'" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "C. A populated declaration still behaves as before"
# ---------------------------------------------------------------------------
# The regression guard. Without it, 'never print the sentence' passes every
# assertion above and destroys the tool's only success output.
core=$(new_core populated "demo-hook
" demo-repo)
proj="$TMP/root-populated/demo-repo"
mkdir -p "$proj/.claude/hooks"
# Byte-identical to what the script renders from the template for this hook.
sed 's/@@HOOK@@/demo-hook/g' "$core/reference-implementations/project-hooks/shim-template.sh" \
  > "$proj/.claude/hooks/demo-hook.sh"
# Core is itself a target, and the missing-shim test runs before the
# self-hosting skip, so it needs the file present to reach that skip.
mkdir -p "$core/.claude/hooks"
cp "$proj/.claude/hooks/demo-hook.sh" "$core/.claude/hooks/demo-hook.sh"
# `find -maxdepth 2` from the root has to reach the repository directory, and
# the declaration's FLEET resolution names repositories by directory name.
run_check "$core" "$TMP/root-populated"

if said "$CONFORMANCE"; then
  ok "a populated declaration with a bound shim still reports conformance"
else
  bad "a populated declaration with a bound shim still reports conformance" \
      "the success path was removed along with the vacuous one" "$OUT"
fi

if [ "$RC" -eq 0 ]; then
  ok "and exits zero"
else
  bad "and exits zero" "rc=$RC" "$OUT"
fi

# A declared hook with no shim must still fail — the check's whole purpose.
core=$(new_core missing "demo-hook
" demo-repo)
mkdir -p "$TMP/root-missing/demo-repo/.claude/hooks"
run_check "$core" "$TMP/root-missing"

if [ "$RC" -ne 0 ] && ! said "$CONFORMANCE"; then
  ok "a declared hook with no shim still fails"
else
  bad "a declared hook with no shim still fails" "rc=$RC" "$OUT"
fi

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
