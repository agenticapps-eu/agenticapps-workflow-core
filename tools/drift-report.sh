#!/usr/bin/env bash
# drift-report.sh — advisory health check that compares canonical
# blocks in the spec against host implementations.
#
# NOT a CI gate. Reports drift; does not fail. Run periodically
# (monthly is fine) or before cutting a spec minor/major release.
#
# Usage: drift-report.sh [path-to-host-clones-dir]
# Default: this repo's parent directory — the family dir the host clones
# sit in, alongside the spec repo itself.
#
# Exit code is always 0. The script is read-only — it does not modify
# any file in the spec repo or in any host clone.
#
# Tests: tools/drift-report.test.sh

set -euo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../spec" && pwd)"

# Default to the spec repo's parent — the hosts are siblings of this repo.
# Previously hardcoded to ~/Sourcecode, which silently stopped resolving when
# the repos were reorganized into per-family subdirectories: every host reported
# "SKIP: not cloned" and the report showed 0 OK / 0 DRIFT for everyone. Deriving
# it from BASH_SOURCE keeps the default correct wherever the family tree lives.
HOSTS_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Hosts to check, as:
#
#   "repo-dir|primary-instruction-file|secondary prose files (globs ok)"
#
# A host that isn't cloned is reported as SKIP — drift checks only run
# against present clones.
#
# These paths are DECLARED, not discovered. spec/09 item 1 binds the canonical
# blocks to "the host's instruction file"; item 4 identifies the primary file
# as the one carrying `implements_spec:`. Scanning for that field does not
# identify it uniquely — claude-workflow has seven files carrying it (a
# build-artifact snapshot, satellite skills, stale planning docs) and
# codex-workflow thirteen — so any discovery rule would be a heuristic that
# can silently pick the wrong file. That is the bug class this tool shipped
# with; declaring the paths keeps the check honest and its failure mode loud.
#
# On the secondary file: the canonical blocks are not all bound to one file,
# and the spec says so itself. spec/09 item 1 binds sections 01/03/04/05 to
# "the host's instruction file (e.g. SKILL.md)". spec/11 separately and
# explicitly binds its own block to a DIFFERENT file: "Host implementations
# MUST reproduce the block below verbatim in their primary project-instruction
# file (CLAUDE.md, AGENTS.md, or whichever filename the host runtime treats as
# canonical project-level guidance)."
#
# So each host declares two files: the workflow skill (01/03/04/05) and the
# project-instruction file (11). A phrase satisfies a check when it appears in
# either.
#
# What must NOT go in this list is a scaffolding payload. An earlier revision
# declared claude-workflow's templates/spec-mirrors/*.md here, reasoning that
# section 11 is "injected into consuming projects rather than spoken by the
# skill". That is a description of the payload, not of an instruction file: the
# mirror under templates/ is shipped INTO other projects by migration 0014 and
# instructs nobody in this repo. Counting it made section 11 report OK for
# claude-workflow off the back of a template — the same false PASS this tool
# shipped with, in better clothes — and masked a real gap: claude-workflow's
# own CLAUDE.md does not carry the block, while codex's and opencode's
# AGENTS.md both do. Declaring CLAUDE.md surfaces that as honest DRIFT.
#
# Only hosts that author canonical prose belong here:
#   - pi-agentic-apps-workflow was retired as a host at spec 0.9.1 (adoption not
#     pursued; it carried implements_spec in no file and shipped no section 11
#     block, so there was nothing to score). Both were fixed at host v0.2.0, so
#     it is scored again as of 2026-07-19.
#   - agenticapps-dashboard is a consumer — it reads workflow artifacts and
#     authors none, so canonical-prose checks do not apply to it.
HOSTS=(
  "claude-workflow|skill/SKILL.md|CLAUDE.md"
  "codex-workflow|skills/agentic-apps-workflow/SKILL.md|AGENTS.md"
  "opencode-workflow|skills/agentic-apps-workflow/SKILL.md|AGENTS.md"
  "pi-agentic-apps-workflow|skills/agentic-apps-workflow/SKILL.md|AGENTS.md"
)

# Canonical phrases per spec section. Format: "section-id|phrase".
# These phrases are taken from the canonical-prose blocks in spec/
# and should appear verbatim in every conformant host's instruction
# file. If a phrase is missing from a host that claims `full`
# conformance, it is drift and warrants attention.
#
# On 04-red-flags: the phrase omits the heading's leading count on purpose.
# spec/04 rule 3 (since spec 0.8.0) makes the count NOT normative — a host
# that appends a host-specific flag updates it to its own total, so
# claude-workflow's `## 14 Red Flags — ...` is conformant. Only the remainder
# of the heading is canonical, and that is what is checked here.
CHECKS=(
  "01-commitment-ritual|Step 0 — The Commitment Ritual"
  "01-commitment-ritual|I am using the agentic-apps-workflow skill"
  "01-commitment-ritual|Once I have stated this plan, I am committed to it."
  "03-rationalization|Rationalization Table — Check Before Skipping Anything"
  "03-rationalization|Skipping it is how discipline erodes"
  "03-rationalization|If you didn't write them down, you didn't consider them"
  "04-red-flags|Red Flags — STOP → DELETE → RESTART"
  "04-red-flags|Code written before the test"
  "04-red-flags|This case is different because"
  "05-pressure-test|Pressure-Test Scenarios — Self-Check"
  "05-pressure-test|Would a senior engineer reviewing this work accept the shortcut"
  "05-pressure-test|If any answer gives you pause, follow the protocol"
  "11-coding-discipline|Coding Discipline (NON-NEGOTIABLE)"
  "11-coding-discipline|Think Before Coding"
  "11-coding-discipline|These four rules are reread every session"
)

# --- header ----------------------------------------------------------------

cat <<EOF
========================================================================
agenticapps-workflow-core drift report
========================================================================

Spec dir:  $SPEC_DIR
Hosts dir: $HOSTS_DIR
Checks:    ${#CHECKS[@]} canonical-phrase lookups per host

This is an advisory check. Exit code is always 0. Each host is checked
against the files it declares below as carrying canonical prose — its
workflow instruction file (spec/09 item 1) and its project-instruction
file (spec/11) — and nothing else. Canonical prose found anywhere else
in the clone (docs, migrations, test fixtures, scaffolding payloads,
planning notes, untracked scratch) does not satisfy a check.

EOF

# --- per-host loop --------------------------------------------------------

ok_total=0
drift_total=0
skip_total=0
error_total=0

for entry in "${HOSTS[@]}"; do
  IFS='|' read -r host instruction_rel secondary_pats <<< "$entry"
  host_path="$HOSTS_DIR/$host"
  instruction_file="$host_path/$instruction_rel"

  echo "------------------------------------------------------------------------"
  echo "$host"
  echo "------------------------------------------------------------------------"

  if [[ ! -d "$host_path" ]]; then
    echo "  SKIP: not cloned at $host_path"
    skip_total=$((skip_total + ${#CHECKS[@]}))
    echo ""
    continue
  fi

  # A declared instruction file that isn't there is a tool-or-host problem,
  # not drift. Report it loudly rather than scoring the host against a file
  # that does not exist.
  if [[ ! -f "$instruction_file" ]]; then
    echo "  ERROR: declared instruction file not found: $instruction_rel"
    echo "         (looked for $instruction_file)"
    echo "         Either the host moved it, or this script's HOSTS table is stale."
    error_total=$((error_total + 1))
    echo ""
    continue
  fi

  # spec/09 item 4: the primary instruction file MUST carry implements_spec.
  # "A host that ships an instruction file without this field is unversioned
  # and cannot claim any conformance level" — so there is nothing to score.
  if ! grep -qE '^implements_spec:' "$instruction_file"; then
    echo "  ERROR: $instruction_rel does not carry implements_spec:"
    echo "         Unversioned per spec/09 item 4 — cannot claim any conformance"
    echo "         level, so its canonical checks are not scored."
    error_total=$((error_total + 1))
    echo ""
    continue
  fi

  # The prose set: the primary instruction file plus any declared secondary
  # files that exist. An unmatched glob stays literal in bash, so the -f test
  # filters it out rather than handing grep a nonexistent path.
  #
  # `read -ra` splits the patterns on whitespace WITHOUT expanding them. An
  # unquoted `for pat in $secondary_pats` would instead glob each pattern
  # against the caller's current directory before it ever reaches the host: run
  # from a directory that happens to contain templates/spec-mirrors/*.md, the
  # pattern collapses to that file's name and is then looked for, literally,
  # under the host. The report's answer would depend on where it was run from.
  # T12 covers this.
  # Secondary paths are literal, not globs. An earlier revision globbed them,
  # which cost a real bug: `for pat in $secondary_pats` pathname-expands each
  # pattern against the CALLER'S directory before it ever reaches the host, so
  # running from a directory that happened to contain a matching path silently
  # rewrote the pattern into that file's name — the report answered differently
  # depending on where you ran it from. No host needs a glob, so the feature is
  # gone rather than fixed: "$host_path/$rel" is quoted end to end and cannot
  # be expanded against anything.
  #
  # The -n guard is not redundant: on bash 3.2 — what /usr/bin/env bash still
  # resolves to on macOS — expanding "${arr[@]}" on an EMPTY array under
  # `set -u` aborts with "unbound variable", which would take the script down
  # and break the "exit code is always 0" contract above. No current host has an
  # empty third field, so it guards the next one rather than anything today.
  prose_files=("$instruction_file")
  prose_rel="$instruction_rel"
  if [[ -n "$secondary_pats" ]]; then
    read -ra secondary_list <<< "$secondary_pats"
    for rel in "${secondary_list[@]}"; do
      candidate="$host_path/$rel"
      if [[ -f "$candidate" ]]; then
        prose_files+=("$candidate")
        prose_rel="$prose_rel, $rel"
      fi
    done
  fi

  echo "  $instruction_rel — $(grep -E '^implements_spec:' "$instruction_file" | head -1)"
  echo "  prose set: $prose_rel"

  for check in "${CHECKS[@]}"; do
    section="${check%%|*}"
    phrase="${check##*|}"
    if grep -qF -- "$phrase" "${prose_files[@]}" 2>/dev/null; then
      echo "  OK    [$section] '$phrase'"
      ok_total=$((ok_total + 1))
    else
      echo "  DRIFT [$section] '$phrase' NOT FOUND in $prose_rel"
      drift_total=$((drift_total + 1))
    fi
  done
  echo ""
done

# --- summary --------------------------------------------------------------

cat <<EOF
========================================================================
Summary
========================================================================

OK     : $ok_total checks passed
DRIFT  : $drift_total checks failed (advisory)
SKIP   : $skip_total checks skipped (host not cloned)
ERROR  : $error_total hosts not scored (missing or unversioned
         instruction file — see above)

DRIFT findings are not failures. They indicate that the named host's
declared instruction file does not contain the canonical phrase from
the named spec section. If the host claims 'full' conformance,
investigate; if the host has not yet adopted the spec, the finding
is expected.

ERROR findings mean a host could not be scored at all. Unlike DRIFT,
they more often indicate this script is stale than that the host is.

For per-host adoption status, see reference-implementations/README.md.
EOF

exit 0
