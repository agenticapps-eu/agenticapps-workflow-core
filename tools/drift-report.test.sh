#!/usr/bin/env bash
# drift-report.test.sh — tests for drift-report.sh
#
# Builds synthetic host clones in a temp dir and drives drift-report.sh
# through its public interface (its one positional arg: the hosts dir).
# No network, no real clones, no writes outside the temp dir.
#
# Usage: tools/drift-report.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIFT="$SCRIPT_DIR/drift-report.sh"

pass=0
fail=0

assert_contains() { # $1=haystack $2=needle $3=description
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "  PASS  $3"
    pass=$((pass + 1))
  else
    echo "  FAIL  $3"
    echo "        expected output to contain: $2"
    fail=$((fail + 1))
  fi
}

assert_not_contains() { # $1=haystack $2=needle $3=description
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "  FAIL  $3"
    echo "        expected output NOT to contain: $2"
    fail=$((fail + 1))
  else
    echo "  PASS  $3"
    pass=$((pass + 1))
  fi
}

# Emits a host's primary instruction file: implements_spec plus the canonical
# blocks that actually live there (01, 03, 04, 05). $1 = target path, $2 =
# red-flags heading (varies per test: the leading count is not normative per
# spec 04 rule 3).
#
# Section 11 is deliberately NOT here. spec/11 binds its block to the host's
# "primary project-instruction file (CLAUDE.md, AGENTS.md, ...)" — a different
# file from the workflow SKILL.md that spec/09 item 1 binds 01/03/04/05 to.
# codex and opencode carry it in AGENTS.md behind a provenance anchor. The
# fixture mirrors that split.
write_instruction_file() {
  local target="$1"
  local red_flags_heading="${2:-## 13 Red Flags — STOP → DELETE → RESTART}"
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<EOF
---
name: agentic-apps-workflow
implements_spec: 0.9.1
---

## Step 0 — The Commitment Ritual

I am using the agentic-apps-workflow skill for this task.
Once I have stated this plan, I am committed to it.

## Rationalization Table — Check Before Skipping Anything

Skipping it is how discipline erodes.
If you didn't write them down, you didn't consider them.

$red_flags_heading

1. Code written before the test (for TDD tasks)
13. "This case is different because..."

## Pressure-Test Scenarios — Self-Check

Would a senior engineer reviewing this work accept the shortcut?
If any answer gives you pause, follow the protocol.
EOF
}

# Emits the section 11 canonical block to a host's declared secondary prose
# file. $1 = target path.
write_coding_discipline_block() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<'EOF'
## Coding Discipline (NON-NEGOTIABLE)

Think Before Coding.
These four rules are reread every session.
EOF
}

# Builds a hosts dir containing all three hosts, each fully conformant, at
# the layout drift-report declares. Echoes the dir path.
make_hosts_dir() {
  local dir
  dir="$(mktemp -d)"
  write_instruction_file "$dir/claude-workflow/skill/SKILL.md"
  write_coding_discipline_block "$dir/claude-workflow/CLAUDE.md"
  write_instruction_file "$dir/codex-workflow/skills/agentic-apps-workflow/SKILL.md"
  write_coding_discipline_block "$dir/codex-workflow/AGENTS.md"
  write_instruction_file "$dir/opencode-workflow/skills/agentic-apps-workflow/SKILL.md"
  write_coding_discipline_block "$dir/opencode-workflow/AGENTS.md"
  printf '%s' "$dir"
}

# Builds a hosts dir containing ONLY claude-workflow. The other two hosts are
# absent, so they report SKIP and emit no OK lines — which lets a test assert
# on the absence of OK lines without a conformant sibling host supplying them.
make_single_host_dir() {
  local dir
  dir="$(mktemp -d)"
  write_instruction_file "$dir/claude-workflow/skill/SKILL.md"
  write_coding_discipline_block "$dir/claude-workflow/CLAUDE.md"
  printf '%s' "$dir"
}

echo "drift-report.sh tests"
echo "====================="

# --- T1: baseline — a fully conformant host set reports no drift ----------
echo ""
echo "T1: conformant hosts report no DRIFT"
d="$(make_hosts_dir)"
out="$("$DRIFT" "$d" 2>&1)"
assert_not_contains "$out" "DRIFT [" "no DRIFT lines for conformant hosts"
rm -rf "$d"

# --- T2: the red-flags heading count is NOT normative (spec 04 rule 3) ----
# A host that appends a host-specific flag updates the leading count to its
# own total. `## 14 Red Flags — ...` is conformant and MUST NOT be drift.
echo ""
echo "T2: a non-canonical leading count in the red-flags heading is conformant"
d="$(make_hosts_dir)"
write_instruction_file "$d/claude-workflow/skill/SKILL.md" \
  "## 14 Red Flags — STOP → DELETE → RESTART"
out="$("$DRIFT" "$d" 2>&1)"
assert_not_contains "$out" "DRIFT [04-red-flags]" \
  "'## 14 Red Flags' does not report drift (count is not normative)"
rm -rf "$d"

# --- T3: a reworded red-flags heading IS drift ----------------------------
# The non-count portion of the heading is canonical and MUST NOT be reworded.
echo ""
echo "T3: a reworded red-flags heading is drift"
d="$(make_hosts_dir)"
write_instruction_file "$d/claude-workflow/skill/SKILL.md" \
  "## 13 Red Flags — Trigger Automatic STOP → DELETE → RESTART"
out="$("$DRIFT" "$d" 2>&1)"
assert_contains "$out" "DRIFT [04-red-flags]" \
  "reworded heading reports drift"
rm -rf "$d"

# --- T4: canonical prose outside the instruction file does NOT count ------
# spec 09 item 1 binds the block to the host's instruction file. Prose that
# lives only in some other tracked .md (a migration, a test fixture, a
# planning doc) must not satisfy the check.
echo ""
echo "T4: canonical prose in a non-instruction .md does not satisfy the check"
d="$(make_hosts_dir)"
write_instruction_file "$d/claude-workflow/skill/SKILL.md" \
  "## 13 Red Flags — Trigger Automatic STOP → DELETE → RESTART"
mkdir -p "$d/claude-workflow/docs"
printf '## 13 Red Flags — STOP → DELETE → RESTART\n' \
  > "$d/claude-workflow/docs/ENFORCEMENT-PLAN.md"
out="$("$DRIFT" "$d" 2>&1)"
assert_contains "$out" "DRIFT [04-red-flags]" \
  "prose in docs/ does not rescue a drifted instruction file"
rm -rf "$d"

# --- T5: canonical prose in gitignored scratch does NOT count -------------
# The live false PASS this tool shipped with: .superpowers/sdd/*.md quoting
# the old canonical phrase made the check report OK while the real
# instruction file had legitimately moved on.
echo ""
echo "T5: canonical prose in gitignored scratch does not satisfy the check"
d="$(make_hosts_dir)"
write_instruction_file "$d/claude-workflow/skill/SKILL.md" \
  "## 13 Red Flags — Trigger Automatic STOP → DELETE → RESTART"
mkdir -p "$d/claude-workflow/.superpowers/sdd"
printf '## 13 Red Flags — STOP → DELETE → RESTART\n' \
  > "$d/claude-workflow/.superpowers/sdd/task-5-report.md"
out="$("$DRIFT" "$d" 2>&1)"
assert_contains "$out" "DRIFT [04-red-flags]" \
  "scratch does not rescue a drifted instruction file"
rm -rf "$d"

# --- T6: a missing instruction file is reported loudly, not silently OK ---
echo ""
echo "T6: a missing declared instruction file is reported"
d="$(make_single_host_dir)"
rm -f "$d/claude-workflow/skill/SKILL.md"
out="$("$DRIFT" "$d" 2>&1)"
assert_contains "$out" "ERROR" "missing instruction file reports ERROR"
assert_contains "$out" "skill/SKILL.md" "the error names the file it looked for"
assert_not_contains "$out" "OK    [01-commitment-ritual]" \
  "no OK lines invented for a host with no instruction file"
rm -rf "$d"

# --- T7: an instruction file without implements_spec is not conformant ----
# spec 09 item 4: a host shipping an instruction file without this field is
# unversioned and cannot claim any conformance level.
echo ""
echo "T7: an instruction file without implements_spec is reported"
d="$(make_single_host_dir)"
grep -v '^implements_spec:' "$d/claude-workflow/skill/SKILL.md" \
  > "$d/claude-workflow/skill/SKILL.md.tmp"
mv "$d/claude-workflow/skill/SKILL.md.tmp" "$d/claude-workflow/skill/SKILL.md"
out="$("$DRIFT" "$d" 2>&1)"
assert_contains "$out" "ERROR" "unversioned instruction file reports ERROR"
assert_contains "$out" "implements_spec" \
  "the error names the missing field"
assert_not_contains "$out" "OK    [01-commitment-ritual]" \
  "an unversioned host is not scored (spec 09 item 4)"
rm -rf "$d"

# --- T8: consumer repos are not checked -----------------------------------
# agenticapps-dashboard is a consumer: it reads workflow artifacts and authors
# no canonical prose, so canonical-prose checks do not apply to it and it must
# never be scored.
#
# This test used to also assert that pi-agentic-apps-workflow is not scored,
# encoding its retirement in ADR-0019. That retirement was reversed at pi host
# v0.2.0, which added the `implements_spec` citation and the section 11 block
# whose absence was the reason for removal. pi is a scored host again, so the
# assertion is inverted rather than deleted — a bare directory with no
# instruction file must now report ERROR (spec/09 item 4), not vanish silently.
echo ""
echo "T8: consumer repos are not scored; a revived host is"
d="$(make_hosts_dir)"
mkdir -p "$d/agenticapps-dashboard"
out="$("$DRIFT" "$d" 2>&1)"
assert_not_contains "$out" "agenticapps-dashboard" "dashboard is not checked"
assert_contains "$out" "pi-agentic-apps-workflow" "pi is checked again after its v0.2.0 revival"
rm -rf "$d"

# --- T9: a declared secondary prose file satisfies its section ------------
# No host keeps section 11 in its workflow SKILL.md. codex/opencode carry it
# in AGENTS.md; claude-workflow carries it in a templates/ spec mirror. Each
# host declares where its canonical prose lives, and the check honors that.
echo ""
echo "T9: canonical prose in a host's declared secondary file satisfies the check"
d="$(make_hosts_dir)"
out="$("$DRIFT" "$d" 2>&1)"
assert_not_contains "$out" "DRIFT [11-coding-discipline]" \
  "section 11 in a declared secondary file is not drift"
rm -rf "$d"

# --- T10: removing the declared secondary file IS drift -------------------
# This is the real state of claude-workflow today: its own CLAUDE.md does not
# carry the section 11 block, so the live report shows this DRIFT.
echo ""
echo "T10: losing the declared project-instruction file reports drift"
d="$(make_single_host_dir)"
rm -f "$d/claude-workflow/CLAUDE.md"
out="$("$DRIFT" "$d" 2>&1)"
assert_contains "$out" "DRIFT [11-coding-discipline]" \
  "a project-instruction file without the block is reported as drift"
rm -rf "$d"

# --- T13: a scaffolding payload does NOT satisfy section 11 ---------------
# The trap this tool walked into once already: claude-workflow ships the
# section 11 block in templates/spec-mirrors/, which migration 0014 injects
# into CONSUMING projects. It instructs nobody in the host repo, so it must
# not satisfy the host's own section 11 check — spec/11 binds the block to the
# host's primary project-instruction file, not to what it ships to others.
echo ""
echo "T13: a templates/ payload does not satisfy section 11"
d="$(make_single_host_dir)"
rm -f "$d/claude-workflow/CLAUDE.md"
mkdir -p "$d/claude-workflow/templates/spec-mirrors"
write_coding_discipline_block \
  "$d/claude-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
out="$("$DRIFT" "$d" 2>&1)"
assert_contains "$out" "DRIFT [11-coding-discipline]" \
  "the shipped payload mirror does not rescue the host's own section 11"
rm -rf "$d"

# --- T11: the known-divergent payload copy does NOT satisfy §04 -----------
# claude-workflow ships a reworded 13-flag list in its vendored CLAUDE.md
# payload (templates/.claude/claude-md/workflow.md). Per the host's own spec
# delta that copy is NOT bound by spec/09 item 1, so it must never rescue a
# drifted instruction file. It lives outside the declared prose set.
echo ""
echo "T11: the divergent templates/ payload copy does not satisfy section 04"
d="$(make_single_host_dir)"
write_instruction_file "$d/claude-workflow/skill/SKILL.md" \
  "## 13 Red Flags — Trigger Automatic STOP → DELETE → RESTART"
mkdir -p "$d/claude-workflow/templates/.claude/claude-md"
printf '## 13 Red Flags — STOP → DELETE → RESTART\n' \
  > "$d/claude-workflow/templates/.claude/claude-md/workflow.md"
out="$("$DRIFT" "$d" 2>&1)"
assert_contains "$out" "DRIFT [04-red-flags]" \
  "the vendored payload copy does not satisfy section 04"
rm -rf "$d"

# --- T12: the result must not depend on the caller's directory ------------
# A declared path must be resolved against the HOST, never against the caller.
# An earlier revision globbed the secondary patterns unquoted, so they were
# pathname-expanded against the caller's cwd before reaching the host and the
# verdict changed with the directory you ran from. The decoy cwd below carries
# its own CLAUDE.md with no canonical prose in it: if the tool ever resolves a
# declared path against cwd again, section 11 flips to DRIFT here.
echo ""
echo "T12: results do not depend on the caller's working directory"
d="$(make_hosts_dir)"
decoy="$(mktemp -d)"
printf 'a decoy CLAUDE.md with no canonical prose\n' > "$decoy/CLAUDE.md"
out="$(cd "$decoy" && "$DRIFT" "$d" 2>&1)"
assert_not_contains "$out" "DRIFT [11-coding-discipline]" \
  "a cwd holding a same-named file does not hijack the declared path"
rm -rf "$d" "$decoy"

# --- summary --------------------------------------------------------------
echo ""
echo "====================="
echo "PASS: $pass   FAIL: $fail"
[ "$fail" -eq 0 ]
