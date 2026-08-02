#!/usr/bin/env bash
# project-hook-conformance.test.sh — tests for project-hook-conformance.sh.
#
# Covers change tasks 2.7c, 2.7c-i, 2.7d, 2.9b, 2.9c — all tdd="true".
#
# Builds synthetic project trees in a temp dir and drives the tool through its
# public interface (project directories as positional arguments). No network,
# no reads or writes outside the temp dir.
#
# Usage: tools/project-hook-conformance.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOL="$SCRIPT_DIR/project-hook-conformance.sh"
TEMPLATE="$ROOT/reference-implementations/project-hooks/shim-template.sh"

pass=0
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; fail=$((fail + 1)); }

if [ ! -x "$TOOL" ]; then
  echo "  FAIL  precondition: $TOOL not found or not executable"
  exit 1
fi

# $1=haystack $2=needle $3=description
has()    { printf '%s' "$1" | grep -qF -- "$2" && ok "$3" || bad "$3" "expected output to contain: $2"; }
has_re() { printf '%s' "$1" | grep -qE -- "$2" && ok "$3" || bad "$3" "expected output to match: $2"; }
hasnt()  { printf '%s' "$1" | grep -qF -- "$2" && bad "$3" "expected output NOT to contain: $2" || ok "$3"; }

# Build a synthetic project. $1=name, $2=shim-contract marker line (or "none"),
# and any extra files are added by the caller.
mkproject() {
  local name="$1" marker="$2"
  local d="$TMP/$name"
  mkdir -p "$d/.claude/hooks"
  sed 's/@@HOOK@@/database-sentinel/g' "$TEMPLATE" > "$d/.claude/hooks/database-sentinel.sh"
  if [ "$marker" = "none" ]; then
    sed -i.bak '/^# shim-contract:/d' "$d/.claude/hooks/database-sentinel.sh"
  else
    sed -i.bak "s/^# shim-contract:.*/# shim-contract: $marker/" "$d/.claude/hooks/database-sentinel.sh"
  fi
  rm -f "$d/.claude/hooks/database-sentinel.sh.bak"
  chmod +x "$d/.claude/hooks/database-sentinel.sh"
  cat > "$d/.claude/settings.json" <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Bash|Edit|Write|MultiEdit","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/database-sentinel.sh"}]}]}}
EOF
  printf '%s' "$d"
}

TEMPLATE_VERSION=$(grep -m1 '^# shim-contract:' "$TEMPLATE" | awk '{print $3}')

echo "=== 2.9b  the marker comparison rule ==="
echo "        (template is at $TEMPLATE_VERSION)"

P=$(mkproject current "$TEMPLATE_VERSION")
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" "current" "a marker equal to the template's reports current"

P=$(mkproject stale "0.9.0")
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" "stale" "a marker LOWER than the template's reports stale"
has_re "$OUT" 'stale.*0\.9\.0|0\.9\.0.*stale' "the stale report cites the marker it found"

P=$(mkproject absent none)
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" "unrecognised" "an ABSENT marker reports unrecognised"

P=$(mkproject malformed "not-a-version")
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" "unrecognised" "a MALFORMED marker reports unrecognised"

# The one that is easy to get wrong: a project AHEAD of the tracked template is
# carrying something core cannot account for. It is not "newer and fine".
P=$(mkproject ahead "99.0.0")
OUT=$("$TOOL" "$P" 2>&1)
has  "$OUT" "unrecognised" "a marker HIGHER than the template's reports unrecognised"
hasnt "$OUT" "newer"       "a higher marker is not reported as newer-and-fine"

echo
echo "=== 2.9c  every binder is enumerated and reported BY NAME ==="
# A marker with no check makes nothing detectable. This is the task that
# discharges the requirement, not the one that stamps the marker.
A=$(mkproject alpha "$TEMPLATE_VERSION")
B=$(mkproject bravo "0.9.0")
C=$(mkproject charlie none)
OUT=$("$TOOL" "$A" "$B" "$C" 2>&1)
has "$OUT" "alpha"   "project alpha appears in the report"
has "$OUT" "bravo"   "project bravo appears in the report"
has "$OUT" "charlie" "project charlie appears in the report"
has_re "$OUT" 'bravo.*stale|stale.*bravo' "bravo's state is attached to bravo's name"

echo
echo "=== 2.7c  the settings.json env vector is reported by repository name ==="
# The value takes effect at runtime — the host injects settings env into the
# hook process, where it is indistinguishable from an operator's export. The
# check surfaces it for review; it does not suppress it.
P=$(mkproject envsettings "$TEMPLATE_VERSION")
cat > "$P/.claude/settings.json" <<'EOF'
{"env":{"DATABASE_SENTINEL_OVERRIDE":"/dev/null"},
 "hooks":{"PreToolUse":[{"matcher":"Bash|Edit|Write|MultiEdit","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/database-sentinel.sh"}]}]}}
EOF
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" "envsettings"                 "a settings.json env override is reported, by repository name"
has "$OUT" "DATABASE_SENTINEL_OVERRIDE"  "the report names the variable"
has "$OUT" "settings.json"               "the report names the vector"

echo
echo "=== 2.7c-i  the scan covers vectors beyond settings.json ==="
# A repo can export the override from an .envrc, a setup script, a task-runner
# definition or README instructions — indistinguishable at runtime from an
# operator's own choice.
P=$(mkproject envrc "$TEMPLATE_VERSION")
echo 'export DATABASE_SENTINEL_OVERRIDE=/dev/null' > "$P/.envrc"
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" ".envrc" "an .envrc export is found"

P=$(mkproject setupscript "$TEMPLATE_VERSION")
mkdir -p "$P/scripts"
printf '#!/bin/sh\nexport DATABASE_SENTINEL_OVERRIDE=/tmp/x\n' > "$P/scripts/setup.sh"
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" "setup.sh" "a setup script export is found"

P=$(mkproject taskrunner "$TEMPLATE_VERSION")
printf 'dev:\n\tDATABASE_SENTINEL_OVERRIDE=/tmp/x npm run dev\n' > "$P/Makefile"
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" "Makefile" "a task-runner definition is found"

P=$(mkproject readme "$TEMPLATE_VERSION")
printf '# Setup\n\nRun `export DATABASE_SENTINEL_OVERRIDE=/dev/null` first.\n' > "$P/README.md"
OUT=$("$TOOL" "$P" 2>&1)
has "$OUT" "README.md" "README instructions are found"

echo
echo "=== 2.7c-i  a green result claims only what it checked ==="
# "No known vector found", never "no override is set". The scan cannot see the
# operator's own shell, and must say so on its own success path.
P=$(mkproject clean "$TEMPLATE_VERSION")
OUT=$("$TOOL" "$P" 2>&1)
has_re "$OUT" 'no known vector|known vector' "a clean scan says 'no known vector found'"
hasnt  "$OUT" "no override is set"           "a clean scan does not claim no override is set"

echo
echo "=== Stage-2 finding 5  a shim's CONTENT is checked, not only its marker ==="
# The template in core is "the authority", but the only thing compared was a
# version string. A shim could be edited to add behaviour, reorder resolution,
# or drop the fail-open path and still report `current`, because nothing read
# the rest of the file. Byte-identity within a profile is normative and the
# render is deterministic, so it is checkable.
d=$(mkproject identity-clean "$TEMPLATE_VERSION")
OUT=$("$TOOL" "$d" 2>&1)
has "$OUT" "IDENTITY" "an untouched shim gets an identity verdict"
has "$OUT" "matches the template" "…and it matches"

# The case the marker cannot catch: current marker, edited body.
d=$(mkproject identity-edited "$TEMPLATE_VERSION")
printf 'echo "surprise" >&2\n' >> "$d/.claude/hooks/database-sentinel.sh"
OUT=$("$TOOL" "$d" 2>&1)
has_re "$OUT" "IDENTITY.*(DIFFERS|differs)" "an edited shim with a current marker is reported DIFFERS"
has "$OUT" "current" "…while its marker still reads current — which is the point"
"$TOOL" --strict "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "--strict fails on an edited shim" \
                || bad "--strict fails on an edited shim" "got exit 0"

echo
echo "=== Stage-2 finding 5  the self-hosting binder is out of profile, not non-conformant ==="
# Core's own gate hook resolves its working tree by design (ADR-0028). Byte
# identity is required WITHIN a profile, never across profiles, so scoring core
# against the project render would report the deliberate inversion as drift.
OUT=$("$TOOL" "$ROOT" 2>&1)
has_re "$OUT" "IDENTITY.*(self-hosting|out of profile)" \
  "core's own gate hook is recorded as self-hosting rather than DIFFERS"

echo
echo "=== Stage-2 finding 12  the exemplar carries the marker that binds both profiles ==="
# The version marker, the behaviour-free rule and fail-open-and-report bind BOTH
# profiles — they are the whole of what one marker can honestly attest. Core's
# own copy carried no marker at all, so the tool reported the repository that
# defines the contract as `unrecognised`. A rule with an unstated exemption for
# its own exemplar is advisory.
hasnt "$OUT" "unrecognised" "core's gate hook is not reported unrecognised"

echo
echo "=== Stage-2 finding 7  the shimmed-hook set is declared, not hardcoded ==="
# The installer and the provisioning check both read a declaration because a set
# derived in more than one place drifts. The conformance tool hardcoded its own.
DECL="$ROOT/reference-implementations/project-hooks/SHIMMED-HOOKS"
if [ -f "$DECL" ]; then
  ok "a shimmed-hook declaration exists at $(basename "$DECL")"
  for h in database-sentinel normalize-claude-md openspec-change-gate; do
    grep -qx "$h" "$DECL" && ok "…and declares $h" || bad "…and declares $h"
  done
else
  bad "a shimmed-hook declaration exists" "no file at $DECL"
fi

echo
echo "=== 7.6a  the fleet is DECLARED, and --fleet makes propagation reproducible ==="
# Stage-2 remediation follow-up. A contract bump must be "verified rather than
# assumed to have been reached" in every binder — but the verification was a
# scratchpad script and a list of paths typed into this file, so nothing in the
# repository could re-run it, and a repo missing from the list would have been
# indistinguishable from a repo that passed.
#
# This is finding 7 one level up: an expected set discovered from what you found
# cannot detect a missing member. ARTIFACTS and SHIMMED-HOOKS exist for that
# reason; FLEET is the same answer for the repositories.
FDECL="$ROOT/reference-implementations/project-hooks/FLEET"
if [ -f "$FDECL" ]; then
  ok "a fleet declaration exists at $(basename "$FDECL")"
  for r in agenticapps-dashboard agenticapps-roadmap agents-task-viewer \
           callbot cparx fbc-platform fx-signal-agent; do
    grep -qx "$r" "$FDECL" && ok "…and declares $r" || bad "…and declares $r"
  done
else
  bad "a fleet declaration exists" "no file at $FDECL"
fi

# --fleet resolves the declared repositories under a root and reports any that
# are ABSENT. Absent must be a finding, not silence: silence is what makes a
# missing repo look like a passing one.
FROOT="$TMP/fleetroot"
mkdir -p "$FROOT/famA" "$FROOT/famB"
P=$(mkproject fleet-present "$TEMPLATE_VERSION")
mv "$P" "$FROOT/famA/agenticapps-dashboard"
OUT=$("$TOOL" --fleet "$FROOT" 2>&1)
has "$OUT" "agenticapps-dashboard" "--fleet reports a declared repository it found"
has_re "$OUT" 'FLEET.*(callbot|cparx).*(not found|absent|missing)' \
  "--fleet reports a declared repository that is ABSENT under the root"

# A declaration that is missing entirely must refuse, for the same reason the
# shimmed-hook declaration does: scanning an empty set reports everything green.
OUT=$(FLEET_DECL="$TMP/no-such-fleet-file" "$TOOL" --fleet "$FROOT" 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "--fleet refuses when the declaration is missing (exit $rc)" \
                || bad "--fleet refuses when the declaration is missing" "exited 0"

echo
echo "=== 2.7d  the baseline: the real seven start green on this vector ==="
# Verifies the "no project sets env today" claim rather than restating it.
# Scoped honestly: this asserts the settings.json vector across the real repos
# only when they are present on this machine.
# The repositories come from FLEET, not from a list typed here. This block used
# to hardcode seven absolute paths — a third enumeration of a set that ARTIFACTS
# and SHIMMED-HOOKS had already been created to stop duplicating, and one that
# would have gone on reporting the baseline green if a repository were quietly
# dropped from it.
SRCROOT="${FLEET_SEARCH_ROOT:-$(cd "$ROOT/../.." 2>/dev/null && pwd)}"
DECLARED=0
REAL=()
while IFS= read -r line; do
  line="${line%%#*}"
  line="$(printf '%s' "$line" | tr -d '[:space:]')"
  [ -n "$line" ] || continue
  DECLARED=$((DECLARED + 1))
  d=$(find "$SRCROOT" -maxdepth 2 -type d -name "$line" 2>/dev/null | head -1)
  [ -n "$d" ] && [ -d "$d/.claude" ] && REAL+=("$d")
done < "$FDECL"
if [ "$DECLARED" -gt 0 ] && [ "${#REAL[@]}" -eq "$DECLARED" ]; then
  OUT=$("$TOOL" --overrides-only "${REAL[@]}" 2>&1)
  if printf '%s' "$OUT" | grep -q 'OVERRIDE-VECTOR'; then
    bad "the seven real projects set no override today" \
        "found: $(printf '%s' "$OUT" | grep 'OVERRIDE-VECTOR' | head -3)"
  else
    ok "the $DECLARED declared repositories set no override today (all known vectors)"
  fi
else
  echo "  SKIP  baseline across the declared fleet — found ${#REAL[@]} of $DECLARED on this machine"
fi

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
