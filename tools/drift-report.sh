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

set -euo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../spec" && pwd)"

# Default to the spec repo's parent — the hosts are siblings of this repo.
# Previously hardcoded to ~/Sourcecode, which silently stopped resolving when
# the repos were reorganized into per-family subdirectories: every host reported
# "SKIP: not cloned" and the report showed 0 OK / 0 DRIFT for everyone. Deriving
# it from BASH_SOURCE keeps the default correct wherever the family tree lives.
HOSTS_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Hosts to check (relative to HOSTS_DIR). A host that isn't cloned is
# reported as SKIP — drift checks only run against present clones.
HOSTS=(
  "claude-workflow"
  "pi-agentic-apps-workflow"
  "codex-workflow"
  "opencode-workflow"
  "agenticapps-dashboard"
)

# Canonical phrases per spec section. Format: "section-id|phrase".
# These phrases are taken from the canonical-prose blocks in spec/
# and should appear verbatim in every conformant host's instruction
# files. If a phrase is missing from a host that claims `full`
# conformance, it is drift and warrants attention.
CHECKS=(
  "01-commitment-ritual|Step 0 — The Commitment Ritual"
  "01-commitment-ritual|I am using the agentic-apps-workflow skill"
  "01-commitment-ritual|Once I have stated this plan, I am committed to it."
  "03-rationalization|Rationalization Table — Check Before Skipping Anything"
  "03-rationalization|Skipping it is how discipline erodes"
  "03-rationalization|If you didn't write them down, you didn't consider them"
  "04-red-flags|13 Red Flags — STOP → DELETE → RESTART"
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
Hosts:     ${HOSTS[*]}
Checks:    ${#CHECKS[@]} canonical-phrase lookups per host

This is an advisory check. Exit code is always 0. Hosts that have
not yet adopted spec v0.1.0 will show DRIFT for most checks — that
is expected behavior, not a regression.

EOF

# --- per-host loop --------------------------------------------------------

ok_total=0
drift_total=0
skip_total=0

for host in "${HOSTS[@]}"; do
  host_path="$HOSTS_DIR/$host"
  echo "------------------------------------------------------------------------"
  echo "$host"
  echo "------------------------------------------------------------------------"

  if [[ ! -d "$host_path" ]]; then
    echo "  SKIP: not cloned at $host_path"
    skip_total=$((skip_total + ${#CHECKS[@]}))
    echo ""
    continue
  fi

  for check in "${CHECKS[@]}"; do
    section="${check%%|*}"
    phrase="${check##*|}"
    if grep -rq --include="*.md" --exclude-dir=.git -F "$phrase" "$host_path" 2>/dev/null; then
      echo "  OK    [$section] '$phrase'"
      ok_total=$((ok_total + 1))
    else
      echo "  DRIFT [$section] '$phrase' NOT FOUND in any .md under $host"
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

DRIFT findings are not failures. They indicate that the named host's
markdown files do not contain the canonical phrase from the named
spec section. If the host claims 'full' conformance with spec v0.1.0,
investigate; if the host has not yet adopted the spec, the finding
is expected.

For per-host adoption status, see reference-implementations/README.md.
EOF

exit 0
