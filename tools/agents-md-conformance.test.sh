#!/usr/bin/env bash
# agents-md-conformance.test.sh — pin agents-md-conformance.sh in BOTH
# directions.
#
# WHY THIS EXISTS
#
# A conformance harness has two ways to be wrong and only one of them is
# obvious. Missing a violation is the failure everyone tests for. Rejecting a
# layout that is actually valid is the one that gets shipped, because the
# harness is red, red looks like it is working, and the false positive is
# indistinguishable from a finding until someone reads the rule.
#
# This repo has already paid for the second kind twice. The `sed -i`
# portability bug reversed itself depending on whose sed you had, so each
# spelling read as correct to whoever wrote it. And during this harness's own
# development the "warnings must not fail the run" row compared a raw failure
# count, so it fired on every file that also had a legitimate host-path failure
# — the check accusing the run of the exact defect it existed to disprove.
#
# So every row below is asserted with an expected VERDICT, not merely an
# expected exit code, and the conformant fixtures are as load-bearing as the
# violating ones.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
HARNESS="tools/agents-md-conformance.sh"
[ -f "$HARNESS" ] || { echo "missing $HARNESS" >&2; exit 2; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/amc-test.XXXXXX")"
trap 'rm -rf "$FX"' EXIT

pass=0; fail=0
ok() { echo "  PASS  $1"; pass=$((pass+1)); }
no() { echo "  FAIL  $1"; fail=$((fail+1)); }

OUT="$FX/out.txt"

run_harness() { # $@ = args; leaves output in $OUT, returns harness exit
  bash "$HARNESS" "$@" >"$OUT" 2>&1
}

# Assert a row matching $2 reported verdict $1. Matching on the row TEXT rather
# than a line number, so reordering rows does not silently retarget an assertion
# at a different requirement.
expect_row() { # $1 = PASS|FAIL|WARN|INCONCLUSIVE, $2 = substring, $3 = label
  if grep -q "^  $1  .*$2" "$OUT" 2>/dev/null; then
    ok "$3"
  else
    no "$3 — no '$1' row matching '$2'"
    grep -E "$2" "$OUT" 2>/dev/null | sed 's/^/          got: /' | head -3
  fi
}

expect_exit() { # $1 = expected, $2 = actual, $3 = label
  if [ "$1" = "$2" ]; then ok "$3 (exit $2)"; else no "$3 — expected exit $1, got $2"; fi
}

# ── Fixtures ────────────────────────────────────────────────────────────────

mk_good() { cat > "$1" <<'EOF'
---
agents:
  codex: .codex/AGENTS.md
  pi: .pi/AGENTS.md
---

# Project

Unrelated prose that must survive removal.

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Development Workflow

This project uses the AgenticApps spec-first OpenSpec workflow. Work is a
change: propose, validate, review, apply, verify, archive, ship.

<!-- END: agentic-apps-workflow sections -->

Trailing prose.
EOF
}

echo "═══ A. A conformant file is accepted"
# The direction that matters most. Every row here is a rule that must NOT fire.
mk_good "$FX/good.md"
run_harness "$FX/good.md"; rc=$?
expect_exit 0 "$rc" "conformant file exits 0"
expect_row PASS "exactly one workflow section"            "single-section rule does not fire on a valid file"
expect_row PASS "no duplicate workflow sections"          "duplicate rule does not fire on a valid file"
expect_row PASS "located by markers alone"                "locatability confirmed without heading text"
expect_row PASS "every byte outside the markers unchanged" "removal purity confirmed"
expect_row PASS "no known host identifier in the section" "neutrality rule does not fire on neutral prose"
expect_row PASS "no host-specific paths in the section"   "host-path rule does not fire on a valid file"
expect_row PASS "carry a path, not a bare identifier"     "link entries accepted when they carry paths"
if grep -q "^  WARN" "$OUT"; then
  no "a conformant file produced a warning"
else
  ok "a conformant file produced no warnings"
fi

echo "═══ B. The cparx duplicate state is reported, never collapsed"
# Rebuilt from the two real blocks: same marker, same heading, drifted step
# names. The drift is what makes collapsing them a silent choice.
cat > "$FX/dup.md" <<'EOF'
---
agents:
  codex: .codex/AGENTS.md
  opencode: .opencode/AGENTS.md
---
<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
## Development Workflow
Route medium tasks through discuss, plan, then execute-plan.
<!-- END: agentic-apps-workflow sections -->

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
## Development Workflow
Route medium tasks through discuss, plan, then execute-phase.
<!-- END: agentic-apps-workflow sections -->
EOF
run_harness "$FX/dup.md"; rc=$?
expect_exit 1 "$rc" "duplicate sections fail the run"
expect_row FAIL "duplicate workflow sections" "duplicate sections reported"
if grep -q "block 1: lines" "$OUT" && grep -q "block 2: lines" "$OUT"; then
  ok "both blocks reported with line ranges"
else
  no "both blocks were not reported with line ranges"
fi
# The whole point of the decision: the harness must not pick a winner.
if grep -qi -e 'collapsed' -e 'resolve by hand' "$OUT"; then
  ok "report says the blocks were not collapsed"
else
  no "report does not say the blocks were left uncollapsed"
fi
n_before=$(wc -l < "$FX/dup.md")
run_harness "$FX/dup.md" || true
if [ "$(wc -l < "$FX/dup.md")" -eq "$n_before" ]; then
  ok "the harness did not modify the file it scored"
else
  no "the harness modified the file it scored"
fi

echo "═══ C. A host identifier warns; a host path fails"
# The severity split is the requirement. A name may appear in neutral prose by
# coincidence; a path cannot, so names warn and paths fail.
cat > "$FX/warnonly.md" <<'EOF'
---
agents:
  codex: .codex/AGENTS.md
---
<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
## Development Workflow
This project uses the AgenticApps workflow on the codex host.
<!-- END: agentic-apps-workflow sections -->
EOF
run_harness "$FX/warnonly.md"; rc=$?
expect_exit 0 "$rc" "a host identifier alone does NOT fail the run"
expect_row WARN "host identifier 'codex' in section body" "host identifier reported at warning severity"
expect_row PASS "did not contribute to the failure count" "warning attribution asserted as its own row"

cat > "$FX/hostpath.md" <<'EOF'
---
agents:
  codex: .codex/AGENTS.md
---
<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
## Development Workflow
The version stamp lives at .codex/workflow-version.txt.
<!-- END: agentic-apps-workflow sections -->
EOF
run_harness "$FX/hostpath.md"; rc=$?
expect_exit 1 "$rc" "a host path in the section DOES fail the run"
expect_row FAIL "host path '.codex/' in section body" "host path reported as a failure"
# Regression pin for the bug this harness shipped with: the attribution row
# compared a raw failure count and fired whenever a legitimate path failure
# was also present.
expect_row PASS "did not contribute to the failure count" \
  "warning attribution stays correct alongside a real path failure"

echo "═══ D. Links are exempt from the neutrality check"
# Not a refinement but a correctness condition: a check that flagged the links
# would fire on the one thing §12 explicitly permits.
run_harness "$FX/good.md"
expect_row PASS "known host identifier(s) present in the links, none warned on" \
  "host names in links produce no warning"

echo "═══ E. An entry must be a link, not an inventory"
cat > "$FX/bare.md" <<'EOF'
---
agents:
  codex: codex
  pi: pi
---
<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
## Development Workflow
Propose, validate, review, apply, verify, archive.
<!-- END: agentic-apps-workflow sections -->
EOF
run_harness "$FX/bare.md"; rc=$?
expect_exit 1 "$rc" "bare identifiers fail the run"
expect_row FAIL "inventory, not links" "bare identifiers reported as inventory"

echo "═══ F. CLAUDE.md is never scored by any row"
mk_good "$FX/CLAUDE.md"
run_harness "$FX/CLAUDE.md"; rc=$?
expect_exit 2 "$rc" "CLAUDE.md is refused"
if grep -q "OUT-OF-SCOPE" "$OUT"; then
  ok "CLAUDE.md refusal names the reason"
else
  no "CLAUDE.md refusal does not name the reason"
fi
# The requirement is that NO row scores it — a refusal that still scored rows
# would satisfy the exit code and violate the rule.
if grep -qE "^  (PASS|FAIL|WARN)" "$OUT"; then
  no "CLAUDE.md produced scored rows"
else
  ok "CLAUDE.md produced no scored rows at all"
fi

echo "═══ G. Unscoreable targets abort, distinguishably"
run_harness "$FX/does-not-exist.md"; rc=$?
expect_exit 2 "$rc" "missing target aborts"
grep -q "UNSCOREABLE.*not found" "$OUT" && ok "missing target reported as not found" \
  || no "missing target not reported as not found"

: > "$FX/empty.md"
run_harness "$FX/empty.md"; rc=$?
expect_exit 2 "$rc" "empty target aborts"
grep -q "UNSCOREABLE.*empty" "$OUT" && ok "empty target reported as empty" \
  || no "empty target not reported as empty"

mkdir -p "$FX/adir.md"
run_harness "$FX/adir.md"; rc=$?
expect_exit 2 "$rc" "directory target aborts"
grep -q "UNSCOREABLE.*not a regular file" "$OUT" && ok "directory reported as not a regular file" \
  || no "directory not reported as not a regular file"

bash "$HARNESS" >"$OUT" 2>&1; rc=$?
expect_exit 2 "$rc" "no argument aborts with usage"

echo "═══ H. Lifecycle rows are inconclusive, not skipped, without a host"
run_harness "$FX/good.md"
expect_row INCONCLUSIVE "5.1 add is idempotent" "lifecycle rows named when unscoreable"
if grep -q "excluded from the scored total" "$OUT"; then
  ok "inconclusive rows are excluded from the scored total (§20)"
else
  no "inconclusive rows are not reported as excluded from the scored total"
fi
# §20: a run that determined nothing must never exit 0. Here rows DID score, so
# the total is legitimate — this pins that inconclusive rows did not inflate it.
if grep -qE "TOTAL: [1-9][0-9]* passed" "$OUT"; then
  ok "scored total counts only rows that reached a verdict"
else
  no "scored total is zero or unparseable"
fi

# ── A conformant reference host, so section E can be scored in both directions ─
# Core cannot provision an agent into a repo it does not own, so the lifecycle
# rows are unreachable without one. This fake host is the smallest thing that
# satisfies the contract; the non-conformant one below is the same script with
# the three specific defects the spec exists to forbid.

SECTION_FIXTURE="$FX/section.txt"
cat > "$SECTION_FIXTURE" <<'EOF'
<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Development Workflow

This project uses the AgenticApps spec-first OpenSpec workflow. Work is a
change: propose, validate, review, apply, verify, archive, ship.

<!-- END: agentic-apps-workflow sections -->
EOF

# awk throughout, never `sed -i`: an in-place edit is the one construct whose
# spelling differs between BSD and GNU, and migration lint rule L11 rejects it.
cat > "$FX/host-add.sh" <<AWKEOF
#!/usr/bin/env bash
set -uo pipefail
repo="\$1"; agent="\$2"; dir="\$repo/.\$agent"; f="\$repo/AGENTS.md"
if [ -d "\$dir" ]; then echo "agent \$agent is already present — no-op"; exit 0; fi
mkdir -p "\$dir"
printf '# %s — host binding\n' "\$agent" > "\$dir/AGENTS.md"
[ -f "\$f" ] || : > "\$f"
if ! grep -q 'BEGIN: agentic-apps-workflow sections' "\$f"; then
  printf '\n' >> "\$f"; cat "$SECTION_FIXTURE" >> "\$f"
fi
tmp="\$(mktemp)"
if [ "\$(sed -n '1p' "\$f")" = "---" ]; then
  if grep -q '^agents:' "\$f"; then
    awk -v a="\$agent" '/^agents:/{print; printf "  %s: .%s/AGENTS.md\n", a, a; next} {print}' "\$f" > "\$tmp"
  else
    awk -v a="\$agent" 'NR==1{print; printf "agents:\n  %s: .%s/AGENTS.md\n", a, a; next} {print}' "\$f" > "\$tmp"
  fi
else
  { printf -- '---\nagents:\n  %s: .%s/AGENTS.md\n---\n' "\$agent" "\$agent"; cat "\$f"; } > "\$tmp"
fi
mv "\$tmp" "\$f"
echo "provisioned \$agent"
AWKEOF

cat > "$FX/host-remove.sh" <<'AWKEOF'
#!/usr/bin/env bash
set -uo pipefail
repo="$1"; agent="$2"; dir="$repo/.$agent"; f="$repo/AGENTS.md"
had_entry=0
grep -qE "^[[:space:]]*$agent[[:space:]]*:" "$f" 2>/dev/null && had_entry=1
if [ ! -d "$dir" ] && [ "$had_entry" -eq 0 ]; then
  echo "agent $agent is not present — nothing to do"; exit 0
fi
if [ -d "$dir" ]; then
  # Report state the workflow did not install, and leave it alone.
  for owned in package.json node_modules; do
    if [ -e "$dir/$owned" ]; then
      echo "reporting: $dir/$owned is tool-owned state, left in place (not installed by the workflow)"
    fi
  done
  # Report expected artifacts that were absent rather than failing on them.
  [ -f "$dir/AGENTS.md" ] || echo "reporting: expected $dir/AGENTS.md was missing"
  for provisioned in AGENTS.md workflow-config.md workflow-version.txt session-handoff.md; do
    rm -f "$dir/$provisioned"
  done
  rmdir "$dir" 2>/dev/null || true
fi
if [ -f "$f" ]; then
  tmp="$(mktemp)"
  awk -v a="$agent" '
    /^agents:/ { inblock=1; print; next }
    inblock && /^[^ \t]/ { inblock=0 }
    inblock && $0 ~ ("^[ \t]*" a "[ \t]*:") { next }
    { print }
  ' "$f" > "$tmp"
  # Drop an agents: key left with no entries — an empty key is not an inventory
  # of nothing, it is a malformed link surface.
  awk '
    /^agents:/ { key=NR; buf=$0; next }
    key && /^[ \t]+[^ \t]/ { print buf; print; key=0; next }
    key { key=0 }
    { print }
  ' "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
  mv "$tmp" "$f"
fi
echo "removed $agent"
AWKEOF
chmod +x "$FX/host-add.sh" "$FX/host-remove.sh"

echo "═══ I. Lifecycle rows against a conformant host"
AGENTS_MD_ADD_CMD="bash $FX/host-add.sh" \
AGENTS_MD_REMOVE_CMD="bash $FX/host-remove.sh" \
  bash "$HARNESS" "$FX/good.md" >"$OUT" 2>&1; rc=$?
expect_exit 0 "$rc" "a conformant host passes every lifecycle row"
expect_row PASS "5.7 first agent adds the section and its link"        "5.7 first-agent boundary"
expect_row PASS "5.1 re-adding an agent left every file byte-identical" "5.1 add idempotency"
expect_row PASS "5.1 re-add reported the agent as already present"      "5.1 no-op is reported"
expect_row PASS "5.2 second agent left the host-neutral section"        "5.2 section untouched by a second agent"
expect_row PASS "5.2 second agent added its own link"                   "5.2 only the new link is added"
expect_row PASS "5.3 removal deleted the departing agent"               "5.3 departing agent removed"
expect_row PASS "5.3 removal left the other agent"                      "5.3 other agent untouched"
expect_row PASS "5.4 removing an absent agent changed nothing"          "5.4 absent removal is inert"
expect_row PASS "5.4 removing an absent agent reported it"              "5.4 absent removal reports"
expect_row PASS "5.8 the host-neutral section survived"                 "5.8 section outlives the last agent"
expect_row PASS "5.8 the departing link went"                           "5.8 link goes, prose preserved"
expect_row PASS "5.9 re-add to a sectioned repo added only the link"    "5.9 re-add adds only the link"
expect_row PASS "5.5 partial presence removed what was there"           "5.5 partial presence not a failure"
expect_row PASS "5.5 partial presence reported which expected"          "5.5 missing artifacts reported"
expect_row PASS "5.6 tool-owned state was left in place"                "5.6 tool-owned state preserved"
expect_row PASS "5.6 tool-owned state was reported"                     "5.6 tool-owned state reported"
if grep -q "INCONCLUSIVE  5\." "$OUT"; then
  no "lifecycle rows stayed inconclusive with a host supplied"
else
  ok "every lifecycle row reached a verdict with a host supplied"
fi

echo "═══ J. Lifecycle rows against a host with the three forbidden defects"
# Same script, three defects: it appends a second section on every add (the bug
# that produced the duplicate state), it deletes tool-owned state, and it
# removes the section when the last agent leaves.
sed -e "s|if ! grep -q 'BEGIN: agentic-apps-workflow sections' \"\$f\"; then|if true; then|" \
    "$FX/host-add.sh" > "$FX/bad-add.sh"
cat > "$FX/bad-remove.sh" <<'AWKEOF'
#!/usr/bin/env bash
set -uo pipefail
repo="$1"; agent="$2"; dir="$repo/.$agent"; f="$repo/AGENTS.md"
rm -rf "$dir"                                  # defect: deletes tool-owned state
if [ -f "$f" ]; then
  tmp="$(mktemp)"
  awk -v a="$agent" '
    /^agents:/ { inblock=1; print; next }
    inblock && /^[^ \t]/ { inblock=0 }
    inblock && $0 ~ ("^[ \t]*" a "[ \t]*:") { next }
    { print }
  ' "$f" > "$tmp"
  # defect: strips the host-neutral section too
  awk '/BEGIN: agentic-apps-workflow sections/{s=1} !s{print} /END: agentic-apps-workflow sections/{s=0}' \
    "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
  mv "$tmp" "$f"
fi
echo "removed $agent"
AWKEOF
chmod +x "$FX/bad-add.sh" "$FX/bad-remove.sh"

AGENTS_MD_ADD_CMD="bash $FX/bad-add.sh" \
AGENTS_MD_REMOVE_CMD="bash $FX/bad-remove.sh" \
  bash "$HARNESS" "$FX/good.md" >"$OUT" 2>&1; rc=$?
expect_exit 1 "$rc" "a defective host fails the run"
# The cparx bug itself. This row exists because the byte-identical comparison
# CANNOT see it: a host that appends leaves the FIRST block untouched, so
# "section unchanged" passes while the file quietly grows a second copy. The
# harness scored this defect green until this fixture proved otherwise.
expect_row FAIL "5.2 second agent appended a duplicate section" "5.2 catches an appended duplicate section"
expect_row FAIL "5.6 tool-owned state was deleted"            "5.6 catches deletion of tool-owned state"
expect_row FAIL "5.8 the host-neutral section was removed"    "5.8 catches removal of the section"

echo ""
echo "═══ TOTAL: $pass passed, $fail failed"
if [ $((pass + fail)) -eq 0 ]; then
  echo "agents-md-conformance.test: asserted NOTHING" >&2
  exit 1
fi
[ "$fail" -eq 0 ]
