#!/usr/bin/env bash
# migration-runner-version: 0.1.0
# lint-migration.sh — enforce the executable migration format.
#
# L1  every step has exactly one check, precondition, apply, rollback;
#     verify is 0 or 1
# L2  each role= fence sits under its matching **Label:** heading
# L3  no duplicate roles within a step
# L4  unknown role values are rejected
# L5  role= appears only on bash fences, and only in the exact grammar
#     ^bash[ \t]+role=[a-z]+$
#
# L2, L4 and the pass/fail threshold are OUT OF SCOPE for this script. Only
# L1, L3 and L5 are implemented here; later work adds the rest. Do not treat
# the comments above as evidence those rules run — they document where this
# script sits in the full rule set, nothing more.
#
# L1's job is presence only: "verify appears at most once" and "no role
# appears more than once" are both L3's problem, so a required role that
# shows up twice is NOT also reported as missing by L1 — grep -qx a role
# name matches on any of its occurrences.
#
# L5 checks EVERY fence whose info string contains the substring "role=",
# not just fences that are already known to be tagged apply/check/etc. A
# fence opened as ```bash role=apply retry=2``` is syntactically a bash
# fence but still fails L5: the exact grammar is anchored at both ends
# (^...$), so a trailing extra key is a grammar violation exactly like a
# non-bash fence type is. Silently accepting "close enough" info strings is
# how a typo'd or embellished role= fence stops being annotated without
# anyone noticing — L4's docstring above makes the same point about typo'd
# role names; this is the same failure mode for the fence's info string as
# a whole.
#
# Usage: lint-migration.sh <doc>
# Exit 0 = clean. Exit 1 = one `L<n>: step <s>: <message>` line per
# violation, on stderr.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC="${1:?usage: lint-migration.sh <doc>}"

violations=0
report() { echo "$*" >&2; violations=$((violations + 1)); }

REQUIRED="check precondition apply rollback"

steps="$(bash "$SCRIPT_DIR/extract.sh" steps "$DOC")"

for s in $steps; do
  roles="$(bash "$SCRIPT_DIR/extract.sh" roles "$DOC" "$s")"

  # L1 — every required role present at least once (duplicates are L3's job)
  for r in $REQUIRED; do
    printf '%s\n' "$roles" | grep -qx "$r" || \
      report "L1: step $s: missing required role '$r'"
  done

  # L3 — no role (required or optional) may appear more than once
  dupes="$(printf '%s\n' "$roles" | awk 'NF' | sort | uniq -d)"
  for d in $dupes; do
    report "L3: step $s: role '$d' appears more than once"
  done
done

# L5 — role= only on bash fences, and only in the exact grammar. Scans every
# fence in the document (fence state tracked first, exactly like
# extract.sh's mr_roles/mr_block, so a "```" inside a heredoc body is not
# mistaken for a real fence delimiter) and remembers the most recently seen
# step heading so each violation can be reported as `L5: step <s>: ...`.
while IFS= read -r line; do
  [ -n "$line" ] && report "$line"
done < <(awk '
  function delim_ok(line, plen,   d) {
    d = substr(line, plen + 1, 1)
    return (d == "" || d == ":" || d == " ")
  }
  !infence && index($0, "```") == 1 {
    infence = 1
    info = substr($0, 4); sub(/[ \t]+$/, "", info)
    if (info ~ /role=/ && info !~ /^bash[ \t]+role=[a-z]+$/) {
      s = (curstep == "" ? "0" : curstep)
      printf "L5: step %s: role= info string does not match ^bash[ \\t]+role=[a-z]+$: %s\n", s, info
    }
    next
  }
  infence && index($0, "```") == 1 { infence = 0; next }
  infence { next }
  index($0, "### Step ") == 1 {
    rest = substr($0, 10); n = ""
    for (i = 1; i <= length(rest); i++) {
      c = substr(rest, i, 1)
      if (c >= "0" && c <= "9") n = n c; else break
    }
    if (n != "") curstep = n + 0
    next
  }
' "$DOC")

[ "$violations" -eq 0 ]
