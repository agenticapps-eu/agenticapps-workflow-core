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
echo "=== 2.7d  the baseline: the real seven start green on this vector ==="
# Verifies the "no project sets env today" claim rather than restating it.
# Scoped honestly: this asserts the settings.json vector across the real repos
# only when they are present on this machine.
REAL=()
for d in /Users/donald/Sourcecode/agenticapps/agenticapps-dashboard \
         /Users/donald/Sourcecode/agenticapps/agenticapps-roadmap \
         /Users/donald/Sourcecode/agenticapps/agents-task-viewer \
         /Users/donald/Sourcecode/factiv/callbot \
         /Users/donald/Sourcecode/factiv/cparx \
         /Users/donald/Sourcecode/factiv/fbc-platform \
         /Users/donald/Sourcecode/factiv/fx-signal-agent; do
  [ -d "$d/.claude" ] && REAL+=("$d")
done
if [ "${#REAL[@]}" -eq 7 ]; then
  OUT=$("$TOOL" --overrides-only "${REAL[@]}" 2>&1)
  if printf '%s' "$OUT" | grep -q 'OVERRIDE-VECTOR'; then
    bad "the seven real projects set no override today" \
        "found: $(printf '%s' "$OUT" | grep 'OVERRIDE-VECTOR' | head -3)"
  else
    ok "the seven real projects set no override today (all known vectors)"
  fi
else
  echo "  SKIP  baseline across the real seven — found ${#REAL[@]} of 7 on this machine"
fi

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
