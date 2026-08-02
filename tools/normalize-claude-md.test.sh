#!/usr/bin/env bash
# normalize-claude-md.test.sh — golden tests for the canonical
# normalize-claude-md implementation.
#
# PORTED FROM claude-workflow, and the port is the point.
#
# These fixtures used to live at claude-workflow/migrations/test-fixtures/0010/
# and were driven against claude-workflow/templates/.claude/hooks/normalize-claude-md.sh.
# shim-project-hooks turned that file into a shim, so the tests began failing
# against a script that no longer contains the behaviour they describe.
#
# Deleting them would have been the easy move and would have silently dropped
# real coverage — seven-block normalization, a missing-source preserve, the
# 0009-vendored interaction, a line-count ceiling, CRLF input, and atomic write.
# The behaviour moved to core, so the tests move to core with it.
#
# Usage: tools/normalize-claude-md.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$ROOT/reference-implementations/project-hooks/normalize-claude-md.sh"
FIXTURES="$SCRIPT_DIR/fixtures/normalize-claude-md"

pass=0
fail=0
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT

if [ ! -x "$SCRIPT" ]; then
  echo "  FAIL  precondition: $SCRIPT not found or not executable"
  exit 1
fi
if [ ! -d "$FIXTURES" ]; then
  echo "  FAIL  precondition: fixtures not found at $FIXTURES"
  exit 1
fi

# Each scenario gets its own temp dir, and the script runs with CWD set to it so
# the source-existence checks resolve against the fixture rather than this repo.
run_normalize() {
  local scenario="$1"
  local tmp="$TMPROOT/$scenario"
  mkdir -p "$tmp"
  cp -R "$FIXTURES/$scenario/." "$tmp/"
  rm -rf "$tmp/expected"
  ( cd "$tmp" && "$SCRIPT" "$tmp/CLAUDE.md" >/dev/null 2>&1 )
  printf '%s' "$tmp"
}

assert_diff() {
  local label="$1" actual="$2" expected="$3"
  if diff -u "$expected" "$actual" >/dev/null 2>&1; then
    echo "  PASS  $label"; pass=$((pass + 1))
  else
    echo "  FAIL  $label — diff against expected:"
    diff -u "$expected" "$actual" 2>&1 | head -25 | sed 's/^/        /'
    fail=$((fail + 1))
  fi
}

assert_line_count_le() {
  local label="$1" file="$2" max="$3" count
  count="$(wc -l < "$file" | tr -d ' ')"
  if [ "$count" -le "$max" ]; then
    echo "  PASS  $label (got $count, max $max)"; pass=$((pass + 1))
  else
    echo "  FAIL  $label (got $count, max $max)"; fail=$((fail + 1))
  fi
}

echo "=== golden scenarios ==="
for scenario in fresh inlined-7-sections inlined-source-missing with-0009-vendored; do
  [ -d "$FIXTURES/$scenario" ] || { echo "  SKIP  $scenario (no fixture)"; continue; }
  out="$(run_normalize "$scenario")"
  if [ -f "$FIXTURES/$scenario/expected/CLAUDE.md" ]; then
    assert_diff "$scenario" "$out/CLAUDE.md" "$FIXTURES/$scenario/expected/CLAUDE.md"
  else
    echo "  SKIP  $scenario (no expected/)"
  fi
done

echo
echo "=== cparx-shape: normalization must actually shrink the file ==="
if [ -d "$FIXTURES/cparx-shape" ]; then
  out="$(run_normalize cparx-shape)"
  assert_line_count_le "cparx-shape: normalized output <= 200 lines" "$out/CLAUDE.md" 200
fi

echo
echo "=== CRLF input still normalizes ==="
# The regex must match marker lines that carry a trailing CR. A CRLF file that
# silently fails to normalize is the worst outcome: the hook reports success and
# changes nothing.
if [ -d "$FIXTURES/inlined-7-sections" ]; then
  tmp="$TMPROOT/crlf"; mkdir -p "$tmp"
  cp -R "$FIXTURES/inlined-7-sections/." "$tmp/"; rm -rf "$tmp/expected"
  perl -pe 's/\n/\r\n/' "$FIXTURES/inlined-7-sections/CLAUDE.md" > "$tmp/CLAUDE.md"
  before=$(wc -l < "$tmp/CLAUDE.md" | tr -d ' ')
  ( cd "$tmp" && "$SCRIPT" "$tmp/CLAUDE.md" >/dev/null 2>&1 )
  after=$(wc -l < "$tmp/CLAUDE.md" | tr -d ' ')
  if [ "$after" -lt "$before" ]; then
    echo "  PASS  CRLF input normalizes ($before -> $after lines)"; pass=$((pass + 1))
  else
    echo "  FAIL  CRLF input did NOT normalize ($before -> $after lines)"; fail=$((fail + 1))
  fi
fi

echo
echo "=== the write is atomic: no partial file, no stray temp ==="
if [ -d "$FIXTURES/inlined-7-sections" ]; then
  out="$(run_normalize inlined-7-sections)"
  strays=$(find "$out" -maxdepth 1 -name 'CLAUDE.md.*' | wc -l | tr -d ' ')
  [ "$strays" -eq 0 ] && { echo "  PASS  no temp file left beside CLAUDE.md"; pass=$((pass + 1)); } \
                      || { echo "  FAIL  $strays temp file(s) left beside CLAUDE.md"; fail=$((fail + 1)); }
  [ -s "$out/CLAUDE.md" ] && { echo "  PASS  CLAUDE.md is non-empty after the rewrite"; pass=$((pass + 1)); } \
                          || { echo "  FAIL  CLAUDE.md was truncated"; fail=$((fail + 1)); }
fi

echo
echo "=== the rewrite preserves the file's mode ==="
# Stage-2 finding 1. The write goes through mktemp (0600) and `mv`, and
# rename(2) makes the destination NAME refer to the temp file's inode — so the
# result carries the TEMP file's mode, not the original's. The comment at the
# write site claimed the opposite for as long as this file has existed.
#
# 0644 in, 0644 out. A hook that quietly makes every project's CLAUDE.md
# owner-only is changing something nobody asked it to change.
if [ -d "$FIXTURES/inlined-7-sections" ]; then
  tmp="$TMPROOT/mode"; mkdir -p "$tmp"
  cp -R "$FIXTURES/inlined-7-sections/." "$tmp/"; rm -rf "$tmp/expected"
  chmod 0644 "$tmp/CLAUDE.md"
  ( cd "$tmp" && "$SCRIPT" "$tmp/CLAUDE.md" >/dev/null 2>&1 )
  mode=$(stat -f '%Lp' "$tmp/CLAUDE.md" 2>/dev/null || stat -c '%a' "$tmp/CLAUDE.md" 2>/dev/null)
  if [ "$mode" = "644" ]; then
    echo "  PASS  a 0644 CLAUDE.md is still 0644 after the rewrite"; pass=$((pass + 1))
  else
    echo "  FAIL  a 0644 CLAUDE.md is still 0644 after the rewrite (got $mode)"; fail=$((fail + 1))
  fi

  # And a deliberately restrictive mode survives too — the fix must carry the
  # original mode across, not hardcode 0644.
  tmp="$TMPROOT/mode600"; mkdir -p "$tmp"
  cp -R "$FIXTURES/inlined-7-sections/." "$tmp/"; rm -rf "$tmp/expected"
  chmod 0600 "$tmp/CLAUDE.md"
  ( cd "$tmp" && "$SCRIPT" "$tmp/CLAUDE.md" >/dev/null 2>&1 )
  mode=$(stat -f '%Lp' "$tmp/CLAUDE.md" 2>/dev/null || stat -c '%a' "$tmp/CLAUDE.md" 2>/dev/null)
  if [ "$mode" = "600" ]; then
    echo "  PASS  a 0600 CLAUDE.md is still 0600 after the rewrite"; pass=$((pass + 1))
  else
    echo "  FAIL  a 0600 CLAUDE.md is still 0600 after the rewrite (got $mode)"; fail=$((fail + 1))
  fi
fi

echo
echo "=== idempotent: running twice changes nothing the second time ==="
if [ -d "$FIXTURES/inlined-7-sections" ]; then
  out="$(run_normalize inlined-7-sections)"
  cp "$out/CLAUDE.md" "$TMPROOT/once.md"
  ( cd "$out" && "$SCRIPT" "$out/CLAUDE.md" >/dev/null 2>&1 )
  if diff -q "$TMPROOT/once.md" "$out/CLAUDE.md" >/dev/null 2>&1; then
    echo "  PASS  second run is a no-op"; pass=$((pass + 1))
  else
    echo "  FAIL  second run changed the file"; fail=$((fail + 1))
  fi
fi

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
