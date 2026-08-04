#!/usr/bin/env bash
# migration-runner.test.sh — tests for reference-implementations/migration-runner/
#
# Drives each script through its public interface against fixtures in a temp
# dir. No network, no writes outside the temp dir.
#
# Usage: tools/migration-runner.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MR="$ROOT/reference-implementations/migration-runner"
FIX="$MR/test-fixtures"

# Every fixture's filename carries its own `<id>-slug.md` prefix directly —
# no fixture is exercised through a renamed temp copy. The one exception is
# unparseable-filename.md, whose entire purpose is to lack a numeric prefix;
# that one fixture is committed exactly as-is rather than synthesized, since
# synthesizing it would need a temp dir this file otherwise has no use for.
pass=0
fail=0

assert_eq() { # $1=actual $2=expected $3=description
  if [ "$1" = "$2" ]; then
    echo "  PASS  $3"; pass=$((pass + 1))
  else
    echo "  FAIL  $3"
    echo "        expected: [$2]"
    echo "        actual:   [$1]"
    fail=$((fail + 1))
  fi
}

assert_contains() { # $1=haystack $2=needle $3=description
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "  PASS  $3"; pass=$((pass + 1))
  else
    echo "  FAIL  $3"
    echo "        expected output to contain: $2"
    echo "        actual: $1"
    fail=$((fail + 1))
  fi
}

assert_not_contains() { # $1=haystack $2=needle $3=description
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "  FAIL  $3"
    echo "        expected output NOT to contain: $2"
    fail=$((fail + 1))
  else
    echo "  PASS  $3"; pass=$((pass + 1))
  fi
}

tree_snapshot() { # $1=dir -> relative-path + checksum for every file, sorted
  ( cd "$1" && find . -type f -print0 | xargs -0 shasum | sort )
}

echo "== extract.sh =="

out="$(bash "$MR/extract.sh" steps "$FIX/0016-conformant.md")"
assert_eq "$out" "$(printf '1\n2')" "steps lists both steps in order"

out="$(bash "$MR/extract.sh" roles "$FIX/0016-conformant.md" 1)"
assert_eq "$out" "$(printf 'check\nprecondition\napply\nverify\nrollback')" \
  "roles lists step 1's five roles in document order"

out="$(bash "$MR/extract.sh" roles "$FIX/0016-conformant.md" 2)"
assert_eq "$out" "$(printf 'check\nprecondition\napply\nrollback')" \
  "roles omits verify where absent"

out="$(bash "$MR/extract.sh" block "$FIX/0016-conformant.md" 1 apply)"
assert_eq "$out" 'echo "applied" > fixture.txt' "block returns step 1 apply body"

out="$(bash "$MR/extract.sh" block "$FIX/0016-conformant.md" 2 apply)"
assert_eq "$out" 'echo "second" >> fixture.txt' "block scopes to step 2, not step 1"

bash "$MR/extract.sh" block "$FIX/0016-conformant.md" 2 verify >/dev/null 2>&1
assert_eq "$?" "1" "block exits 1 for an absent role"

echo "== extract.sh regression fixtures =="

# Regression guard for the phantom-step defect: mr_steps must track fence
# state, exactly like mr_roles/mr_block do. A heredoc in an apply block whose
# body contains the literal line "### Step 2" must not be read as a heading.
out="$(bash "$MR/extract.sh" steps "$FIX/0031-heredoc-step-heading.md")"
assert_eq "$out" "1" \
  "steps on heredoc fixture returns exactly 1, no phantom step from the heredoc heading line"

out="$(bash "$MR/extract.sh" block "$FIX/0031-heredoc-step-heading.md" 1 apply)"
expected="$(printf '%s\n' "cat <<'INNER' > out.txt" "### Step 2" "INNER" "echo done >> out.txt")"
assert_eq "$out" "$expected" \
  "block on heredoc fixture returns the whole heredoc including its ### Step 2 line"

# A gap in step numbering (1, 3 — no 2) must not merge the two steps or
# synthesize a phantom step 2.
out="$(bash "$MR/extract.sh" steps "$FIX/0028-bad-nonconsecutive-steps.md")"
assert_eq "$out" "$(printf '1\n3')" \
  "steps on non-consecutive fixture returns 1 and 3, gap does not synthesize step 2"

out="$(bash "$MR/extract.sh" roles "$FIX/0028-bad-nonconsecutive-steps.md" 1)"
assert_eq "$out" "$(printf 'check\nprecondition\napply\nverify\nrollback')" \
  "non-consecutive fixture: step 1 roles resolve correctly"

out="$(bash "$MR/extract.sh" roles "$FIX/0028-bad-nonconsecutive-steps.md" 3)"
assert_eq "$out" "$(printf 'check\nprecondition\napply\nverify\nrollback')" \
  "non-consecutive fixture: step 3 roles resolve correctly"

out="$(bash "$MR/extract.sh" block "$FIX/0028-bad-nonconsecutive-steps.md" 1 apply)"
assert_eq "$out" 'echo "one" > fixture.txt' \
  "non-consecutive fixture: step 1 apply block resolves correctly"

out="$(bash "$MR/extract.sh" block "$FIX/0028-bad-nonconsecutive-steps.md" 3 apply)"
assert_eq "$out" 'echo "three" >> fixture.txt' \
  "non-consecutive fixture: step 3 apply block resolves correctly"

# A fence info-string with an extra key is not a tagged fence: it contributes
# no role and its body cannot be fetched as a block.
out="$(bash "$MR/extract.sh" roles "$FIX/0025-bad-infostring-extra-key.md" 1)"
assert_eq "$out" "$(printf 'check\nprecondition\nrollback')" \
  "extra-key info-string fence contributes no role"

bash "$MR/extract.sh" block "$FIX/0025-bad-infostring-extra-key.md" 1 apply >/dev/null 2>&1
assert_eq "$?" "1" "block exits 1 for a fence with an extra info-string key"

echo
echo "== lint-migration.sh: structural rules =="

# --threshold (or --host) is now mandatory (see the no-silent-no-op
# assertions below), and the ID it compares against comes from the
# filename. These fixtures all already declare migration_format: executable
# in their own frontmatter, so any threshold value puts them in scope by
# opt-in; --threshold 16 is used throughout for consistency with
# codex-workflow's real declared threshold.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "0" "L1/L3/L5: conformant fixture passes"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0017-bad-l1-missing-rollback.md" 2>&1)"
assert_eq "$?" "1" "L1: missing rollback exits 1"
assert_contains "$out" "L1" "L1: names the rule"
assert_contains "$out" "rollback" "L1: names the missing role"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0018-bad-l3-duplicate-apply.md" 2>&1)"
assert_eq "$?" "1" "L3: duplicate apply exits 1"
assert_contains "$out" "L3" "L3: names the rule"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0019-bad-l5-role-on-yaml.md" 2>&1)"
assert_eq "$?" "1" "L5: role= on a yaml fence exits 1"
assert_contains "$out" "L5" "L5: names the rule"

# 0025-bad-infostring-extra-key.md already exists from Task 1 (extract.sh
# coverage). Reuse it here rather than adding a duplicate fixture: its apply
# fence ("```bash role=apply retry=2") is a bash fence that carries role=, so
# it is in scope for L5's exact grammar (^bash[ \t]+role=[a-z]+$) — the extra
# `retry=2` key fails that grammar even though the fence type is bash. This
# also drives an L1 violation (apply never gets recognized, so it looks
# missing), which is asserted precisely so this isn't a vacuous L5-only check.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0025-bad-infostring-extra-key.md" 2>&1)"
assert_eq "$?" "1" "L5: bash fence with extra info-string key exits 1"
assert_contains "$out" "L1: step 1: missing required role 'apply'" \
  "L5 fixture reuse: extra-key fence also trips L1 (apply looks absent)"
assert_contains "$out" "L5" "L5: names the rule for the extra-key grammar violation"
assert_contains "$out" "retry=2" \
  "L5: extra-key violation message names the offending info string, not just the word L5"

echo
echo "== lint-migration.sh: agreement, typos, threshold =="

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0020-bad-l2-wrong-heading.md" 2>&1)"
assert_eq "$?" "1" "L2: swapped headings exit 1"
assert_contains "$out" "L2" "L2: names the rule"

# 0021-bad-l4-typo-role.md is the fixture that matters most. Its stray fence
# is opened as ```bash role=aply``` ALONGSIDE a fully valid quartet (not
# instead of the real apply fence) precisely so that, before L4 exists, it is
# indistinguishable from an illustration snippet — nothing else fires. See
# task-3-report.md for the CRITICAL empirical exit-0 evidence, both for this
# fixture and for the fence-ordering bug found in fix round 1 (a role=aply
# fence hidden behind a heredoc's literal "### Step 2" line was ALSO
# silently ignored, for an unrelated reason, until the L2/L4 scan's fence
# check was moved ahead of its step-boundary check).
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0021-bad-l4-typo-role.md" 2>&1)"
assert_eq "$?" "1" "L4: role=aply exits 1"
assert_contains "$out" "L4" "L4: names the rule"
assert_contains "$out" "aply" "L4: quotes the offending value back"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0022-bad-threshold-no-frontmatter.md" 2>&1)"
assert_eq "$?" "1" "threshold: id 0022 >= 16 without migration_format exits 1"
assert_contains "$out" "migration_format" "threshold: names the missing field"

# Below every threshold and never opting in: frozen pre-format history, so it
# is skipped entirely even though it would fail every rule if it were judged
# (no rollback, and its only fence is untagged illustration).
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0005-belowthreshold-skip.md" 2>&1)"
assert_eq "$?" "0" "threshold: id 0005 < 16 is skipped entirely, even though it would fail L1"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "0" "threshold: conformant fixture at id 0016 passes"

echo
echo "== lint-migration.sh: filename-keyed ID, never frontmatter =="

# Deleting the id: line entirely must not evade the linter: scope came from
# the FILENAME (0026 >= 16), so the missing rollback is still caught.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0026-bad-no-frontmatter-id.md" 2>&1)"
assert_eq "$?" "1" "filename-ID: no id: line in frontmatter still gets judged (in scope by filename)"
assert_contains "$out" "L1" "filename-ID: missing rollback is still caught"
assert_contains "$out" "rollback" "filename-ID: names the missing role"

# Frontmatter id: 0005 disagrees with the filename's 0027. Scope is decided
# by the filename regardless (27 >= 16), and the disagreement itself is
# reported.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0027-bad-id-mismatch.md" 2>&1)"
assert_eq "$?" "1" "id-mismatch: frontmatter id disagreeing with filename id exits 1"
assert_contains "$out" "id-mismatch" "id-mismatch: names the rule"
assert_contains "$out" "0005" "id-mismatch: quotes the frontmatter id"
assert_contains "$out" "0027" "id-mismatch: quotes the filename id"

# id 0009 is below every host threshold, but the migration itself declares
# migration_format: executable — a declaration may ADD scope, never remove
# it, so this is judged anyway and its missing rollback is caught.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0009-bad-optin-below-threshold.md" 2>&1)"
assert_eq "$?" "1" "opt-in: below-threshold migration_format: executable still gets judged"
assert_contains "$out" "L1" "opt-in: missing rollback is still caught"

# 0030-scope-by-filename.md is the regression guard for property A itself:
# every OTHER above-threshold fixture in this suite is also in scope some
# other way (an executable declaration, or an agreeing frontmatter id), so
# none of them would fail if the linter were "simplified" to read the ID
# from frontmatter instead of the filename. This one's frontmatter id (0005)
# would put it BELOW every threshold if it were ever used for scope; only
# the filename's 0030 puts it in scope, and no migration_format line is
# declared either, so the threshold violation must also fire alongside L1.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0030-scope-by-filename.md" 2>&1)"
assert_eq "$?" "1" "scope-by-filename: in scope purely because the filename says 0030"
assert_contains "$out" "threshold" "scope-by-filename: threshold violation fires (no migration_format declared)"
assert_contains "$out" "L1" "scope-by-filename: missing rollback is still caught"
assert_contains "$out" "rollback" "scope-by-filename: names the missing role"

# unparseable-filename.md carries no leading digit at all. This is exactly
# the shape Task 3 requires to be a violation, never a skip.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/unparseable-filename.md" 2>&1)"
assert_eq "$?" "1" "filename-ID: an unparseable filename is a violation, not a skip"
assert_contains "$out" "numeric" "filename-ID: names the problem"

# A frontmatter id that isn't numeric at all (not just disagreeing) must be
# reported, not handed to bash arithmetic — which would error out to stderr
# and report nothing, letting the migration lint clean by accident.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0033-bad-nonnumeric-frontmatter-id.md" 2>&1)"
assert_eq "$?" "1" "id-mismatch: a non-numeric frontmatter id is a violation, not a crash"
assert_contains "$out" "id-mismatch" "id-mismatch: names the rule for a non-numeric id"
assert_contains "$out" "abc" "id-mismatch: quotes the non-numeric value"

echo
echo "== lint-migration.sh: L0 unknown migration_format, both scope branches =="

# Above threshold (in scope by filename): the out-of-scope skip path is never
# reached, so L0 fires through the report()-and-continue branch.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0032-bad-l0-above-threshold.md" 2>&1)"
assert_eq "$?" "1" "L0: unrecognised migration_format above threshold exits 1"
assert_contains "$out" "L0" "L0: names the rule (above threshold)"
assert_contains "$out" "legacy" "L0: quotes the offending value (above threshold)"

# Below threshold: being out of scope by ID does not excuse a garbage
# declaration — this exercises the OTHER L0 branch, the one that fires
# immediately before the "skip it entirely" exit.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0003-bad-l0-below-threshold.md" 2>&1)"
assert_eq "$?" "1" "L0: unrecognised migration_format below threshold still exits 1"
assert_contains "$out" "L0" "L0: names the rule (below threshold)"
assert_contains "$out" "legacy" "L0: quotes the offending value (below threshold)"

echo
echo "== lint-migration.sh: no silent no-op when scope can't be resolved =="

# Neither --threshold nor --host: there is deliberately no path that treats
# this as "nothing in scope, therefore clean." It must error.
out="$(bash "$MR/lint-migration.sh" "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "1" "no-scope: omitting both --threshold and --host is an error"
assert_contains "$out" "threshold" "no-scope: error names what could not be resolved"

out="$(bash "$MR/lint-migration.sh" --host nonexistent-host "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "65" "no-scope: an unknown host is an error, not a default"
assert_contains "$out" "nonexistent-host" "no-scope: error names the unresolved host"

# A non-numeric threshold — whether typed directly or resolved from a typo'd
# THRESHOLDS row — must not silently make the >= comparison fail closed as
# "nothing is above it". It has to be a hard error instead.
out="$(bash "$MR/lint-migration.sh" --threshold abc "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "65" "no-scope: a non-numeric --threshold value is an error"
assert_contains "$out" "numeric" "no-scope: error names the problem with the threshold"

echo
echo "== lint-migration.sh: argument and file handling =="

out="$(bash "$MR/lint-migration.sh" --threshold 16 --bogus-flag "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "64" "args: an unknown flag is an error, not silently ignored"
assert_contains "$out" "bogus-flag" "args: error names the unknown flag"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0016-conformant.md" "$FIX/0017-bad-l1-missing-rollback.md" 2>&1)"
assert_eq "$?" "64" "args: a second positional document is an error, not 'last one wins'"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0099-does-not-exist.md" 2>&1)"
assert_eq "$?" "66" "args: a nonexistent path is an error, not a below-threshold-shaped skip"
assert_contains "$out" "no such file" "args: error names the problem"

echo
echo "== lint-migration.sh: L6 consecutive step numbering =="

# 0028-bad-nonconsecutive-steps.md (Task 1) declares ### Step 1 and ### Step 3
# with no ### Step 2. The extractor deliberately tolerates the gap (two
# steps, not a merged one) — but the linter does not: L6 is new in Task 3.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0028-bad-nonconsecutive-steps.md" 2>&1)"
assert_eq "$?" "1" "L6: non-consecutive step numbering exits 1"
assert_contains "$out" "L6" "L6: names the rule"

echo
echo "== run-migration.sh: happy path =="

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0016-conformant.md" "$tmp" 2>&1)"
rc=$?
assert_eq "$rc" "0" "conformant migration applies cleanly"
assert_eq "$(cat "$tmp/fixture.txt")" "$(printf 'applied\nsecond')" "both steps applied in order"
assert_contains "$out" "step 1" "reports step 1"
assert_contains "$out" "step 2" "reports step 2"
assert_eq "$(ls "$tmp"/tripwire.txt 2>/dev/null; echo done)" "done" \
  "illustration fence was never executed"

# Idempotency: the second run must apply nothing and must leave the WHOLE
# tree byte-identical — not just fixture.txt's content, which a stray extra
# file created by the second run would pass unnoticed. A find+checksum
# snapshot over every file in the workdir catches that a single-file content
# comparison cannot.
before="$(tree_snapshot "$tmp")"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0016-conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "second run exits 0"
assert_contains "$out" "skipped" "second run reports skipped"
after="$(tree_snapshot "$tmp")"
assert_eq "$after" "$before" "second run leaves the whole workdir byte-identical (checksum snapshot)"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: dry-run =="

# §08 requires dry-run to run check + precondition and print the apply
# SOURCE, writing nothing. A dry run cannot show a real diff without applying
# the step. It evaluates check/precondition up to and including the FIRST
# pending step only: 0016's step 1 is pending, so its source is printed and
# its check/precondition really ran; step 2 is never evaluated at all — its
# apply source is printed but explicitly labelled unevaluated, and its check
# (which depends on step 1 having actually run) never executes.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --host codex-workflow --dry-run "$FIX/0016-conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "dry-run exits 0"
assert_contains "$out" 'echo "applied" > fixture.txt' "dry-run prints step 1's apply source"
assert_contains "$out" 'echo "second" >> fixture.txt' "dry-run prints step 2's apply source too"
assert_contains "$out" "not evaluated" \
  "dry-run labels step 2 as unevaluated rather than silently running its check"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "dry-run wrote nothing"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: three-valued check, unchanged in dry-run =="

# check exiting 2 (neither 0 nor 1) means the check itself could not run.
# Conflating that with "not applied" would silently re-apply a step whose
# state is unknown — the runner must abort instead, and must never run apply.
# This is NOT relaxed in dry-run: a dry run that reports success over a
# migration whose real run would hard-abort is worse than no preview at all,
# so both modes must agree here.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0024-failing-check.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "check exiting 2 aborts a real run"
assert_contains "$out" "could not run" "abort message names the check-could-not-run condition"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "apply never ran when its step's check could not run"
rm -rf "$tmp"; trap - EXIT

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --host codex-workflow --dry-run "$FIX/0024-failing-check.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "the same fixture's dry run aborts too, exactly as the real run does"
assert_contains "$out" "could not run" "dry-run abort message also names the check-could-not-run condition"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "dry-run still wrote nothing"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: pre-condition failure is verbatim and hard-aborts =="

# A failing pre-condition always aborts — regardless of whether stdin is a
# terminal — and its stderr is reproduced VERBATIM, never paraphrased. 0023's
# pre-condition writes an exact two-line remediation message and exits 3.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0023-failing-precondition.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "failing pre-condition aborts the migration"
assert_contains "$out" 'cparx: unmanaged prose at line 42. Either (a) move it above the marker,' \
  "pre-condition stderr line 1 reproduced verbatim"
assert_contains "$out" 'or (b) re-run with --adopt to take ownership.' \
  "pre-condition stderr line 2 reproduced verbatim"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "apply never ran when its step's pre-condition failed"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: pre-condition failure aborts a dry run too =="

# Spec: "A precondition failing during a dry run SHALL abort the dry run and
# exit non-zero, exactly as it would during a real run." 0016's step 1 is the
# first pending step, so its precondition IS evaluated in dry-run (dry-run
# evaluates check+precondition up to and including the first pending step) —
# unlike 0023's case here, where the failure is on the very first step, so
# there is nothing before it to have already been reported pending.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --host codex-workflow --dry-run "$FIX/0023-failing-precondition.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "dry-run aborts on a failing pre-condition"
assert_contains "$out" 'cparx: unmanaged prose at line 42. Either (a) move it above the marker,' \
  "dry-run reproduces pre-condition stderr line 1 verbatim"
assert_contains "$out" 'or (b) re-run with --adopt to take ownership.' \
  "dry-run reproduces pre-condition stderr line 2 verbatim"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "dry-run wrote nothing"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: pre-condition failure aborts at a terminal too =="

# The same fixture, but stdin redirected from /dev/null so [ -t 0 ] is false —
# and separately exercised with an explicit --on-failure=prompt so the
# terminal-vs-not distinction is not what is deciding the outcome. A failing
# pre-condition is not governed by the failure policy at all: it always
# hard-aborts.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow --on-failure=prompt "$FIX/0023-failing-precondition.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "failing pre-condition aborts even with --on-failure=prompt"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: each block runs in its own shell =="

# 0029's check and pre-condition each set a variable, define a function, AND
# cd elsewhere (/tmp) — none of which its apply block may see. If apply
# observed the variable or function, it would write "leaked" instead of
# "clean"; if apply inherited the earlier blocks' cwd instead of being cd'd
# into the workdir fresh, "cwd.txt" would record /tmp (or fail to land in the
# workdir at all).
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0029-block-isolation.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "isolation fixture applies cleanly"
assert_eq "$(cat "$tmp/iso.txt")" "clean" \
  "apply sees no env var or function left by check/precondition blocks"
assert_eq "$(cat "$tmp/cwd.txt")" "$(cd "$tmp" && pwd)" \
  "apply runs in the workdir, not the cwd check/precondition changed to"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: dry-run never writes outside the workdir =="

# Regression guard for the scratch-mirror defect found in review round 1: an
# earlier implementation copied the workdir into a scratch directory and ran
# each pending step's apply there for real, on the theory that a copy is not
# "the working tree." 0034's apply writes to an absolute path outside the
# workdir; dry-run must never execute apply AT ALL, so this must never
# appear, in a scratch copy or anywhere else.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
escape_target="$(mktemp -d)"; trap 'rm -rf "$tmp" "$escape_target"' EXIT
out="$(ESCAPE_TARGET="$escape_target" bash "$MR/run-migration.sh" --host codex-workflow --dry-run "$FIX/0034-escape-probe.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "escape-probe dry-run exits 0"
assert_contains "$out" 'date > "$ESCAPE_TARGET/ran"' "dry-run prints the apply source"
assert_eq "$(ls "$tmp"/probe.txt 2>/dev/null; echo none)" "none" "dry-run wrote nothing in the workdir"
assert_eq "$(ls "$escape_target"/ran 2>/dev/null; echo none)" "none" \
  "dry-run wrote nothing outside the workdir either — apply never ran, not even against a copy"
rm -rf "$tmp" "$escape_target"; trap - EXIT

echo
echo "== run-migration.sh: document existence/readability =="

# A nonexistent document must be a hard error, not a silent zero-step,
# zero-anything success: extract.sh's own awk error would otherwise go to
# stderr while `steps` comes back empty, the loop runs zero times, and the
# script exits 0 having done nothing at all.
out="$(bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0099-does-not-exist.md" 2>&1)"
assert_eq "$?" "66" "a nonexistent document is an error, not a silent no-op success"
assert_contains "$out" "no such file" "error names the problem"

echo
echo "== run-migration.sh: --on-failure validates its value =="

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --host codex-workflow --on-failure=bogus "$FIX/0016-conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "64" "an unrecognised --on-failure value is a usage error"
assert_contains "$out" "bogus" "error names the offending value"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "nothing ran before the bad flag was rejected"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: (retired) a missing pre-condition block =="

# RETIRED in fix round 1, not merely renumbered. The prior version of this
# test kept its ad-hoc fixture BELOW every host's threshold, with no
# migration_format declared, specifically so lint-migration.sh would skip it
# (exit 0, out of scope) and never see the missing precondition — leaving
# run_block's own 127-detection in the dispatch loop as the only thing that
# caught it.
#
# Fix round 1 closes exactly that gap (see "the runner executes only
# migrations the linter judged" below): a below-threshold, non-opted-in
# document is now refused BEFORE the dispatch loop ever runs, which means
# the fixture that used to reach run_block's 127 path can no longer reach it
# at all without also being refused first. And the fixture cannot be made
# in-scope instead, because lint's L1 and run_block share the exact same
# extraction primitive (extract.sh) — any role L1 sees as present, run_block
# necessarily also finds, and any role missing enough to trip run_block's
# 127 path is, by the same construction, missing enough to trip L1 first.
# There is no longer a document shape that is both in-scope-and-lint-clean
# AND missing a required role at runtime. The dispatch loop's own
# rc-eq-127 handling (see run_block's header comment and the "pre-condition
# block missing" branch below it) is kept as defense in depth — it is
# still correct code, just no longer reachable from this CLI, by design.

echo
echo "== run-migration.sh: --host is required, no default =="

# THE HOST IS REQUIRED, NOT OPTIONAL. An optional threshold looks harmless
# and reopens the silent-no-op hole one layer down: with no threshold,
# nothing is in scope for the linter, every lint passes trivially, and this
# runner — which now lints before executing — would execute anything at all.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" "$FIX/0016-conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "64" "a missing --host is a usage error"
assert_contains "$out" "--host is required" "error names the missing flag"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "nothing ran when --host was omitted"
rm -rf "$tmp"; trap - EXIT

# --host with no value at all (the flag is the last argument) is a usage
# error too, and a CLEAN one — fix round 1's minor fix: this used to hit
# bash's own "${2:?...}" expansion directly, producing a raw
# "line N: 2: --host needs a value" message and exit 1, unlike every other
# usage error's clean exit 64.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --host 2>&1)"
assert_eq "$?" "64" "a bare --host with no value is a clean usage error, not a raw bash message"
assert_contains "$out" "--host needs a value" "error names the missing value"
assert_not_contains "$out" "line " "error is not a raw bash parameter-expansion message"
rm -rf "$tmp"; trap - EXIT

# An unknown host name is a usage problem with how THIS SCRIPT was invoked —
# not a property of the document — so fix round 1 maps it to 64 (the same
# usage-error code as the other bad-argument cases above), even though
# lint-migration.sh's OWN internal contract calls this exit 65 ("bad
# threshold/host") for itself. The runner's 65 is reserved exclusively for
# document refusals (see the next section) and must not be muddied by a
# caller's own typo.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --host nonexistent-host "$FIX/0016-conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "64" "an unknown --host value is a usage error (64), not a document refusal (65)"
assert_contains "$out" "nonexistent-host" "error names the unresolved host"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "nothing ran for an unresolvable host"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: refuses a migration that would do nothing =="

# LINT BEFORE EXECUTING ANYTHING.
#
# Rejecting a bad migration at lint time is not enough on its own, because
# nothing obliges the operator to have linted. Confirmed against the OLD
# (task 4) runner before this fix: 0017-bad-l1-missing-rollback.md fails L1
# (its step has no rollback block at all) yet the old runner ran check,
# pre-condition, and apply to completion and exited 0 —
#   step 1: applied
#   rc=0
#   fixture.txt: applied
# — a lint violation, fully executed, reported as success. The runner must
# now lint first and refuse before any block runs at all.
#
# Exit code 65 (not a bare 1): fix round 1 reserves 65 for every
# pre-execution refusal (lint violation, zero steps, no apply block, out of
# scope) and leaves 1 for a failure once execution has begun, so a caller can
# tell "refused, tree untouched" from "ran partway, tree may have changed"
# by exit code alone. 0024-failing-check.md elsewhere in this suite still
# exits 1 — it fails mid-dispatch, not at the pre-execution gate.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0017-bad-l1-missing-rollback.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses a migration that fails the linter"
assert_contains "$out" "L1" "the runner's output includes the linter's own violation"
assert_contains "$out" "rollback" "the violation names the missing role"
assert_contains "$out" "does not satisfy the executable format" \
  "the runner explains why it refused"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "no block of the failing-lint migration ever ran"
rm -rf "$tmp"; trap - EXIT

# 0035-all-illustration.md: every fence in its one step is un-annotated.
# Confirmed against the OLD runner: it does NOT report success on this exact
# fixture — run_block's own missing-block convention (extract.sh exits 1 =>
# 127) makes the untagged `check` role look like "the check itself could not
# run," so the OLD runner already hard-aborted here for an unrelated reason:
#   step 1: idempotency check could not run (exit 127) — aborting
#   rc=1
# That is an accident of the three-valued check contract, not evidence the
# format is enforced: it fires only because `check` specifically happened to
# be untagged, and gives no indication the document is even in scope, let
# alone which rule it breaks. Lint-first replaces that with an accurate,
# actionable diagnostic naming all four missing roles, and — unlike the
# accident above — also catches a document where only SOME roles are
# illustration (see 0038 below, where `check` is real and tagged but `apply`
# is empty, and the accident above cannot fire at all).
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0035-all-illustration.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses an all-illustration migration"
assert_not_contains "$out" "step 1: applied" "the runner does not report success"
assert_contains "$out" "L1: step 1: missing required role 'check'" \
  "the linter names the missing check role"
assert_contains "$out" "L1: step 1: missing required role 'precondition'" \
  "the linter names the missing precondition role"
assert_contains "$out" "L1: step 1: missing required role 'apply'" \
  "the linter names the missing apply role"
assert_contains "$out" "L1: step 1: missing required role 'rollback'" \
  "the linter names the missing rollback role"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "the apply illustration was never executed"
assert_eq "$(ls "$tmp"/tripwire.txt 2>/dev/null; echo none)" "none" \
  "the un-annotated tripwire fence was never executed"
rm -rf "$tmp"; trap - EXIT

# 0039-zero-steps.md: an in-scope migration with no ### Step heading at all.
# Confirmed against the OLD runner: it exits 0 with NO output whatsoever —
#   [output was empty]
#   rc=0
# — the purest form of the defect this group exists to close: a document
# that runs to completion having dispatched nothing, and reports success.
# Lint alone cannot catch this (every per-step rule iterates zero times over
# an empty step list, so lint-migration.sh itself exits 0 clean on this
# fixture) — only the runner's own zero-steps refusal closes this one.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0039-zero-steps.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses a zero-step migration"
assert_contains "$out" "declares no steps" "the runner names the zero-steps problem"
rm -rf "$tmp"; trap - EXIT

# 0038-zero-apply-step.md: check/precondition/rollback are real and tagged;
# the apply fence is syntactically valid (```bash role=apply```, satisfying
# L1) but has nothing between its delimiters, so lint-migration.sh itself
# exits 0 clean on this fixture too. Confirmed against the OLD runner:
#   step 1: applied
#   rc=0
#   fixture.txt: (absent — nothing was ever written)
# — the runner claimed the step applied while doing nothing at all. Checking
# for an EMPTY captured body (not just extract.sh's exit code) is what closes
# this: an absent apply block and a tagged-but-empty one are the same
# silent-no-op outcome from the operator's point of view.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0038-zero-apply-step.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses a step whose apply block is empty"
assert_not_contains "$out" "step 1: applied" "the runner does not report success"
assert_contains "$out" "step 1 has no apply block" "the runner names the empty apply block"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "nothing was written by the empty apply block"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: a runner executes only migrations the linter judged =="

# FIX ROUND 1, Important 1. The linter's silence on a below-threshold,
# non-opted-in document means NOT EXAMINED, not EXAMINED AND FOUND
# WELL-FORMED — lint-migration.sh exits 0 in both cases. Before this fix, the
# runner treated "lint exited 0" as "approved," so renaming ANY migration —
# however malformed — to a low-numbered filename made the format gate
# evaporate at run time. Confirmed against the round-0 (this group's first
# submission) runner, committed at 647ca93, using
# 0004-belowthreshold-no-rollback.md (below every host's threshold, no
# migration_format declared, every role real and tagged EXCEPT rollback,
# which is missing outright):
#   step 1: applied
#   rc=0
#   fixture.txt: applied
# — exactly the same shape as the reviewer's own verification
# (0003-no-rollback.md, same defect). The fix asks lint-migration.sh's own
# scope computation directly (--scope-only), rather than duplicating the
# ID/threshold rule here, and refuses before the linter's structural rules —
# let alone the dispatch loop — ever run.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0004-belowthreshold-no-rollback.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses a below-threshold migration the linter never examined"
assert_not_contains "$out" "step 1: applied" "the runner does not report success"
assert_contains "$out" "out of scope" "the runner names it as out of scope, distinctly from a format violation"
assert_not_contains "$out" "L1" "no structural lint rule ever ran against an unexamined document"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "no block of the unexamined migration ever ran"
rm -rf "$tmp"; trap - EXIT

# The other side of the same requirement: opting in below the threshold adds
# a migration to scope and it runs normally — opting in can only ever ADD
# scope, never remove it, so this must not be refused.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0006-belowthreshold-optin-conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "an opted-in below-threshold migration that satisfies the format runs normally"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "applied" \
  "the opted-in below-threshold migration actually applied"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: refusal is distinguishable from failure by exit code =="

# FIX ROUND 1, Important 2. Every pre-execution refusal above (lint
# violation, zero steps, no apply block, out of scope) shares exit 65 with
# the working tree guaranteed untouched. A failure once execution has begun
# is a different code (1) precisely because the tree may already have
# changed — a CI caller needs to tell these apart without parsing stderr.
# 0024-failing-check.md's step 1 check exits 2 (can't tell if it's already
# applied), which is a MID-DISPATCH failure, not a pre-execution refusal:
# the document itself is lint-clean and well-scoped, so it reaches the
# dispatch loop before failing.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0017-bad-l1-missing-rollback.md" "$tmp" 2>&1)"
refusal_rc="$?"
out2="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0024-failing-check.md" "$tmp" 2>&1)"
failure_rc="$?"
assert_eq "$refusal_rc" "65" "a pre-execution refusal (lint violation) is exit 65"
assert_eq "$failure_rc" "1" "a mid-dispatch failure (check could not run) is exit 1, not 65"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: dry-run never writes outside the workdir via a symlink =="

# 0034-escape-probe.md above guards only the ABSOLUTE-path variant of the
# dry-run escape. This is the same root cause from the other side: a workdir
# containing a symlink to a location outside it, and an apply block that
# only ever names a purely RELATIVE path (no leading /, no env var). Since
# dry-run never executes apply at all — not for real, not against a scratch
# copy — this must never appear regardless of what the relative path
# resolves to.
tmp="$(mktemp -d)"
escape_target="$(mktemp -d)"
trap 'rm -rf "$tmp" "$escape_target"' EXIT
ln -s "$escape_target" "$tmp/escape-link"
out="$(bash "$MR/run-migration.sh" --host codex-workflow --dry-run "$FIX/0040-symlink-escape-probe.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "symlink escape-probe dry-run exits 0"
assert_contains "$out" 'date > escape-link/ran' "dry-run prints the apply source"
assert_eq "$(ls "$tmp"/probe.txt 2>/dev/null; echo none)" "none" "dry-run wrote nothing in the workdir"
assert_eq "$(ls "$escape_target"/ran 2>/dev/null; echo none)" "none" \
  "dry-run wrote nothing through the symlink either — apply never ran"
rm -rf "$tmp" "$escape_target"; trap - EXIT

echo
echo "TOTAL: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
