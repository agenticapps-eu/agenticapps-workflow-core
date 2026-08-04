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
echo "== lint-migration.sh: L7 unclosed fence =="

# FIX ROUND 2. extract.sh's mr_roles (what L1 is built on) prints a role
# from a fence's OPENING line; mr_block (what the runner calls) only
# confirms it on the CLOSING line. A fence that opens and is never closed
# before EOF is therefore PRESENT to L1 but ABSENT to the runner — found by
# construction in review, using 0041-unclosed-fence-precondition.md: its
# pre-condition fence is deliberately last in the file and never closed.
# Before L7 existed, this fixture linted CLEAN — that clean exit is the
# evidence L7 was needed, not merely a nice-to-have. FIX ROUND 3, minor:
# this used to be narrated only in a comment and the fix report's
# transcript; it is now MACHINE-CHECKED by pulling the actual pre-L7
# lint-migration.sh out of git history and running it for real, so the
# "evidence" is an executed assertion rather than a claim.
# FIX ROUND 4: the `git show` below had its own exit status unchecked, and
# `>` creates the destination file regardless of whether the command inside
# it succeeded — an unreachable commit (a squash/rebase merge onto main, a
# shallow clone) would silently produce a 0-byte file, and `bash` on an
# empty file exits 0 with empty output: EXACTLY what both downstream
# assertions expect, making this pass VACUOUSLY forever instead of being the
# evidence it claims to be. Demonstrated directly: `git show deadbee:...`
# (nonexistent commit) leaves a 0-byte file and both downstream assertions
# would still PASS. Guarded now: `git show`'s own exit status, the extracted
# file's non-emptiness, and that it does NOT already contain "L7" (which
# would mean some OTHER revision got extracted, not the intended pre-L7
# one) are all asserted BEFORE anything the extracted script says is
# trusted — and if any of those guards fail, the two "MACHINE-CHECKED"
# assertions below are recorded as FAIL rather than silently skipped, so a
# broken extraction shrinks the pass count instead of vanishing from it.
oldlintdir="$(mktemp -d)"
git -C "$ROOT" show e22db7f:reference-implementations/migration-runner/lint-migration.sh > "$oldlintdir/lint-migration.sh" 2>/dev/null
show_rc=$?
assert_eq "$show_rc" "0" "git show e22db7f:...lint-migration.sh succeeds (the commit must stay reachable)"
assert_eq "$(test -s "$oldlintdir/lint-migration.sh" && echo nonempty || echo empty)" "nonempty" \
  "the extracted pre-L7 lint-migration.sh is non-empty, not a git-show failure masked by an empty file"
assert_not_contains "$(cat "$oldlintdir/lint-migration.sh" 2>/dev/null)" "L7" \
  "the extracted script is genuinely the pre-L7 revision (contains no L7 rule)"

if [ "$show_rc" -eq 0 ] && [ -s "$oldlintdir/lint-migration.sh" ]; then
  chmod +x "$oldlintdir/lint-migration.sh"
  # extract.sh and THRESHOLDS are unchanged since e22db7f; symlink the real
  # ones in rather than pulling stale copies of files this test isn't about.
  ln -s "$MR/extract.sh" "$oldlintdir/extract.sh"
  ln -s "$MR/THRESHOLDS" "$oldlintdir/THRESHOLDS"
  out="$(bash "$oldlintdir/lint-migration.sh" --host codex-workflow "$FIX/0041-unclosed-fence-precondition.md" 2>&1)"
  assert_eq "$?" "0" \
    "MACHINE-CHECKED: 0041 lints CLEAN under the actual pre-L7 (e22db7f) linter"
  assert_eq "$out" "" "the pre-L7 linter reports zero violations for this fixture, not merely exit 0"
else
  fail=$((fail + 2))
  echo "  FAIL  MACHINE-CHECKED: 0041 lints CLEAN under the actual pre-L7 (e22db7f) linter (skipped: extraction failed above)"
  echo "  FAIL  the pre-L7 linter reports zero violations for this fixture, not merely exit 0 (skipped: extraction failed above)"
fi
rm -rf "$oldlintdir"

out="$(bash "$MR/lint-migration.sh" --host codex-workflow "$FIX/0041-unclosed-fence-precondition.md" 2>&1)"
assert_eq "$?" "1" "L7: an unclosed fence at EOF exits 1"
assert_contains "$out" "L7" "L7: names the rule"
assert_contains "$out" "never closed" "L7: names the problem"
assert_contains "$out" "role=precondition" "L7: names the offending fence's info string"

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
echo "== run-migration.sh: the 127 collision (a present pre-condition is not a missing one) =="

# FIX ROUND 3. run_block used to return a sentinel of 127 to mean "the
# block is missing" — but `bash -c "$body"` ALSO returns 127 when the
# block's own command is not found (`command not found` is a real exit code,
# not this script's invention). 0043-precondition-127.md is fully
# lint-clean, in-scope, and L7-passing: check/apply/rollback are ordinary,
# and the pre-condition fence is real, tagged, and properly closed — its
# body just calls a command that does not exist on this machine. Confirmed
# against the pre-fix run-migration.sh (committed at 3ad0641, restored via
# `git stash` and run in place):
#   bash: definitely-not-a-real-command-xyz: command not found
#   step 1: pre-condition block missing — aborting
#   rc=1
# — telling the operator their migration is malformed and the block is
# missing, when the block is present, ran, and told them (via its own exit
# code) that a tool it needs is not installed. This is the same
# looks-correct-does-nothing-shaped misreport this format exists to guard
# against, pointed in the opposite direction: not a phantom success, but a
# false "this document is broken" aimed at one that is not.
#
# The fix: run_block now sets an out-of-band $BLOCK_MISSING flag (0 or 1) at
# entry, rather than overloading its own return value, so the block's REAL
# exit code — even 127 — is never confused with "extract.sh found nothing."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0043-precondition-127.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "a present pre-condition whose command isn't installed aborts"
assert_contains "$out" "pre-condition failed" \
  "diagnostic reports it as a failed pre-condition, not a missing block"
assert_not_contains "$out" "pre-condition block missing" \
  "a present-but-127-exiting block is not misreported as absent"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "apply never ran (pre-condition still hard-aborts, real failure or not)"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: a missing pre-condition block is named, not misreported =="

# FIX ROUND 1 retired this test on the theory that L1 and run_block share
# the same extraction primitive, so no document could be both in-scope-and-
# lint-clean and still missing a required role at runtime. FIX ROUND 2's
# review disproved that BY CONSTRUCTION: extract.sh's mr_roles (what L1 is
# built on) prints a role from a fence's OPENING line, while mr_block (what
# run_block calls) only confirms it on the CLOSING line. An unclosed fence
# at EOF is therefore present to one and absent to the other — see
# 0041-unclosed-fence-precondition.md and lint-migration.sh's new L7, which
# closes exactly that gap.
#
# L7 closes the SPECIFIC mismatch the reviewer found for THIS FIXTURE'S
# SHAPE (a step with no precondition heading or fence at all): once L7
# exists, that specific shape cannot stay in-scope-and-lint-clean, so an
# in-scope document with a genuinely absent precondition fails L1 before the
# dispatch loop ever runs (asserted below). This is a claim about this one
# fixture's shape only — FIX ROUND 3 found a completely different route to
# the very same dispatch-loop branch (a PRESENT pre-condition whose own
# command isn't installed, also producing a non-zero exit — see the
# "127 collision" section elsewhere in this suite) — so this is not, and
# must not be read as, a claim that the branch itself is unreachable in
# general.
#
# FIX ROUND 2 exercised the branch via an environment-variable bypass in
# run-migration.sh itself. FIX ROUND 3 removed that bypass entirely — an env
# var is inherited transitively by anything downstream (a nested runner
# invocation, a CI env: block, an agent's own tool config) and a bypassed
# run is byte-identical to a real one, with nothing to grep for. This test
# now uses a STUB-COLLABORATOR test double instead, with zero bypass surface
# in the shipped script: run-migration.sh resolves SCRIPT_DIR from
# ${BASH_SOURCE[0]} (the path as INVOKED, not a symlink target) and derives
# both extract.sh and its lint-migration.sh calls from it, so a temp dir
# containing SYMLINKS to the real run-migration.sh and extract.sh, plus a
# STUB lint-migration.sh that unconditionally exits 0, reproduces "past the
# lint gate" exactly — same output, same exit code — without run-migration.sh
# containing any code that skips its own gates. Symlinks rather than copies
# so this can never silently drift onto a stale copy of either script.
# THRESHOLDS is not needed here since only the real linter reads it.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# First, confirm normal operation still refuses it — this is what happens
# to this exact fixture on every real invocation, using the REAL linter.
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0042-missing-precondition-block.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "normally, this fixture is refused at the lint gate (L1), never reaching the dispatch loop"
assert_contains "$out" "L1" "the refusal is attributed to the linter, not the dispatch loop"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "nothing ran"

# Now exercise the dispatch loop's own handling directly, via the stub
# collaborator described above.
stubdir="$(mktemp -d)"
ln -s "$MR/run-migration.sh" "$stubdir/run-migration.sh"
ln -s "$MR/extract.sh" "$stubdir/extract.sh"
cat > "$stubdir/lint-migration.sh" <<'STUB'
#!/usr/bin/env bash
# Stub collaborator for this test only — not part of the shipped scripts.
# Always clean, for both --scope-only and the full-lint call: this stands
# in for "a document that got past both real lint gates," not for anything
# a real lint-migration.sh does.
exit 0
STUB
chmod +x "$stubdir/lint-migration.sh"

out="$(cd "$tmp" && bash "$stubdir/run-migration.sh" --host codex-workflow "$FIX/0042-missing-precondition-block.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "past a stubbed-clean lint gate, a step with no pre-condition block aborts"
assert_contains "$out" "pre-condition block missing" \
  "diagnostic names the block as missing, not as having failed"
assert_not_contains "$out" "pre-condition failed" \
  "a missing block is not misreported as a failed one"
rm -rf "$tmp" "$stubdir"; trap - EXIT

echo
echo "== run-migration.sh: a missing check block is not silently treated as 'not yet applied' =="

# FIX ROUND 4, Important 1 — a REAL REGRESSION introduced by fix round 3's
# BLOCK_MISSING refactor, not a pre-existing gap. run_block used to return a
# sentinel of 127 for "block missing"; changing that to a real 1 collided
# with the THREE-VALUED check contract's OWN meaning for 1 ("not yet
# applied, proceed"). Fix round 3 updated the pre-condition call site to
# consult $BLOCK_MISSING but missed the check call site, so a migration
# whose check was simply never written fell through into "proceed, apply
# it" — silently voiding the idempotency contract. Confirmed against the
# committed run-migration.sh at acae685 (past a stubbed-clean lint gate,
# same technique as the pre-condition test above):
#   step 1: applied
#   rc=0
#   fixture.txt: APPLIED BLIND
# — applied blind, with no idempotency check at all, reporting success.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Normal operation still refuses it at lint (L1), same contrast as above.
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0044-missing-check-block.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "normally, this fixture is refused at the lint gate (L1), never reaching the dispatch loop"
assert_contains "$out" "L1" "the refusal is attributed to the linter, not the dispatch loop"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "nothing ran"

# Past a stubbed-clean lint gate, the dispatch loop's own check-handling
# must abort rather than silently proceeding to apply.
stubdir="$(mktemp -d)"
ln -s "$MR/run-migration.sh" "$stubdir/run-migration.sh"
ln -s "$MR/extract.sh" "$stubdir/extract.sh"
cat > "$stubdir/lint-migration.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$stubdir/lint-migration.sh"

out="$(cd "$tmp" && bash "$stubdir/run-migration.sh" --host codex-workflow "$FIX/0044-missing-check-block.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "past a stubbed-clean lint gate, a step with no check block aborts, not applies"
assert_contains "$out" "idempotency check block missing" \
  "diagnostic names the check block as missing"
assert_not_contains "$out" "step 1: applied" \
  "the step is NOT silently applied just because its check block is absent"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "apply never ran — the missing check aborts before it, exactly like a missing pre-condition does"
rm -rf "$tmp" "$stubdir"; trap - EXIT

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
# L1) but has nothing between its delimiters. AT THE TIME this fixture and
# test were written, lint-migration.sh exited 0 clean on it, and only the
# runner's OWN pre-flight scan (checking the captured apply body for
# emptiness, not just extract.sh's exit code) caught it, reporting "step 1
# has no apply block". L8 (task 6) now generalises that same emptiness check
# to every role and moves it into the linter, so this fixture is refused at
# the LINT GATE now, before the runner's own pre-flight scan ever runs — this
# is strictly earlier and more informative (it names the rule), not a
# regression: the runner's own apply-emptiness check stays in place as
# defense in depth for a lint-bypassed path (e.g. the stub-collaborator
# technique used elsewhere in this suite), it merely never fires for THIS
# fixture's shape any more. Confirmed against the OLD runner (pre-L8):
#   step 1: applied
#   rc=0
#   fixture.txt: (absent — nothing was ever written)
# — the runner claimed the step applied while doing nothing at all.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0038-zero-apply-step.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses a step whose apply block is empty"
assert_not_contains "$out" "step 1: applied" "the runner does not report success"
assert_contains "$out" "L8: step 1: role 'apply' is empty or whitespace-only" \
  "the runner's lint gate (L8) names the empty apply block"
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
# dispatch loop before failing. This case alone does not touch the tree
# either way, though, so it does not yet distinguish "tree untouched" from
# "tree may have changed" — see the load-bearing case just below.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0017-bad-l1-missing-rollback.md" "$tmp" 2>&1)"
refusal_rc="$?"
out2="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0024-failing-check.md" "$tmp" 2>&1)"
failure_rc="$?"
assert_eq "$refusal_rc" "65" "a pre-execution refusal (lint violation) is exit 65"
assert_eq "$failure_rc" "1" "a mid-dispatch failure (check could not run) is exit 1, not 65"
rm -rf "$tmp"; trap - EXIT

# FIX ROUND 2. spec.md's own scenario: "WHEN a step's apply fails AFTER
# EARLIER STEPS APPLIED ... THEN the runner SHALL exit with a code distinct
# from the refusal code." The case above never applies anything either way,
# so it cannot show the dangerous side of the distinction: a tree that MAY
# have changed. 0036-failing-apply.md's step 1 genuinely applies (writes
# fixture.txt) before step 2's apply exits 7 non-interactively (default
# --on-failure when stdin is not a terminal, which it never is under this
# test harness). The observable difference from every refusal case above is
# that step 1's artefact SURVIVES on disk — that is "ran partway, tree may
# have changed" made concrete, not merely a different number.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0036-failing-apply.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "a step's apply failing after an earlier step applied is exit 1, not 65"
assert_contains "$out" "step 1: applied" "step 1 is reported as applied"
assert_contains "$out" "step 2: apply failed" "step 2's apply failure is reported"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "step1" \
  "step 1's artefact survives on disk — the tree DID change, unlike every refusal case above"
assert_eq "$(ls "$tmp"/step2.txt 2>/dev/null; echo none)" "none" \
  "step 2's own artefact was never written (its apply is what failed)"
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
echo "== lint-migration.sh: L8 empty/whitespace-only body, any role =="

# 0049: role=check is PRESENT (an exact-grammar fence tagged check opens and
# closes), so L1 sees nothing wrong — this is the fixture that lints clean
# without L8. Run for real, `bash -c ''` exits 0, which the three-valued
# check contract reads as "already applied": the runner would report
# "step 1: skipped (already applied)" and apply nothing on a tree where
# nothing was ever applied. That is confirmed directly below, against the
# REAL CLI, not merely asserted.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0049-bad-l8-empty-check.md" 2>&1)"
assert_eq "$?" "1" "L8: a tagged-but-empty check fence exits 1"
assert_contains "$out" "L8" "L8: names the rule"
assert_contains "$out" "'check'" "L8: names the empty role"
assert_not_contains "$out" "L1" "L8: does NOT also fire L1 — the role IS present, just empty"

# The runner's existing lint-before-execute gate closes this without any
# runner change: once L8 exists, this fixture is refused before dispatch,
# rather than silently reporting "skipped (already applied)" as it would
# have before L8 existed.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0049-bad-l8-empty-check.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses an empty-check migration at the lint gate"
assert_contains "$out" "L8" "the refusal is attributed to L8"
assert_not_contains "$out" "skipped (already applied)" \
  "the runner never gets far enough to report the silent-no-op skip"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "nothing ran"
rm -rf "$tmp"; trap - EXIT

# 0050: whitespace-only (one blank line), not merely zero bytes — proves L8
# tests emptiness AFTER stripping whitespace, not a literal byte-count.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0050-bad-l8-empty-precondition.md" 2>&1)"
assert_eq "$?" "1" "L8: a whitespace-only pre-condition fence exits 1"
assert_contains "$out" "L8" "L8: names the rule (precondition)"
assert_contains "$out" "'precondition'" "L8: names the empty role (precondition)"

echo
echo "== run-migration.sh: A2 failure policy — non-interactive apply failure =="

# 0036-failing-apply.md: step 1 applies, step 2's apply exits 7. This is the
# load-bearing case: absence of anyone to ask is not consent, and the
# half-applied tree is the evidence of what happened, which an automatic
# rollback would destroy.
tmp="$(mktemp -d)"
out="$(bash "$MR/run-migration.sh" --host codex-workflow --on-failure=abort "$FIX/0036-failing-apply.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2: explicit --on-failure=abort exits 1"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "step1" \
  "A2: step 1's work SURVIVES — nothing was rolled back"
assert_contains "$out" "Nothing was rolled back" "A2: says so explicitly"
assert_contains "$out" "applied steps: 1" "A2: names which steps applied"
rm -rf "$tmp"

# Non-TTY defaults to abort without being told (no --on-failure at all).
tmp="$(mktemp -d)"
out="$(bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0036-failing-apply.md" "$tmp" </dev/null 2>&1)"
assert_eq "$?" "1" "A2: non-TTY exits 1 with no --on-failure"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "step1" "A2: non-TTY rolls back nothing"
assert_contains "$out" "Nothing was rolled back" "A2: non-TTY says so explicitly too"
rm -rf "$tmp"

echo
echo "== run-migration.sh: A2 failure policy — verify failure is not recorded as applied =="

# 0037-failing-verify.md: step 2's apply succeeds (s2.txt is written) but its
# verify fails. The step must NOT be reported as applied, even though the
# apply itself ran to completion.
tmp="$(mktemp -d)"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0037-failing-verify.md" "$tmp" </dev/null 2>&1)"
assert_eq "$?" "1" "A2: a verify failure exits 1"
assert_eq "$(cat "$tmp/s1.txt" 2>/dev/null)" "s1" "A2: step 1 fully applied and verified"
assert_eq "$(cat "$tmp/s2.txt" 2>/dev/null)" "s2" "A2: step 2's apply DID run — verify is what failed"
assert_contains "$out" "step 2: verify failed" "A2: names the verify failure"
assert_not_contains "$out" "step 2: applied" \
  "A2: a failing verify does not mark its step applied"
rm -rf "$tmp"

echo
echo "== run-migration.sh: A2 failure policy — skip continues rather than aborting =="

# 0047-skip-continues.md: an earlier draft of this policy had skip fall
# through to an unconditional exit, meaning skip never skipped. Step 2's
# apply always fails; under --on-failure=skip the runner must still reach
# and apply step 3.
tmp="$(mktemp -d)"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow --on-failure=skip "$FIX/0047-skip-continues.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2: skip policy still exits non-zero overall (a step DID fail)"
assert_eq "$(cat "$tmp/s1.txt" 2>/dev/null)" "s1" "A2: step 1 applied"
assert_contains "$out" "step 3: applied" "A2: skip CONTINUES to step 3 rather than stopping at step 2"
assert_eq "$(cat "$tmp/s3.txt" 2>/dev/null)" "s3" "A2: step 3 actually ran"
assert_contains "$out" "partial" "A2: the migration is reported as partial"
rm -rf "$tmp"

echo
echo "== run-migration.sh: A2 interactive prompt — silence is never consent to roll back =="

# All four cases below feed stdin from a pipe or here-string, never a real
# pty. This proves the PROMPT-HANDLING logic itself — reading an answer,
# branching on it, and what happens at end-of-input — behaves correctly. It
# does NOT prove that `[ -t 0 ]` genuinely detects a real terminal; that
# detection is unchanged from task 4 and isn't exercised by a pty anywhere in
# this suite. --on-failure=prompt is passed explicitly so these cases reach
# the prompt branch despite stdin never being a terminal (matching "an
# explicit override selects the policy").

# End-of-input: the pipe/redirect supplies nothing at all.
tmp="$(mktemp -d)"
out="$(bash "$MR/run-migration.sh" --host codex-workflow --on-failure=prompt "$FIX/0036-failing-apply.md" "$tmp" </dev/null 2>&1)"
assert_eq "$?" "1" "A2 prompt: EOF on the prompt aborts"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "step1" "A2 prompt: EOF rolls back nothing"
assert_contains "$out" "Nothing was rolled back" "A2 prompt: EOF says so explicitly"
rm -rf "$tmp"

# An empty answer (just pressing enter) is not a "yes" either.
tmp="$(mktemp -d)"
out="$(printf '\n' | bash "$MR/run-migration.sh" --host codex-workflow --on-failure=prompt "$FIX/0036-failing-apply.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2 prompt: an empty answer aborts"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "step1" "A2 prompt: empty answer rolls back nothing"
assert_contains "$out" "Nothing was rolled back" "A2 prompt: empty answer says so explicitly"
rm -rf "$tmp"

# An unrecognised answer is not a "yes" either.
tmp="$(mktemp -d)"
out="$(printf 'qqq\n' | bash "$MR/run-migration.sh" --host codex-workflow --on-failure=prompt "$FIX/0036-failing-apply.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2 prompt: an unrecognised answer aborts"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "step1" "A2 prompt: unrecognised answer rolls back nothing"
assert_contains "$out" "Nothing was rolled back" "A2 prompt: unrecognised answer says so explicitly"
rm -rf "$tmp"

# An explicit --on-failure=abort overrides even when a "b" (rollback) answer
# is sitting right there on stdin — proving the override short-circuits
# before the prompt is ever reached, not merely that it happens to also
# answer "no".
tmp="$(mktemp -d)"
out="$(printf 'b\n' | bash "$MR/run-migration.sh" --host codex-workflow --on-failure=abort "$FIX/0036-failing-apply.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2: --on-failure=abort overrides even with a rollback answer available on stdin"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "step1" "A2: override never reads the available 'b' at all"
rm -rf "$tmp"

echo
echo "== run-migration.sh: A2 interactive prompt — retry loops back to the same prompt =="

# 0036's step 2 apply always exits 7, so a retry always fails again. Feeding
# "r" then "b" proves retry re-attempts the failing block and, on a second
# failure, re-prompts rather than falling through to anything else.
tmp="$(mktemp -d)"
out="$(printf 'r\nb\n' | bash "$MR/run-migration.sh" --host codex-workflow --on-failure=prompt "$FIX/0036-failing-apply.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2 prompt: retry-then-rollback exits non-zero"
assert_contains "$out" "failed again" "A2 prompt: retry re-ran the failing apply and it failed again"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "A2 prompt: the SECOND answer (rollback) still took effect — step 1 was rolled back"
rm -rf "$tmp"

echo
echo "== run-migration.sh: A2 interactive rollback — a verify-failed step IS rolled back =="

# 0037-failing-verify.md: step 2's apply succeeded and its verify failed.
# Choosing rollback must roll back BOTH steps, in reverse order (2 before 1)
# — step 2 is rollback-eligible precisely because its apply completed.
tmp="$(mktemp -d)"
out="$(printf 'b\n' | bash "$MR/run-migration.sh" --host codex-workflow --on-failure=prompt "$FIX/0037-failing-verify.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2 prompt: rollback after a verify failure exits non-zero"
log="$(cat "$tmp/rollback.log" 2>/dev/null)"
assert_contains "$log" "rollback:2" "A2 prompt: the verify-failed step's rollback DID run"
assert_contains "$log" "rollback:1" "A2 prompt: the earlier fully-applied step's rollback also ran"
assert_eq "$(printf '%s\n' "$log" | grep -n 'rollback:' | head -1 | cut -d: -f1)" \
  "$(printf '%s\n' "$log" | grep -n 'rollback:2' | head -1 | cut -d: -f1)" \
  "A2 prompt: step 2's rollback entry comes BEFORE step 1's — reverse document order"
rm -rf "$tmp"

echo
echo "== run-migration.sh: A2 interactive rollback — reverse order, membership, continues past a failed rollback =="

# 0048-rollback-order-and-membership.md: steps 1 and 2 apply; step 3's apply
# fails. Rollback must: (a) roll back 2 then 1 (reverse order), (b) NEVER
# roll back 3 (its apply failed part-way — state unknown), and (c) continue
# to attempt step 1's rollback even though step 2's rollback itself fails.
tmp="$(mktemp -d)"
out="$(printf 'b\n' | bash "$MR/run-migration.sh" --host codex-workflow --on-failure=prompt "$FIX/0048-rollback-order-and-membership.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2 prompt: a rollback that itself partially fails still exits non-zero"
log="$(cat "$tmp/rollback.log" 2>/dev/null)"
assert_contains "$log" "rollback:2:attempted" "A2 prompt: step 2's rollback WAS attempted"
assert_contains "$log" "rollback:1:ok" "A2 prompt: step 1's rollback WAS attempted despite step 2's failing"
assert_not_contains "$log" "rollback:3" \
  "A2 prompt: step 3's rollback NEVER ran — its apply failed part-way, excluded from rollback"
line2="$(printf '%s\n' "$log" | grep -n 'rollback:2:attempted' | head -1 | cut -d: -f1)"
line1="$(printf '%s\n' "$log" | grep -n 'rollback:1:ok' | head -1 | cut -d: -f1)"
assert_eq "$(( line2 < line1 ? 1 : 0 ))" "1" \
  "A2 prompt: step 2's rollback entry appears BEFORE step 1's — reverse document order"
assert_contains "$out" "rollback FAILED" "A2 prompt: step 2's own rollback failure is reported"
assert_contains "$out" "rollback succeeded" "A2 prompt: step 1's rollback success is reported too"
rm -rf "$tmp"

echo
echo "== run-migration.sh: apply BLOCK_MISSING is reachable through the real CLI, no stub needed =="

# 0046-apply-dropped-by-step1.md: step 1's own apply rewrites the document
# (a RELATIVE "0046-doc.md", copied into the workdir here — the numeric
# prefix matters, since the linter derives scope from the filename) to
# strip step 2's apply fence entirely. extract.sh re-reads $DOC from disk on
# every call, so by the time the dispatch loop reaches step 2, its apply
# fence is gone — BLOCK_MISSING, genuinely reached with no stub-collaborator
# bypass at all. This also exercises the deliberate design choice that
# apply/verify BLOCK_MISSING does NOT go through fail_policy: there is no
# "Nothing was rolled back" phrasing here, because fail_policy was never
# called.
tmp="$(mktemp -d)"
cp "$FIX/0046-apply-dropped-by-step1.md" "$tmp/0046-doc.md"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$tmp/0046-doc.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "apply BLOCK_MISSING: exits 1"
assert_eq "$(cat "$tmp/s1.txt" 2>/dev/null)" "s1" "apply BLOCK_MISSING: step 1 (which did the mutating) applied fine"
assert_contains "$out" "apply block missing" "apply BLOCK_MISSING: named as missing, not merely failed"
assert_not_contains "$out" "step 2: applied" "apply BLOCK_MISSING: step 2 never reported as applied"
assert_eq "$(ls "$tmp"/s2.txt 2>/dev/null; echo none)" "none" "apply BLOCK_MISSING: step 2's apply never ran"
assert_not_contains "$out" "Nothing was rolled back" \
  "apply BLOCK_MISSING: bypasses fail_policy entirely (design choice — see run-migration.sh's header)"
rm -rf "$tmp"

echo
echo "== run-migration.sh: verify BLOCK_MISSING — normal refusal at L7, then reached via stub =="

# 0045-unclosed-fence-verify.md: an unclosed role=verify fence at EOF. L7
# catches this at lint time (unlike 0041's pre-L7 era), so a normal
# invocation refuses before the dispatch loop ever runs. The dispatch loop's
# own verify BLOCK_MISSING branch is reached only via the same
# stub-collaborator technique used for 0042/0044 (a stubbed lint gate that
# always exits 0) — see those fixtures' own comments for why that technique
# carries zero bypass surface in the shipped script.
tmp="$(mktemp -d)"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0045-unclosed-fence-verify.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "verify BLOCK_MISSING: normally refused at the lint gate (L7), never reaching dispatch"
assert_contains "$out" "L7" "verify BLOCK_MISSING: the refusal is attributed to L7"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "verify BLOCK_MISSING: nothing ran"

stubdir="$(mktemp -d)"
ln -s "$MR/run-migration.sh" "$stubdir/run-migration.sh"
ln -s "$MR/extract.sh" "$stubdir/extract.sh"
cat > "$stubdir/lint-migration.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$stubdir/lint-migration.sh"

out="$(cd "$tmp" && bash "$stubdir/run-migration.sh" --host codex-workflow "$FIX/0045-unclosed-fence-verify.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "verify BLOCK_MISSING: past a stubbed-clean lint gate, the dispatch loop aborts"
assert_contains "$out" "verify block missing" "verify BLOCK_MISSING: diagnostic names the block as missing"
assert_not_contains "$out" "verify failed" "verify BLOCK_MISSING: a missing block is not misreported as a failed one"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "applied" \
  "verify BLOCK_MISSING: apply DID run (only verify is missing) — its artefact is on disk"
assert_not_contains "$out" "Nothing was rolled back" \
  "verify BLOCK_MISSING: also bypasses fail_policy, same design choice as the apply case"
rm -rf "$tmp" "$stubdir"; trap - EXIT

echo
echo "TOTAL: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
