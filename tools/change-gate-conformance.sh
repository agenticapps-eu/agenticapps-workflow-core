#!/usr/bin/env bash
# change-gate-conformance.sh — scores a §18 change-gate implementation
# against the exit-code truth table in spec/18-retargeted-change-gate.md.
#
# §18 requires the gate be "demonstrable by direct script invocation with
# simulated payloads" (spec/18, Conformance). This is that demonstration,
# executable: it builds a throwaway fixture repo, stubs the `openspec` CLI
# on PATH so `validate` can be driven green or red independently of the
# gate's own logic, and drives the gate through every row.
#
# Usage: tools/change-gate-conformance.sh <path-to-gate-script> [...]
#        tools/change-gate-conformance.sh --family     # score every host clone
#
# Exit 0 = every scored gate conforms, 1 = at least one row failed.
# Read-only with respect to the repo and the host clones: all writes land
# in a mktemp dir that is removed on exit.
#
# Sections:
#   A. Truth table (spec/18) — normative for every host. A failure here is
#      a conformance defect.
#   B. Payload shapes — the same policy rows re-driven through each host
#      runtime's payload envelope. A gate that cannot parse a shape fails
#      OPEN on that host, i.e. silently does not enforce.
#   C. Modes — `--pre-commit` / `--ci`. §18 makes the shell script "the
#      real enforcement surface ... including against a human editor";
#      these rows score the agent-agnostic floor. Reported separately
#      because a hook-only gate may legitimately not implement them.
#   D. Reviewer counting — §02/§18 count independent reviewers, not lines
#      matching a heading. Duplicate and fenced-example headings must not
#      inflate the count past the threshold.

set -uo pipefail

pass=0
fail=0
WORK=""

cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

# ── fixture construction ─────────────────────────────────────────────────────
# Builds a repo with one active change and returns its path. Callers mutate
# REVIEWS.md / the validate stub per row.
make_fixture() { # $1 = validate exit code (0 green, 1 red)
  local d rc="$1"
  d="$(mktemp -d)"
  mkdir -p "$d/stub" "$d/repo/openspec/changes/add-thing" "$d/repo/src"
  printf '#!/usr/bin/env bash\nexit %s\n' "$rc" > "$d/stub/openspec"
  chmod +x "$d/stub/openspec"
  : > "$d/repo/openspec/changes/add-thing/proposal.md"
  printf 'package main\n' > "$d/repo/src/main.go"
  ( cd "$d/repo" && git init -q . && git config user.email t@t && git config user.name t )
  printf '%s' "$d"
}

reviewers() { # $1 = change dir, remaining args = reviewer names
  local dir="$1"; shift
  local f="$dir/REVIEWS.md" n
  : > "$f"
  for n in "$@"; do printf '## Reviewer: %s\n\nLooks fine.\n\n' "$n" >> "$f"; done
}

# ── the assertion ────────────────────────────────────────────────────────────
# Runs GATE inside a fixture with the stub on PATH and compares the exit code.
run_row() { # $1=desc $2=expected $3=fixture $4=payload $5...=gate args
  local desc="$1" want="$2" fx="$3" payload="$4"; shift 4
  local got
  got="$(
    cd "$fx/repo" || exit 99
    printf '%s' "$payload" | PATH="$fx/stub:$PATH" bash "$GATE" "$@" >/dev/null 2>&1
    printf '%s' "$?"
  )"
  # Section B is only interpretable on a gate that fails OPEN on an unparsed
  # payload. A gate that fails CLOSED blocks whether or not it understood the
  # shape, so a `-> block` row passes for the wrong reason and would certify a
  # parser that never ran. Report those rows as inconclusive rather than
  # banking a false PASS.
  if [ "${ROW_NEEDS_FAILOPEN:-0}" = "1" ] && [ "$FAILS_OPEN" != "1" ]; then
    echo "  ????  $desc — inconclusive (gate fails closed; a block here does not prove the shape parsed)"
    return
  fi
  if [ "$got" = "$want" ]; then
    echo "  PASS  $desc (exit $got)"
    pass=$((pass + 1))
  else
    echo "  FAIL  $desc — expected $want, got $got"
    fail=$((fail + 1))
  fi
}

# Payload envelopes, one per host runtime.
p_claude() { printf '{"tool_input":{"file_path":"%s"}}' "$1"; }          # Claude PreToolUse
p_pi()     { printf '{"toolName":"edit","input":{"path":"%s"}}' "$1"; }  # pi tool_call
p_generic(){ printf '{"path":"%s"}' "$1"; }

score_gate() {
  # Absolutise: every row runs after a `cd` into the fixture repo, so a relative
  # gate path would resolve to nothing there and score 127 on every row.
  GATE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  echo
  echo "═══ $GATE"
  echo "    ($(wc -l < "$GATE" | tr -d ' ') lines)"

  local fx

  echo "  ── A. Truth table (spec/18) ──"
  # No active change → allow.
  fx="$(make_fixture 0)"; rm -rf "$fx/repo/openspec/changes/add-thing"
  run_row "no active change -> allow" 0 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  # OpenSpec artifact write under an unsatisfied change → allow (author the change).
  fx="$(make_fixture 0)"
  run_row "openspec artifact write -> allow" 0 "$fx" \
    "$(p_claude openspec/changes/add-thing/proposal.md)"
  rm -rf "$fx"

  # Active change, validate green, no REVIEWS.md → block.
  fx="$(make_fixture 0)"
  run_row "active change, no REVIEWS.md -> block" 2 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  # Active change, validate fails → block.
  fx="$(make_fixture 1)"; reviewers "$fx/repo/openspec/changes/add-thing" claude codex
  run_row "validate FAILS (reviewed) -> block" 2 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  # Active change, validate green, >=2 reviewers → allow.
  fx="$(make_fixture 0)"; reviewers "$fx/repo/openspec/changes/add-thing" claude codex
  run_row "validate green + 2 reviewers -> allow" 0 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  # Documented escape hatch → allow.
  fx="$(make_fixture 0)"
  GSD_SKIP_REVIEWS=1 run_row "GSD_SKIP_REVIEWS=1 -> allow" 0 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  # Fail OPEN on parse error — never on policy.
  fx="$(make_fixture 0)"
  local before="$fail"
  run_row "garbage stdin -> allow (fail-open)" 0 "$fx" 'not json {{{'
  run_row "empty stdin -> allow (fail-open)"   0 "$fx" ''
  [ "$fail" -eq "$before" ] && FAILS_OPEN=1 || FAILS_OPEN=0
  rm -rf "$fx"

  echo "  ── B. Payload shapes (code edit under an unsatisfied change -> block) ──"
  ROW_NEEDS_FAILOPEN=1
  # A shape the gate cannot parse yields no path, so it fails OPEN and the
  # gate silently does not enforce on that host. Driving a *code* edit (not an
  # artifact write) is what discriminates: under fail-open both exit 0.
  fx="$(make_fixture 0)"
  run_row "Claude  {tool_input.file_path} -> block" 2 "$fx" "$(p_claude src/main.go)"
  run_row "pi      {input.path}           -> block" 2 "$fx" "$(p_pi src/main.go)"
  run_row "generic {path}                 -> block" 2 "$fx" "$(p_generic src/main.go)"
  rm -rf "$fx"
  ROW_NEEDS_FAILOPEN=0

  echo "  ── C. Modes: the agent-agnostic floor (advisory) ──"
  fx="$(make_fixture 0)"
  ( cd "$fx/repo" && git add src/main.go >/dev/null 2>&1 )
  run_row "--pre-commit, code staged, unsatisfied -> block" 1 "$fx" '' --pre-commit
  run_row "--ci, unsatisfied change -> fail"                1 "$fx" '' --ci
  rm -rf "$fx"

  fx="$(make_fixture 0)"
  ( cd "$fx/repo" && git add openspec >/dev/null 2>&1 )
  run_row "--pre-commit, only openspec staged -> allow" 0 "$fx" '' --pre-commit
  rm -rf "$fx"

  echo "  ── D. Reviewer counting ──"
  # Two headings naming the SAME reviewer is one independent reviewer.
  fx="$(make_fixture 0)"; reviewers "$fx/repo/openspec/changes/add-thing" claude claude
  run_row "duplicate reviewer counts once -> block" 2 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  # A heading inside a fenced code block is an example, not a reviewer.
  fx="$(make_fixture 0)"
  {
    printf '## Reviewer: claude\n\nReal.\n\n'
    printf 'Template for reviewers to copy:\n\n```markdown\n## Reviewer: codex\n```\n'
  } > "$fx/repo/openspec/changes/add-thing/REVIEWS.md"
  run_row "fenced example is not a reviewer -> block" 2 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  echo "  ── E. Self-review exclusion (OPENSPEC_GATE_SELF; advisory) ──"
  # The implementing host reviewing its own change is not an independent second
  # opinion. A gate that counts it disagrees with the §02 evidence verifier,
  # which rejects it — the ADR-0018 drift pattern, inside the tooling.
  fx="$(make_fixture 0)"; reviewers "$fx/repo/openspec/changes/add-thing" pi claude
  OPENSPEC_GATE_SELF=pi run_row "self + 1 other = 1 independent -> block" 2 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  fx="$(make_fixture 0)"; reviewers "$fx/repo/openspec/changes/add-thing" pi claude codex
  OPENSPEC_GATE_SELF=pi run_row "self + 2 others = 2 independent -> allow" 0 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"

  # Anchored: a reviewer whose name merely starts with the host's is not swallowed.
  fx="$(make_fixture 0)"; reviewers "$fx/repo/openspec/changes/add-thing" pi pilot-crew claude
  OPENSPEC_GATE_SELF=pi run_row "exclusion is anchored, not a prefix -> allow" 0 "$fx" "$(p_claude src/main.go)"
  rm -rf "$fx"
}

# ── entry point ──────────────────────────────────────────────────────────────
if [ "${1:-}" = "--family" ]; then
  FAMILY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  set --
  for c in \
    "$FAMILY/agenticapps-workflow-core/gate/openspec-change-gate.sh" \
    "$FAMILY/claude-workflow/bin/openspec-change-gate.sh" \
    "$FAMILY/codex-workflow/bin/openspec-change-gate.sh" \
    "$FAMILY/opencode-workflow/bin/openspec-change-gate.sh" \
    "$FAMILY/pi-agentic-apps-workflow/bin/openspec-change-gate.sh" \
    "$HOME/.agenticapps/bin/openspec-change-gate.sh"
  do [ -f "$c" ] && set -- "$@" "$c"; done
fi

[ "$#" -gt 0 ] || { echo "usage: $0 <gate-script> [...] | --family" >&2; exit 2; }

for g in "$@"; do
  [ -f "$g" ] || { echo "  SKIP  $g (not found)"; continue; }
  score_gate "$g"
done

echo
echo "═══ $pass passed, $fail failed"
[ "$fail" -eq 0 ]
