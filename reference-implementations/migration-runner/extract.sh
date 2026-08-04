#!/usr/bin/env bash
# migration-runner-version: 0.1.0
# extract.sh — pull role-tagged fenced blocks out of a migration document.
#
# WHY THIS EXISTS AND WHAT IT REPLACES. codex-workflow's run-tests.sh carries
# extract_step_block(), which finds the first fence after a `**Label:**` marker.
# That is kept, and this is not a rewrite of it: the labels still structure the
# document. What labels cannot express is that a fence is ILLUSTRATION. This
# reads the role tag, so an un-annotated ```bash block is invisible to it.
#
# TWO PROPERTIES PORTED DELIBERATELY from extract_step_block(), because both
# were defects found under review there and would otherwise be re-introduced:
#
#   1. DELIMITER GUARD. `index($0, "### Step 1") == 1` also prefix-matches
#      "### Step 10" through "### Step 19". A document with ten or more steps
#      would latch onto the wrong step. delim_ok() requires the character after
#      the matched prefix to be ':', ' ', or end-of-line.
#
#   2. LITERAL PREFIX, NEVER AN INTERPOLATED REGEX. Step and role arrive as awk
#      -v variables and are compared with index()/string equality, never spliced
#      into a /.../ regex. There is nothing to escape and nothing to inject.
#
# Usage:
#   extract.sh steps <doc>                 -> step numbers, one per line
#   extract.sh roles <doc> <step>          -> roles present, one per line
#   extract.sh block <doc> <step> <role>   -> block body; exit 1 if absent

set -uo pipefail

mr_steps() {
  awk '
    index($0, "### Step ") == 1 {
      rest = substr($0, 10); n = ""
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (c >= "0" && c <= "9") n = n c; else break
      }
      if (n != "") print n + 0
    }
  ' "$1"
}

mr_roles() {
  local doc="$1" step="$2"
  awk -v stepp="### Step ${step}" '
    function delim_ok(line, plen,   d) {
      d = substr(line, plen + 1, 1)
      return (d == "" || d == ":" || d == " ")
    }
    # FENCE STATE IS TRACKED FIRST, BEFORE ANY STEP LOGIC.
    #
    # Step bodies are shell, and shell contains heredocs. A migration whose
    # apply block writes a document containing the line "### Step 2" would
    # otherwise truncate its own step there and hide every role below it — the
    # linter and the runner would both agree the step was fine. Recognising a
    # step heading only OUTSIDE a fence is what closes that.
    !infence && index($0, "```") == 1 {
      infence = 1
      info = substr($0, 4); sub(/[ \t]+$/, "", info)
      # EXACT GRAMMAR: literal bash, whitespace, role=, a lowercase role name,
      # then end of string. An info-string carrying extra keys is NOT a tagged
      # fence — it falls through to the linter as a violation rather than being
      # silently honoured with its extra keys ignored.
      if (in_step && info ~ /^bash[ \t]+role=[a-z]+$/) {
        sub(/^bash[ \t]+role=/, "", info); print info
      }
      next
    }
    infence && index($0, "```") == 1 { infence = 0; next }
    infence { next }
    # ANY step heading ends the previous step. Bounding on "the next step
    # heading" rather than on "the heading numbered N+1" means a gap in the
    # numbering cannot merge two steps and hide the second one'"'"'s roles.
    index($0, "### Step ") == 1 {
      in_step = (index($0, stepp) == 1 && delim_ok($0, length(stepp)))
      next
    }
  ' "$doc"
}

mr_block() {
  local doc="$1" step="$2" role="$3" out
  out="$(awk -v stepp="### Step ${step}" -v want="$role" '
    function delim_ok(line, plen,   d) {
      d = substr(line, plen + 1, 1)
      return (d == "" || d == ":" || d == " ")
    }
    # Fence state first — see the note in mr_roles. A "### Step" line inside a
    # heredoc is shell, not a heading.
    !infence && index($0, "```") == 1 {
      infence = 1
      info = substr($0, 4); sub(/[ \t]+$/, "", info); r = ""
      if (info ~ /^bash[ \t]+role=[a-z]+$/) { r = info; sub(/^bash[ \t]+role=/, "", r) }
      if (in_step && r == want) capturing = 1
      next
    }
    infence && index($0, "```") == 1 {
      infence = 0
      if (capturing) { found = 1; exit }
      next
    }
    capturing { print; next }
    infence { next }
    index($0, "### Step ") == 1 {
      in_step = (index($0, stepp) == 1 && delim_ok($0, length(stepp)))
      next
    }
    END { if (!found) exit 1 }
  ' "$doc")" || return 1
  printf '%s\n' "$out"
}

# CLI
case "${1:-}" in
  steps) mr_steps "$2" ;;
  roles) mr_roles "$2" "$3" ;;
  block) mr_block "$2" "$3" "$4" ;;
  *) echo "usage: extract.sh steps|roles|block <doc> [<step>] [<role>]" >&2; exit 64 ;;
esac
