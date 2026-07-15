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
# On the secondary files: spec/09 says "the host's instruction file"
# (singular), but no host keeps every canonical block in one file, because
# section 11 is not prose the workflow skill speaks to itself — it is a block
# the host injects into consuming projects. codex and opencode carry it in
# AGENTS.md behind a provenance anchor; claude-workflow carries it in a spec
# mirror under templates/. Each host therefore declares the full set of files
# its canonical prose legitimately lives in, and a phrase satisfies a check
# when it appears in ANY file of that set.
#
# The set is kept deliberately narrow. claude-workflow's glob is
# templates/spec-mirrors/*.md, NOT templates/*.md: the host also ships a
# reworded 13-flag list in its vendored CLAUDE.md payload
# (templates/.claude/claude-md/workflow.md) which its own spec delta declares
# is NOT bound by spec/09 item 1. A broad templates glob would let that known
# divergence satisfy section 04 — the exact false PASS this rewrite exists to
# prevent.
#
# Only hosts that author canonical prose belong here:
#   - pi-agentic-apps-workflow was retired as a host (adoption not pursued).
#   - agenticapps-dashboard is a consumer — it reads workflow artifacts and
#     authors none, so canonical-prose checks do not apply to it.
HOSTS=(
  "claude-workflow|skill/SKILL.md|templates/spec-mirrors/*.md"
  "codex-workflow|skills/agentic-apps-workflow/SKILL.md|AGENTS.md"
  "opencode-workflow|skills/agentic-apps-workflow/SKILL.md|AGENTS.md"
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
against its declared primary instruction file ONLY — canonical prose
found anywhere else in the clone (docs, migrations, test fixtures,
planning notes, untracked scratch) does not satisfy a check, because
spec/09 binds the blocks to that one file.

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
  prose_files=("$instruction_file")
  prose_rel="$instruction_rel"
  for pat in $secondary_pats; do
    for candidate in "$host_path"/$pat; do
      if [[ -f "$candidate" ]]; then
        prose_files+=("$candidate")
        prose_rel="$prose_rel, ${candidate#"$host_path"/}"
      fi
    done
  done

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
