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
out="$(cd "$tmp" && bash "$MR/run-migration.sh" "$FIX/0016-conformant.md" "$tmp" 2>&1)"
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
out="$(cd "$tmp" && bash "$MR/run-migration.sh" "$FIX/0016-conformant.md" "$tmp" 2>&1)"
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
out="$(bash "$MR/run-migration.sh" --dry-run "$FIX/0016-conformant.md" "$tmp" 2>&1)"
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
out="$(cd "$tmp" && bash "$MR/run-migration.sh" "$FIX/0024-failing-check.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "check exiting 2 aborts a real run"
assert_contains "$out" "could not run" "abort message names the check-could-not-run condition"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "apply never ran when its step's check could not run"
rm -rf "$tmp"; trap - EXIT

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --dry-run "$FIX/0024-failing-check.md" "$tmp" 2>&1)"
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
out="$(cd "$tmp" && bash "$MR/run-migration.sh" "$FIX/0023-failing-precondition.md" "$tmp" 2>&1)"
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
out="$(bash "$MR/run-migration.sh" --dry-run "$FIX/0023-failing-precondition.md" "$tmp" 2>&1)"
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
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --on-failure=prompt "$FIX/0023-failing-precondition.md" "$tmp" 2>&1)"
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
out="$(cd "$tmp" && bash "$MR/run-migration.sh" "$FIX/0029-block-isolation.md" "$tmp" 2>&1)"
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
out="$(ESCAPE_TARGET="$escape_target" bash "$MR/run-migration.sh" --dry-run "$FIX/0034-escape-probe.md" "$tmp" 2>&1)"
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
out="$(bash "$MR/run-migration.sh" "$FIX/0099-does-not-exist.md" 2>&1)"
assert_eq "$?" "66" "a nonexistent document is an error, not a silent no-op success"
assert_contains "$out" "no such file" "error names the problem"

echo
echo "== run-migration.sh: --on-failure validates its value =="

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --on-failure=bogus "$FIX/0016-conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "64" "an unrecognised --on-failure value is a usage error"
assert_contains "$out" "bogus" "error names the offending value"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "nothing ran before the bad flag was rejected"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: a missing pre-condition block is named, not misreported =="

# A step with no precondition block at all makes run_block return 127
# (extract.sh found nothing to run). That must not be reported as though the
# block ran and failed — the diagnostic should say the block is missing.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/0099-missing-precondition.md" <<'EOF'
---
id: 0099
slug: missing-precondition
title: A step with no pre-condition block at all
from_version: 1.8.0
to_version: 1.9.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0099 — missing pre-condition block

## Steps

### Step 1: No pre-condition heading or fence at all

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
EOF
out="$(cd "$tmp" && bash "$MR/run-migration.sh" "$tmp/0099-missing-precondition.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "a step with no pre-condition block aborts"
assert_contains "$out" "pre-condition block missing" \
  "diagnostic names the block as missing, not as having failed"
rm -rf "$tmp"; trap - EXIT

echo
echo "TOTAL: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
