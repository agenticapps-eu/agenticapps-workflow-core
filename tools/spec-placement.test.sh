#!/usr/bin/env bash
# spec-placement.test.sh — guard the property `openspec validate` cannot see.
#
# WHY THIS EXISTS
#
# On 2026-08-03 the archive fold at 09f829e severed a paragraph in
# openspec/specs/project-hook-binding/spec.md. Its first half stayed in the
# requirement "A machine's provisioning is a triple, not a state name"; its
# second half was filed ~66 lines away inside "Currency is judged against an
# authority checkout", where it read as a fragment opening on a lowercase
# continuation. Two requirements each held half a sentence for three commits.
#
# Nothing caught it:
#   - `openspec validate --all` was green throughout — a torn sentence is
#     schema-valid.
#   - The line-multiset diff that guarded the refactor proved every line
#     survived, which was TRUE. Every line did survive. In the wrong
#     requirement.
#
# "Every line still exists" is a weaker property than "every line is in the
# right place." This script checks the stronger one. It is deliberately a
# PLACEMENT check and not a diff, because a diff is what already failed here.
#
# It is not a grammar checker. It looks for the two textual signatures a torn
# paragraph leaves behind, both of which are cheap and neither of which fires
# on the four specs that were never torn.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
SPECS=(openspec/specs/*/spec.md)
fails=0

note() { printf '  %s\n' "$*"; }

# ── Signature 1 ────────────────────────────────────────────────────────────
# A paragraph that opens on a lowercase word — or on **bold** lowercase — is a
# sentence continuing from somewhere else. Prose paragraphs open on a capital.
# Excluded: indented lines (bullet continuations), headings, tables, block
# quotes, fenced code, list items.
tears_opening() {
  awk '
    /^```/ { fence = !fence; prev = $0; next }
    fence  { prev = $0; next }
    NR > 1 && prev == "" && $0 != "" \
      && $0 !~ /^[ \t]/ && $0 !~ /^[#|>`]/ && $0 !~ /^- / && $0 !~ /^[0-9]+\. / \
      && (substr($0,1,1) ~ /[a-z]/ || $0 ~ /^\*\*[a-z]/) \
      { printf "%d: %s\n", NR, $0 }
    { prev = $0 }
  ' "$1"
}

# ── Signature 2 ────────────────────────────────────────────────────────────
# A paragraph whose last line ends with no terminal punctuation has had its
# ending taken away. Excluded: the same structural lines as above, plus
# ordered-list items, whose final entry legitimately ends bare in this repo's
# house style (see the resolution-order list in project-hook-binding).
tears_ending() {
  awk '
    /^```/ { fence = !fence }
    { l[NR] = $0; f[NR] = fence }
    END {
      for (i = 1; i <= NR; i++) {
        if (f[i]) continue
        if (l[i] == "" || l[i+1] != "") continue
        # NB: no backtick in this class. Fenced code is already excluded by the
        # fence tracker above, and a prose line may legitimately OPEN on a code
        # span — the torn line this check exists for opens on `CLAUDE.md`.
        # Excluding backticks here silently blinded the check to its own case.
        if (l[i] ~ /^[ \t]/ || l[i] ~ /^[#|>-]/ || l[i] ~ /^[0-9]+\. /) continue
        if (l[i] ~ /[.:;!?)"`*_]$/) continue
        printf "%d: %s\n", i, l[i]
      }
    }
  ' "$1"
}

echo "== torn-paragraph sweep across ${#SPECS[@]} spec(s) =="
for f in "${SPECS[@]}"; do
  [ -f "$f" ] || continue
  o=$(tears_opening "$f")
  e=$(tears_ending "$f")
  if [ -n "$o" ] || [ -n "$e" ]; then
    fails=$((fails + 1))
    echo "FAIL  $f"
    [ -n "$o" ] && { note "paragraph opens mid-sentence (continuation stranded here):"; note "$o"; }
    [ -n "$e" ] && { note "paragraph ends mid-sentence (continuation taken away):"; note "$e"; }
  else
    echo "ok    $f"
  fi
done

# ── Targeted invariant ─────────────────────────────────────────────────────
# The Currency cell of the provisioning axes table states `current` and `stale`
# as a matched pair. Both are scoped to artifacts PRESENT on the machine: an
# artifact absent from the machine is completeness's finding and is not judged
# on the currency axis at all (see the requirement prose and the scenario
# "The authority holds no such artifact", and provisioning-check.sh, which
# skips absent artifacts before comparing).
#
# The `stale` clause once lacked that qualifier while `current` carried it, so
# the table contradicted the requirement it summarised. This asserts the two
# clauses stay scoped together.
PHB=openspec/specs/project-hook-binding/spec.md
echo
echo "== currency table clause parity =="
if [ -f "$PHB" ]; then
  row=$(grep -m1 '^| \*\*Currency\*\*' "$PHB" || true)
  if [ -z "$row" ]; then
    echo "FAIL  $PHB: no Currency row found in the axes table"
    fails=$((fails + 1))
  else
    cur_ok=0; stale_ok=0
    case "$row" in
      *"every declared, present implementation"*) cur_ok=1 ;;
    esac
    case "$row" in
      *"no file for a declared, present artifact"*) stale_ok=1 ;;
    esac
    if [ "$cur_ok" -eq 1 ] && [ "$stale_ok" -eq 1 ]; then
      echo "ok    both clauses scope currency to PRESENT artifacts"
    else
      fails=$((fails + 1))
      echo "FAIL  the Currency cell's clauses disagree on presence scoping"
      [ "$cur_ok"   -eq 0 ] && note "\`current\` clause lost \"every declared, present implementation\""
      [ "$stale_ok" -eq 0 ] && note "\`stale\` clause lost \"no file for a declared, present artifact\""
      note "An artifact absent from the machine is completeness's finding."
      note "Reporting it on the currency axis too is the defect this guards."
    fi
  fi
else
  echo "FAIL  $PHB missing"
  fails=$((fails + 1))
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "FAILED — $fails check(s). A spec says two things about one condition,"
  echo "or a sentence is split across two requirements."
  exit 1
fi
# Say what was checked, never what is true of the specs. This script detects
# tears at PARAGRAPH BOUNDARIES: a fragment relocated as a whole, grammatically
# intact paragraph passes it, and only a reader catches that. Claiming "every
# paragraph is whole" would be a check overstating its own reach — the exact
# failure this repository keeps finding, and the reason this change exists.
echo "PASSED — no torn paragraph boundary found, and the currency clauses agree."
echo "         Scope: paragraph-boundary tears only. A grammatically intact"
echo "         paragraph moved to the wrong requirement passes this check."
