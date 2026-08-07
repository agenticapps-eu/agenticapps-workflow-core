#!/usr/bin/env bash
# bind-openspec-tools.test.sh — the machine-level openspec binding, test-first.
#
# Covers fresh-clone-needs-nothing tasks 9.1-9.6. Written and observed RED before
# reference-implementations/openspec-tools/bind-openspec-tools.sh existed.
#
# The REAL `openspec` CLI does the generating here, deliberately. The per-host
# shapes are the whole difficulty of this task — claude nests its commands,
# opencode flattens them, codex emits none — so a doubled generator would be a
# test of my assumptions rather than of the hosts. Everything it writes lands in
# a scratch store and a scratch HOME; nothing touches the real machine.
#
# Usage: tools/bind-openspec-tools.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINDER="$ROOT/reference-implementations/openspec-tools/bind-openspec-tools.sh"

pass=0
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; fail=$((fail + 1)); }

# Same trap as the initializer's suite. Most assertions here are "was not
# created", "was not overwritten", "was not copied" — all true of a binder that
# cannot run at all.
if [ ! -x "$BINDER" ]; then
  echo "  FAIL  precondition: binder not executable at $BINDER"
  echo "        Refusing to run: the negative assertions would pass vacuously."
  echo "        This is the expected RED while the implementation does not exist."
  exit 1
fi
command -v openspec >/dev/null 2>&1 || {
  echo "  FAIL  precondition: openspec is not installed, and it is the generator"
  exit 1
}

CASE_N=0
HOME_DIR=""; STORE=""; OUT=""; RC=0
# fresh <host>... — a scratch HOME and store, then run the binder for those hosts.
fresh() {
  CASE_N=$((CASE_N + 1))
  HOME_DIR="$TMP/home-$CASE_N"
  STORE="$TMP/store-$CASE_N"
  mkdir -p "$HOME_DIR"
  local args=()
  for h in "$@"; do args+=(--host "$h"); done
  OUT=$( "$BINDER" --home "$HOME_DIR" --store "$STORE" "${args[@]}" 2>&1 )
  RC=$?
}
rerun() {
  local args=()
  for h in "$@"; do args+=(--host "$h"); done
  OUT=$( "$BINDER" --home "$HOME_DIR" --store "$STORE" "${args[@]}" 2>&1 )
  RC=$?
}

# ---------------------------------------------------------------------------
echo "A. claude — nested command directory (task 9.1)"
# ---------------------------------------------------------------------------
fresh claude
[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC" "$(printf '%s' "$OUT" | head -3)"

[ -L "$HOME_DIR/.claude/skills/openspec-propose" ] \
  && ok "a skill is bound by symlink (task 9.4)" \
  || bad "a skill is bound by symlink (task 9.4)" "missing, or copied rather than linked"

case "$(readlink "$HOME_DIR/.claude/skills/openspec-propose" 2>/dev/null)" in
  "$STORE"/*) ok "the skill link points into the store" ;;
  *) bad "the skill link points into the store" \
         "target: $(readlink "$HOME_DIR/.claude/skills/openspec-propose" 2>/dev/null)" ;;
esac

[ -e "$HOME_DIR/.claude/commands/opsx/propose.md" ] \
  && ok "claude's nested opsx commands resolve" \
  || bad "claude's nested opsx commands resolve" \
         "expected .claude/commands/opsx/propose.md"

# ---------------------------------------------------------------------------
echo
echo "B. opencode — flat, hyphenated commands (task 9.1)"
# ---------------------------------------------------------------------------
fresh opencode
[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC" "$(printf '%s' "$OUT" | head -3)"
[ -L "$HOME_DIR/.config/opencode/skills/openspec-propose" ] \
  && ok "skills bind into ~/.config/opencode/skills" \
  || bad "skills bind into ~/.config/opencode/skills" "missing"
[ -e "$HOME_DIR/.config/opencode/commands/opsx-propose.md" ] \
  && ok "commands bind flat as opsx-propose.md, not into a directory" \
  || bad "commands bind flat as opsx-propose.md, not into a directory" \
         "opencode's shape is flat and hyphenated; claude's is nested"
[ ! -e "$HOME_DIR/.config/opencode/commands/opsx/propose.md" ] \
  && ok "claude's nested shape is NOT applied to opencode" \
  || bad "claude's nested shape is NOT applied to opencode" \
         "one pattern was applied to two hosts that do not share it"

# ---------------------------------------------------------------------------
echo
echo "C. codex — a real prompt directory with nothing to put in it (task 9.5)"
# ---------------------------------------------------------------------------
fresh codex
[ "$RC" -eq 0 ] \
  && ok "an empty command surface is not a failed install" \
  || bad "an empty command surface is not a failed install" "got $RC" "$(printf '%s' "$OUT" | head -3)"
[ -L "$HOME_DIR/.codex/skills/openspec-propose" ] \
  && ok "codex skills are bound" || bad "codex skills are bound" "missing"
[ -z "$(ls -A "$HOME_DIR/.codex/prompts" 2>/dev/null)" ] \
  && ok "nothing is invented for codex's prompt directory" \
  || bad "nothing is invented for codex's prompt directory" \
         "the CLI generates no codex commands, so there is nothing to bind"
printf '%s' "$OUT" | grep -qi 'codex' \
  && ok "the empty command surface is reported" \
  || bad "the empty command surface is reported" "silence makes it indistinguishable from success"

# ---------------------------------------------------------------------------
echo
echo "D. pi — no bindable command directory anywhere (tasks 9.2, 9.2a)"
# ---------------------------------------------------------------------------
fresh pi
[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC" "$(printf '%s' "$OUT" | head -3)"
[ -L "$HOME_DIR/.pi/agent/skills/openspec-propose" ] \
  && ok "pi skills bind into ~/.pi/agent/skills" \
  || bad "pi skills bind into ~/.pi/agent/skills" "missing — note this is the corrected path, not .agents/skills"

# The measurement: pi has no global prompt directory and names none in its
# settings. It installs extensions as packages. Creating one here would be the
# same inference that left pi bound to a directory it never read.
[ ! -e "$HOME_DIR/.pi/agent/prompts" ] && [ ! -e "$HOME_DIR/.pi/prompts" ] \
  && ok "no prompt directory is invented for pi" \
  || bad "no prompt directory is invented for pi" \
         "pi writes .pi/prompts INSIDE a repo; that is not evidence about ~/"
printf '%s' "$OUT" | grep -qi 'unverified\|unconfirmed' \
  && ok "pi's command surface is recorded unverified" \
  || bad "pi's command surface is recorded unverified" "$(printf '%s' "$OUT" | head -3)"

# ---------------------------------------------------------------------------
echo
echo "E. omp — nothing established at all"
# ---------------------------------------------------------------------------
fresh omp
[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC" "$(printf '%s' "$OUT" | head -3)"
printf '%s' "$OUT" | grep -qi 'unverified\|unconfirmed' \
  && ok "omp is recorded unverified" || bad "omp is recorded unverified" "$(printf '%s' "$OUT" | head -3)"
[ ! -d "$HOME_DIR/.omp" ] \
  && ok "no directory is created for omp" \
  || bad "no directory is created for omp" "a directory was created for a host with no established path"

# ---------------------------------------------------------------------------
echo
echo "F. Binding is idempotent and never copies (tasks 9.4, and the install-twice rule)"
# ---------------------------------------------------------------------------
fresh claude opencode
first=$(cd "$HOME_DIR" && find . -type l | sort | md5 -q 2>/dev/null || cd "$HOME_DIR" && find . -type l | sort | md5sum)
rerun claude opencode
second=$(cd "$HOME_DIR" && find . -type l | sort | md5 -q 2>/dev/null || cd "$HOME_DIR" && find . -type l | sort | md5sum)
[ "$RC" -eq 0 ] && ok "second run exits zero" || bad "second run exits zero" "got $RC"
# The count guard is not decoration: comparing two EMPTY link sets is equal, so
# without it this assertion passes for a binder that binds nothing at all.
links_now=$(cd "$HOME_DIR" && find . -type l | wc -l | tr -d ' ')
[ "$first" = "$second" ] && [ "$links_now" -gt 0 ] \
  && ok "second run binds the same set" \
  || bad "second run binds the same set" "changed, or nothing was bound at all ($links_now links)"

copied=$(cd "$HOME_DIR" && find . -name 'openspec-*' -type d -not -type l 2>/dev/null | head -3)
[ -z "$copied" ] && ok "no skill is copied — every one is a link" \
  || bad "no skill is copied — every one is a link" "copied: $copied"

# ---------------------------------------------------------------------------
echo
echo "G. It leaves another tool's entries alone (co-tenancy)"
# ---------------------------------------------------------------------------
fresh claude
mkdir -p "$HOME_DIR/.claude/skills/somebody-elses"
printf 'not ours\n' > "$HOME_DIR/.claude/skills/somebody-elses/SKILL.md"
rerun claude
[ -f "$HOME_DIR/.claude/skills/somebody-elses/SKILL.md" ] \
  && ok "an unrelated skill is untouched" || bad "an unrelated skill is untouched" "it was removed"

# A name collision with a foreign entry is reported, never silently replaced —
# pi's skill directory is populated by another tool, so this is not theoretical.
rm -rf "$HOME_DIR/.claude/skills/openspec-propose"
mkdir -p "$HOME_DIR/.claude/skills/openspec-propose"
printf 'foreign\n' > "$HOME_DIR/.claude/skills/openspec-propose/SKILL.md"
rerun claude
[ -f "$HOME_DIR/.claude/skills/openspec-propose/SKILL.md" ] \
  && grep -q foreign "$HOME_DIR/.claude/skills/openspec-propose/SKILL.md" 2>/dev/null \
  && ok "a foreign entry under our own name is not overwritten" \
  || bad "a foreign entry under our own name is not overwritten" \
         "another tool's file was replaced by our link"
printf '%s' "$OUT" | grep -qi 'collision\|exists\|refus\|skip' \
  && ok "the collision is reported" || bad "the collision is reported" "$(printf '%s' "$OUT" | head -3)"

# ---------------------------------------------------------------------------
echo
echo "H. The generator is a prerequisite, and its absence is named (task 9.3)"
# ---------------------------------------------------------------------------
CASE_N=$((CASE_N + 1))
HOME_DIR="$TMP/home-$CASE_N"; STORE="$TMP/store-$CASE_N"; mkdir -p "$HOME_DIR"
OUT=$( PATH="/usr/bin:/bin" "$BINDER" --home "$HOME_DIR" --store "$STORE" --host claude 2>&1 ); RC=$?
[ "$RC" -ne 0 ] && ok "refuses when openspec is unavailable" \
  || bad "refuses when openspec is unavailable" "exited 0 with no generator"
printf '%s' "$OUT" | grep -qi 'openspec' \
  && ok "names openspec as the missing generator" || bad "names openspec as the missing generator" "$(printf '%s' "$OUT" | head -2)"
[ ! -e "$HOME_DIR/.claude/skills/openspec-propose" ] \
  && ok "binds nothing when it cannot generate" || bad "binds nothing when it cannot generate" "a link was made"

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
