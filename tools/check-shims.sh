#!/usr/bin/env bash
# check-shims.sh — did every repository get the current shim?
#
# Usage: tools/check-shims.sh [<root>]        (root defaults to ~/Sourcecode)
#
# Run this BY HAND after bumping the shim contract. That is the only event that
# can invalidate the answer, because nothing else writes a project's shim.
#
# WHY THIS IS SIXTY LINES AND NOT TWO THOUSAND. Its ancestor,
# project-hook-conformance.sh, grew a fleet resolver, checkout provenance, an
# override-vector classifier, an opt-out registry, a matcher axis and a
# thousand-line test suite — six times the size of the shim contract it measured
# — and then spent six of eight changes in a week repairing itself. Every repair
# was a real defect and every one was found by reading the previous repair's
# output. An instrument that generates its own work is not measuring the fleet.
#
# So this answers one question: is each declared hook bound, with the authority's
# bytes? If you find yourself adding an axis to it, add the check to the shim
# contract instead, or accept that the question is not worth a tool.
#
# It reports and exits 1 on a missing or drifted shim. It never writes anything.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DECL="$ROOT/reference-implementations/project-hooks"
TEMPLATE="$DECL/shim-template.sh"
root="${1:-$HOME/Sourcecode}"

# Declared, never discovered: a set derived from what you found cannot detect a
# missing member, so a repository that never got the bump would look like one
# that passed.
decl() { sed 's/#.*//' "$1" 2>/dev/null | awk 'NF'; }
[ -f "$TEMPLATE" ] || { echo "check-shims: no template at $TEMPLATE" >&2; exit 65; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
bad=0

# Core first, and included rather than excluded: a check that structurally omits
# the repository holding the authority cannot be quoted as covering it.
targets="$ROOT"
while IFS= read -r name; do
  found=$(find "$root" -maxdepth 2 -type d -name "$name" 2>/dev/null | head -1)
  if [ -z "$found" ]; then
    echo "MISSING REPO  $name  — declared in FLEET, found nowhere under $root"
    bad=1
  else
    targets="$targets"$'\n'"$found"
  fi
done < <(decl "$DECL/FLEET")

while IFS= read -r proj; do
  name=$(basename "$proj")
  while IFS= read -r hook; do
    shim="$proj/.claude/hooks/$hook.sh"
    if [ ! -f "$shim" ]; then
      if reason=$(awk -v r="$name" -v h="$hook" '$1==r && $2==h {$1="";$2="";sub(/^ +/,"");print;exit}' "$DECL/OPT-OUTS" 2>/dev/null) \
         && [ -n "$reason" ]; then
        echo "opt-out   $name  $hook  — $reason"
      else
        echo "MISSING   $name  $hook  — declared shimmed, no shim file"
        bad=1
      fi
      continue
    fi
    # Core resolves its own working tree by design (ADR-0028), so its bytes are
    # not the project render and comparing them would report a deliberate
    # inversion as drift.
    if [ "$proj" = "$ROOT" ]; then
      echo "present   $name  $hook  — self-hosting, bytes not compared (ADR-0028)"
      continue
    fi
    if [ "$hook" = "openspec-change-gate" ]; then
      expected="$DECL/openspec-change-gate.shim.sh"
    else
      expected="$TMP/$hook.expected"
      [ -f "$expected" ] || sed "s/@@HOOK@@/$hook/g" "$TEMPLATE" > "$expected"
    fi
    if cmp -s "$shim" "$expected"; then
      echo "ok        $name  $hook"
    else
      echo "DRIFTED   $name  $hook  — differs from $expected"
      bad=1
    fi
  done < <(decl "$DECL/SHIMMED-HOOKS")
done <<<"$targets"

echo
if [ "$bad" -eq 0 ]; then
  echo "Every declared hook is bound with the authority's bytes."
  echo "That is a statement about the trees checked out under $root right now."
else
  echo "Something is missing or drifted above. Fix the shim it names."
fi
exit "$bad"
