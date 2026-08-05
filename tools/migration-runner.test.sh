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
# PREFLIGHT. `tree_snapshot` below is the primary rollback oracle for group 7
# and it hashes with `shasum`, whose stderr it discards. On a box without
# `shasum` — a bare ubuntu:24.04 container has no Perl, so no shasum — every
# snapshot came back EMPTY, "before" equalled "after" for the wrong reason,
# and seventeen rollback assertions failed with a message pointing at the
# fixtures rather than at the missing tool. A suite whose oracle can quietly
# become vacuous has to say so out loud, so the absence is now fatal here
# instead of misattributed there.
for tool in shasum find sort; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "migration-runner.test.sh: required tool '$tool' is not on PATH." >&2
    echo "  tree_snapshot() hashes with shasum and would otherwise report an" >&2
    echo "  empty snapshot for every tree, turning every rollback check vacuous." >&2
    exit 2
  }
done

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
  # BLIND SPOTS, recorded here because group 7 is the first caller to lean on
  # this as its primary rollback oracle rather than a spot-check: `-type f`
  # only, so it reports nothing about empty directories, symlinks (neither
  # their target nor their own existence), or file modes/permissions — an
  # apply/rollback pair that differs only in one of those leaves this
  # function blind and an equality check built on it will pass regardless.
  #
  # PORTABILITY (group 7 fix round 2, found by running in an Alpine
  # container, not by reasoning): the previous `find ... -print0 | xargs -0
  # shasum` skips invoking `shasum` on empty input under BSD xargs (macOS),
  # but GNU and busybox xargs (Linux) run it once regardless — `shasum`
  # then reads stdin as data and hashes zero bytes, so an EMPTY directory
  # snapshots to `da39a3ee...  -` on Linux instead of to nothing. `find
  # -exec ... +` does not have this discrepancy on any of the three: the
  # utility is invoked only if at least one file matched, consistently.
  # Verified both ways: see task-7-report.md fix round 2 for the Linux
  # container run this replaced.
  ( cd "$1" && find . -type f -exec shasum {} + 2>/dev/null | sort )
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
# FIX ROUND 4, MINOR. This used to exit 1 — the VIOLATION code — through a
# bare `${THRESHOLD:?...}` expansion, so a CI job that forgot --host got the
# same status a malformed document produces, plus a raw bash diagnostic. Every
# usage error in this script is 64 now; 65 stays reserved for a resolvable-but-
# wrong host/threshold VALUE and 66 for a missing document. RED, before:
#   lint-migration.sh: line 153: THRESHOLD: lint: --threshold or --host is
#   required ...   rc=1
out="$(bash "$MR/lint-migration.sh" "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "64" "no-scope: omitting both --threshold and --host is a usage error (64), not a violation (1)"
assert_contains "$out" "threshold" "no-scope: error names what could not be resolved"
assert_not_contains "$out" "line " "no-scope: error is not a raw bash parameter-expansion message"

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
# TASK 9, FIX ROUND 1: the MACHINE-CHECKED assertions that used to follow
# this comment — extracting the pre-L7 (e22db7f) lint-migration.sh from git
# history via `git show` and running it for real against this fixture —
# were removed. They asserted a historical fact about code that no longer
# exists (that the OLD linter lints this clean) and never executed TODAY's
# linter, so they could not have caught a regression in it: provenance, not
# a guard. That also made them a hard CI dependency on this repo's own git
# history surviving indefinitely (via `git show <sha>`), which breaks for
# every future PR once this branch's commits are unreachable, and which a
# host running these scripts from a shared install has no history for at
# all. The RED-state evidence is preserved above, in prose, including the
# exact verbatim output this fixture used to produce under the pre-L7
# linter. The assertion that actually matters — that TODAY's linter still
# catches this — is immediately below, and it regresses the moment L7 does.
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
#
# THE COMMENT THAT USED TO SIT HERE WAS FALSE AND IS DELETED. It read: "Lint
# alone cannot catch this (every per-step rule iterates zero times over an
# empty step list, so lint-migration.sh itself exits 0 clean on this fixture)
# — only the runner's own zero-steps refusal closes this one." The
# parenthetical is true and the conclusion does not follow from it: a linter
# can COUNT `### Step ` headings exactly as L6 already iterates them, without
# any per-step rule running at all. It was a false absolute of precisely the
# kind this branch's history exists to warn about, and it shipped inside the
# test file. lint-migration.sh now reports the zero-steps case itself, which is
# what matters, because §08's Conformance section requires an adopting host to
# run the LINTER in CI — CI does not run the runner, so before this rule that
# CI was green on a document that cannot run.
#
# The runner's own refusal is retained and still asserted, below, past a
# stubbed-clean lint gate: it is the guard that holds when the lint gate is
# bypassed.
out="$(bash "$MR/lint-migration.sh" --host codex-workflow "$FIX/0039-zero-steps.md" 2>&1)"
assert_eq "$?" "1" "zero-steps: the LINTER now rejects a zero-step document (it used to exit 0 clean)"
assert_contains "$out" "declares no '### Step ' heading" "zero-steps: the linter names the problem"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0039-zero-steps.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses a zero-step migration"
assert_contains "$out" "declares no '### Step ' heading" "the runner surfaces the linter's zero-steps diagnostic"
rm -rf "$tmp"; trap - EXIT

# The runner's OWN zero-steps refusal, past a stubbed-clean lint gate. Adding
# the lint rule above moved which gate fires first for this fixture through the
# real CLI; without this, the runner's branch would have been left with zero
# coverage — the same coverage-regression the 0038 stub below was added for.
tmp="$(mktemp -d)"; stubdir="$(mktemp -d)"; trap 'rm -rf "$tmp" "$stubdir"' EXIT
ln -s "$MR/run-migration.sh" "$stubdir/run-migration.sh"
ln -s "$MR/extract.sh" "$stubdir/extract.sh"
cat > "$stubdir/lint-migration.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$stubdir/lint-migration.sh"
out="$(cd "$tmp" && bash "$stubdir/run-migration.sh" --host codex-workflow "$FIX/0039-zero-steps.md" "$tmp" 2>&1)"
assert_eq "$?" "65" \
  "past a stubbed-clean lint gate, the runner's OWN zero-steps refusal still fires"
assert_contains "$out" "declares no steps" "the runner's own zero-steps message is still reachable"
assert_not_contains "$out" "### Step " "this is the runner speaking, not the (stubbed-out) linter"
rm -rf "$tmp" "$stubdir"; trap - EXIT

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
assert_contains "$out" "L8: step 1: role 'apply' contains no executable statement" \
  "the runner's lint gate (L8) names the empty apply block"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "nothing was written by the empty apply block"
rm -rf "$tmp"; trap - EXIT

# COVERAGE REGRESSION, fix round 1 of task 6's review. L8 catching this
# fixture at the lint gate means the runner's OWN pre-flight "no apply
# block" check (the "step 1 has no apply block" message, distinct from L8's
# "role 'apply' is empty or whitespace-only") is no longer reachable through
# the real CLI for THIS fixture's shape — and the assertion that used to
# cover it was simply re-pointed at L8's message above, leaving that
# pre-flight branch with zero coverage. Same stub-collaborator technique as
# 0042/0044/0045: a stubbed-clean lint gate reaches the runner's own
# pre-flight scan directly, past L8 entirely.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
stubdir="$(mktemp -d)"
ln -s "$MR/run-migration.sh" "$stubdir/run-migration.sh"
ln -s "$MR/extract.sh" "$stubdir/extract.sh"
cat > "$stubdir/lint-migration.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$stubdir/lint-migration.sh"

out="$(cd "$tmp" && bash "$stubdir/run-migration.sh" --host codex-workflow "$FIX/0038-zero-apply-step.md" "$tmp" 2>&1)"
assert_eq "$?" "65" \
  "past a stubbed-clean lint gate, the runner's OWN pre-flight scan still refuses an empty apply block"
assert_not_contains "$out" "step 1: applied" "the runner does not report success"
assert_contains "$out" "step 1 has no apply block" \
  "the runner's own pre-flight message is still reachable (past a bypassed lint gate)"
assert_not_contains "$out" "L8" \
  "this is the runner's pre-flight scan speaking, not the (stubbed-out) linter"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" \
  "nothing was written by the empty apply block"
rm -rf "$tmp" "$stubdir"; trap - EXIT

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
# fixture.txt) before step 2's apply fails. This invocation gives no
# --on-failure, so the policy is TTY-derived — which, since group 6, means
# an apply failure with no redirect here would resolve to `prompt` and block
# on `read` under a REAL terminal. `</dev/null` forces the non-interactive
# default (abort) deliberately: this section is about the exit-code
# distinction, not the failure policy, and task 6 found by construction
# (fix round 1 of that task, under a real pty via a Python `pty.fork()`
# harness — not `script(1)`, which this repo's sandbox cannot use to
# reproduce a genuine hang; see that round's report) that a
# now-stale version of THIS comment once claimed stdin "is never a
# terminal... under this test harness" — true when task 5 wrote it, false
# the moment task 6 gave fail_policy a real prompt branch, and exactly the
# kind of claim the standing instruction warns against making without an
# executed case. The observable difference from every refusal case above is
# that step 1's artefact SURVIVES on disk — that is "ran partway, tree may
# have changed" made concrete, not merely a different number.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0036-failing-apply.md" "$tmp" </dev/null 2>&1)"
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

# IMPORTANT 3, fix round 1 of task 6's review. L8 must check extract.sh
# block's own exit status before trusting a captured (or empty) body — an
# extraction FAILURE is not the same thing as an empty body. Probe:
# 0045-unclosed-fence-verify.md's verify fence has real content (one real
# grep command) and is simply never closed before EOF — `roles` reports it
# present (from the fence's OPENING line) but `extract.sh block` exits 1 for
# it (mr_block only confirms a role on the CLOSING line). Confirmed by
# extracting the actual pre-fix lint-migration.sh from the commit this task
# shipped (4592eaa) and running it directly against this exact fixture:
#   L8: step 1: role 'verify' is empty or whitespace-only
#   L7: step 1: fence opened at line 53 (info string: bash role=verify) is
#   never closed before end of file
# — L8 fired first, and is simply FALSE (the body is real, non-empty
# content; extraction never got to return it). L7 alone is correct.
# TASK 9, FIX ROUND 1: the MACHINE-CHECKED assertions that used to follow
# this comment — extracting the pre-fix (4592eaa) lint-migration.sh from
# git history and running it for real against this fixture to prove L8
# used to misreport it — were removed, for the same reason as the L7 block
# above: a historical fact about deleted code, never executing today's
# linter, and a hard dependency on this repo's own git history (`git show
# <sha>`) that breaks for every future PR once the commit is unreachable,
# and that a shared install has no history for regardless. The RED-state
# evidence is preserved above, in prose, verbatim. The assertion that
# matters — that TODAY's linter no longer misreports this — is immediately
# below, and it regresses the moment that fix does.
out="$(bash "$MR/lint-migration.sh" --host codex-workflow "$FIX/0045-unclosed-fence-verify.md" 2>&1)"
assert_eq "$?" "1" "L8 fix: 0045 still lints dirty (L7 fires)"
assert_contains "$out" "L7" "L8 fix: L7 still correctly diagnoses the unclosed fence"
assert_not_contains "$out" "role 'verify' contains no executable statement" \
  "L8 fix: no longer misreports an extraction FAILURE as an empty body"

echo
echo "== lint-migration.sh: L8 widened — no executable statement, any role =="

# CRITICAL 2 of the final whole-branch review. L8 used to test emptiness with
# `tr -d '[:space:]'`, so a body of `# TODO: check whether the allowlist is
# already hardened` was ONE CHARACTER past it. RED, reproduced against the real
# CLI on 0053 before the widening:
#   $ lint-migration.sh --host claude-workflow <doc> ; echo $?
#   0
#   $ run-migration.sh --host claude-workflow <doc> wd ; echo $?
#   step 1: skipped (already applied)
#   0
#   $ ls -a wd    # empty — the security-relevant apply was never attempted
# `bash -c '# ...'` exits 0 and the three-valued check contract reads exit 0 as
# ALREADY APPLIED. This is strictly worse than the apply-only-a-comment variant
# an earlier round put on the deferred list as an accepted gap (0055 below):
# there, the step is attempted and vacuous; here it is never attempted at all.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0053-bad-l8-comment-only-check.md" 2>&1)"
assert_eq "$?" "1" "L8: a comment-only check fence exits 1"
assert_contains "$out" "L8: step 1: role 'check' contains no executable statement" \
  "L8: names the rule and the role for a comment-only check"
assert_not_contains "$out" "L1" "L8: does NOT also fire L1 — the role IS present, just vacuous"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0053-bad-l8-comment-only-check.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses a comment-only check at the lint gate"
assert_not_contains "$out" "skipped (already applied)" \
  "the runner never reaches the silent-no-op skip this fixture used to produce"
assert_eq "$(ls "$tmp"/settings.json 2>/dev/null; echo none)" "none" \
  "nothing ran for the comment-only-check migration"
rm -rf "$tmp"; trap - EXIT

# The `:` variant. A bare no-op builtin as the WHOLE body is counted as
# non-executable — a decision, recorded in lint-migration.sh's L8 note: `:`
# provably does nothing and exits 0, which is the same observable outcome as an
# empty body, reached deliberately. RED before the widening: lint 0,
# `step 1: skipped (already applied)`, empty workdir.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0054-bad-l8-noop-builtin-check.md" 2>&1)"
assert_eq "$?" "1" "L8: a check fence whose whole body is ':' exits 1"
assert_contains "$out" "L8: step 1: role 'check' contains no executable statement" \
  "L8: names the rule and the role for a bare no-op builtin"

# `:` INSIDE a larger body is ordinary shell and must be left completely alone
# — the rule strips it only as a whole line. Without this, `while :; do` and
# `: "${VAR:?}"` would start failing the linter, which is the false-positive
# direction this decision must not fall into.
probe="$(mktemp -d)/0061-colon-inside.md"
sed "s|^:$|while :; do break; done|" "$FIX/0054-bad-l8-noop-builtin-check.md" \
  | sed "s|^id: 0054|id: 0061|" > "$probe"
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$probe" 2>&1)"
assert_eq "$?" "0" "L8: ':' inside a larger statement ('while :; do') is untouched — no false positive"
assert_eq "$out" "" "L8: and reports nothing at all for it"
rm -rf "$(dirname "$probe")"

# The apply-only-a-comment variant: the previously-deferred gap, closed by the
# same one-line widening rather than deferred a second time.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0055-bad-l8-comment-only-apply.md" 2>&1)"
assert_eq "$?" "1" "L8: a comment-only apply fence exits 1"
assert_contains "$out" "L8: step 1: role 'apply' contains no executable statement" \
  "L8: names the rule and the role for a comment-only apply"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0055-bad-l8-comment-only-apply.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses a comment-only apply at the lint gate"
assert_not_contains "$out" "step 1: applied" \
  "the runner never reports the vacuous success this fixture used to produce"
rm -rf "$tmp"; trap - EXIT

echo
echo "== lint-migration.sh: L9/L10 — a fence line inside a heredoc truncates a block =="

# CRITICAL 1 of the final whole-branch review, committed verbatim as
# 0052-bad-l9-heredoc-fence.md. extract.sh's mr_block ends its capture on ANY
# line whose first three characters are three backticks, INCLUDING one inside a
# heredoc body. §08 already mandated heredoc-awareness for `### Step` headings
# and was silent on the identical hazard for fences.
#
# RED, reproduced against the real CLI before L9/L10 existed:
#   $ lint-migration.sh --host claude-workflow 0039-patch-claude-md.md ; echo $?
#   0
#   $ run-migration.sh --host claude-workflow 0039-patch-claude-md.md wd
#   step 1: applied              rc=0
#   $ cat wd/CLAUDE.md
#   # CLAUDE.md
#
#   ## Running the suite         <- and NOTHING else; the payload is truncated
#   $ run-migration.sh ... wd
#   step 1: skipped (already applied)   <- self-certifies as done, forever
#
# Every existing guard passed it: L1 reads the role from the OPENING line, L7
# balances, L8 sees a non-empty body, the runner's zero-apply pre-flight sees a
# non-empty body, and `bash -c` on an unterminated heredoc writes the partial
# payload and exits 0.
#
# WHAT THE FLEET ACTUALLY LOOKS LIKE, MEASURED. An earlier version of this
# comment said "6 of the 73 migrations in the fleet today already emit a
# three-backtick line from inside a heredoc". That number was relayed from a
# review and never measured; it is wrong. Counted directly across all four
# hosts' migrations/ directories — 73 numbered migrations (claude-workflow 34,
# codex-workflow 16, opencode-workflow 12, pi-agentic-apps-workflow 11):
#   - 7 use a heredoc at all inside a fenced body;
#   - 0 emit a three-backtick line from inside a heredoc;
#   - 0 emit a three-backtick line into a file by any means. (Three documents
#     contain a three-backtick sequence inside a fenced body, but each is a
#     regex or a prose comment — `/^```/ { fence = !fence }` and the like —
#     never emitted output.)
# L9 and L10 are justified by the constructed vulnerability below, which is
# real, executed, and committed as a fixture. They are not justified by the
# idiom being common, because on today's fleet it is not.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0052-bad-l9-heredoc-fence.md" 2>&1)"
assert_eq "$?" "1" "L9: a tagged fence truncated by a nested fence line exits 1"
assert_contains "$out" "L9: step 1: role 'apply' fence opened at line" "L9: names the rule, the step and the role"
assert_contains "$out" "is terminated by a nested fence line at line" "L9: names the truncation"
assert_contains "$out" "(info string: bash)" "L9: quotes the nested fence's own info string"
assert_contains "$out" "L10: step 1: role 'apply' opens a heredoc delimited by 'EOF'" \
  "L10: independently reports the unterminated heredoc the truncation leaves behind"

# THE TRUNCATION IS REAL, not merely reported — asserted against extract.sh
# directly so the rule is anchored to an observable rather than to its own
# message. The captured body stops at the nested fence, so the heredoc
# terminator never appears in it.
body="$(bash "$MR/extract.sh" block "$FIX/0052-bad-l9-heredoc-fence.md" 1 apply)"
assert_eq "$?" "0" "L9: extract.sh still returns a (truncated) body — which is why nothing else caught this"
assert_contains "$body" "cat >> CLAUDE.md <<'EOF'" "L9: the captured body does open the heredoc"
assert_not_contains "$body" "bash tools/migration-runner.test.sh" \
  "L9: and the captured body is genuinely truncated before the payload's own fenced command"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '# CLAUDE.md\n' > "$tmp/CLAUDE.md"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0052-bad-l9-heredoc-fence.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses the truncated-heredoc migration at the lint gate"
assert_not_contains "$out" "step 1: applied" "the runner does not report the truncated apply as success"
assert_eq "$(cat "$tmp/CLAUDE.md")" "# CLAUDE.md" \
  "the truncated payload was never written — CLAUDE.md is byte-identical to before"
rm -rf "$tmp"; trap - EXIT

# THERE IS NO ESCAPE VIA A FOUR-BACKTICK OUTER FENCE, so L9 does not forbid
# something the format otherwise permits. A four-backtick opener's info string
# starts with a backtick and fails the `^bash[ \t]+role=[a-z]+$` grammar, so
# the fence carries no role at all.
probe4="$(mktemp -d)/probe4.md"
printf '### Step 1: x\n\n**Apply:**\n````bash role=apply\necho hi\n````\n' > "$probe4"
out="$(bash "$MR/extract.sh" roles "$probe4" 1)"
assert_eq "$?" "0" "four-backtick probe: extract.sh roles runs cleanly"
assert_eq "$out" "" \
  "four-backtick probe: a four-backtick fence carries NO role — it is not an escape hatch L9 takes away"
rm -rf "$(dirname "$probe4")"

# L10 IS NOT A RESTATEMENT OF L9. 0058 has no nested fence anywhere, every
# fence opens and closes normally, and its apply body is non-empty and
# comment-free — so L7, L8 and L9 all pass it. Only the heredoc terminator is
# mistyped, and `bash -c` on that body writes a partial payload and exits 0,
# which is the same silent-partial-write outcome by a different route.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0058-bad-l10-mistyped-heredoc.md" 2>&1)"
assert_eq "$?" "1" "L10: a mistyped heredoc terminator exits 1"
assert_contains "$out" "L10: step 1: role 'apply' opens a heredoc delimited by 'EOF'" "L10: names the rule and the delimiter"
assert_not_contains "$out" "L9" "L10: fires ALONE here — there is no nested fence for L9 to see"
assert_not_contains "$out" "L7" "L10: and no unclosed fence for L7 to see"
assert_not_contains "$out" "L8" "L10: and the body is not empty, so L8 is silent too"

# L10 MUST NOT FIRE ON A WELL-FORMED HEREDOC. 0031's apply block is a heredoc
# whose body contains the literal line "### Step 2" and whose terminator is
# present and correct — the exact shape a naive scanner would trip over.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0031-heredoc-step-heading.md" 2>&1)"
assert_eq "$?" "0" "L10: a correctly terminated heredoc is clean — no false positive"
assert_eq "$out" "" "L10: and reports nothing at all for it"

# L10'S FALSE-POSITIVE GUARDS, each exercised rather than described. The scan
# reads shell redirection operators by hand (bash 3.2's own parser is silent on
# an unterminated heredoc — see lint-migration.sh's L10 note), so every shape
# that merely LOOKS like `<<` must be proven not to fire. Each probe below
# substitutes one such line into 0060's apply block, which is otherwise clean.
# The replacement is passed through a FILE, not `awk -v`: awk rejects a literal
# newline inside a -v assignment ("awk: newline in string"), and several of the
# probes below are deliberately multi-line. Caught by these very assertions
# going red rather than by inspection.
mr_l10_probe() { # $1=apply body to substitute (may be multi-line)  $2=description
  local dir out rc
  dir="$(mktemp -d)"
  printf '%s\n' "$1" > "$dir/repl.txt"
  awk -v f="$dir/repl.txt" '
    /^printf .root = true/ { while ((getline l < f) > 0) print l; close(f); next }
    { print }
  ' "$FIX/0060-first-migration.md" | sed "s|^id: 0060|id: 0090|" > "$dir/0090-l10-probe.md"
  out="$(bash "$MR/lint-migration.sh" --threshold 16 "$dir/0090-l10-probe.md" 2>&1)"
  rc=$?
  assert_eq "$rc" "0" "L10 false-positive guard: $2 — lints clean"
  assert_eq "$out" "" "L10 false-positive guard: $2 — reports nothing"
  rm -rf "$dir"
}
mr_l10_probe 'x=$((1<<2)); printf "%s\n" "$x" > .editorconfig'  'a left-shift inside $((...)) is not a heredoc'
mr_l10_probe 'echo "a << b" > .editorconfig'                    'a << inside double quotes is not a heredoc'
mr_l10_probe "echo 'a << b' > .editorconfig"                    'a << inside single quotes is not a heredoc'
mr_l10_probe 'cat <<<"herestring" > .editorconfig'              'a <<< herestring is not a heredoc'
mr_l10_probe 'cat <<-EOT > .editorconfig
	root = true
	EOT'                                                          'a <<- heredoc terminated after leading tabs is fine'
mr_l10_probe 'cat <<A > .editorconfig; cat <<B >> .editorconfig
root = true
A
more = true
B'                                                              'two heredocs declared on one line, both terminated in order'

# And the positive control for the same helper: a genuinely unterminated
# heredoc substituted the same way DOES fire, so the six clean results above
# are not clean merely because the helper never detects anything.
probe_dir="$(mktemp -d)"
printf '%s\n' 'cat <<EOF > .editorconfig' 'root = true' > "$probe_dir/repl.txt"
awk -v f="$probe_dir/repl.txt" '
  /^printf .root = true/ { while ((getline l < f) > 0) print l; close(f); next }
  { print }
' "$FIX/0060-first-migration.md" | sed "s|^id: 0060|id: 0091|" > "$probe_dir/0091-l10-control.md"
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$probe_dir/0091-l10-control.md" 2>&1)"
assert_eq "$?" "1" "L10 positive control: the same helper's substitution DOES fire on a real unterminated heredoc"
assert_contains "$out" "L10: step 1: role 'apply' opens a heredoc delimited by 'EOF'" \
  "L10 positive control: and names it"
rm -rf "$probe_dir"

echo
echo "== L10: the two holes the scoped re-review found, both directions asserted =="

# A RULE THAT REJECTS A VALID MIGRATION IS AS BAD AS ONE THAT MISSES AN INVALID
# ONE, so both directions are pinned here rather than only the detection.

# ---- DIRECTION 1: 0061 MUST BE ACCEPTED ----------------------------------
#
# L10 did not skip whole-line comments, so it read a heredoc opener out of
# PROSE. The worst case was a migration following this runner's own README:
# emit the payload with `printf` instead of a heredoc, and say why in a
# comment. RED against the real CLI before the fix:
#   $ lint-migration.sh --threshold 16 0061-l10-comment-mentions-heredoc.md
#   L10: step 1: role 'apply' opens a heredoc delimited by 'EOF' that is never
#   terminated in the captured body — running it writes a partial payload and
#   still exits 0
#   $ echo $?
#   1
# Every substantive clause of that message was false: no heredoc is opened, nothing is unterminated, and no partial payload is written. Only the trailing "and still exits 0" is true, and it is true of the CORRECT behaviour — the body exits 0 having written the payload WHOLE. L8's scan in the same loop had
# discarded full-line `#` comments since it was written; L10 now agrees.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0061-l10-comment-mentions-heredoc.md" 2>&1)"
assert_eq "$?" "0" "L10 comment: a migration whose comment MENTIONS <<EOF lints clean"
assert_eq "$out" "" "L10 comment: with no diagnostics at all — no false accusation"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '# CLAUDE.md\n' > "$tmp/CLAUDE.md"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0061-l10-comment-mentions-heredoc.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "L10 comment: and it RUNS — the body was always valid bash"
assert_contains "$out" "step 1: applied" "L10 comment: the step applied"
assert_eq "$(cat "$tmp/CLAUDE.md")" "$(printf '%s\n' '# CLAUDE.md' '' '## Workflow')" \
  "L10 comment: the payload was written WHOLE — nothing was ever truncated"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0061-l10-comment-mentions-heredoc.md" "$tmp" 2>&1)"
assert_contains "$out" "step 1: skipped (already applied)" "L10 comment: and it is idempotent"
rm -rf "$tmp"; trap - EXIT

# The comment skip must NOT reach a heredoc PAYLOAD line that begins with `#` —
# emitting a markdown heading is the ordinary reason a migration has one. The
# heredoc-body branch runs before the comment skip, which is what keeps them
# apart; 0031's payload is exactly that shape.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0031-heredoc-step-heading.md" 2>&1)"
assert_eq "$?" "0" "L10 comment: a heredoc PAYLOAD line starting with # is still payload, not a comment"

# ---- DIRECTION 2: 0062 AND 0063 MUST BE REJECTED -------------------------
#
# CRITICAL 1, REACHABLE AGAIN. bash 3.2 treats `<<\EOF` exactly like `<<'EOF'`,
# but L10's delimiter parser accepted only `<<WORD`, `<<'W'` and `<<"W"`. And
# L9 stays silent because the truncating line is a BARE ``` — which is what an
# ordinary markdown fenced block is opened with. So NEITHER rule fired. RED,
# against the real CLI, before the backslash fix:
#   $ lint-migration.sh --threshold 16 0062-l10-backslash-bare-fence.md ; echo $?
#   0
#   $ run-migration.sh --host codex-workflow 0062-...md wd
#   step 1: applied            (rc 0)
#   $ cat wd/NOTES.md
#   # Notes
#   ## Running the suite       <- and NOTHING else
#   $ run-migration.sh --host codex-workflow 0062-...md wd
#   step 1: skipped (already applied)
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0062-l10-backslash-bare-fence.md" 2>&1)"
assert_eq "$?" "1" "L10 backslash: a <<\\EOF heredoc truncated by a BARE fence exits 1"
assert_contains "$out" "L10: step 1: role 'apply' opens a heredoc delimited by 'EOF'" \
  "L10 backslash: names the rule, the step, the role and the delimiter"
assert_not_contains "$out" "L9" \
  "L10 backslash: and L9 is silent here — the truncating line is BARE, which is why L10 has to carry this case"

# THE TRUNCATION IS REAL, not merely reported — anchored to extract.sh rather
# than to L10's own message, exactly as 0052's assertions are.
body="$(bash "$MR/extract.sh" block "$FIX/0062-l10-backslash-bare-fence.md" 1 apply)"
assert_eq "$?" "0" "L10 backslash: extract.sh still returns a (truncated) body"
assert_contains "$body" 'cat >> NOTES.md <<\EOF' "L10 backslash: the captured body does open the heredoc"
assert_not_contains "$body" "bash tools/migration-runner.test.sh" \
  "L10 backslash: and is genuinely truncated before the payload's own fenced command"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '# Notes\n' > "$tmp/NOTES.md"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0062-l10-backslash-bare-fence.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "L10 backslash: the runner refuses it at the lint gate"
assert_not_contains "$out" "step 1: applied" "L10 backslash: and never reports the truncated apply as success"
assert_eq "$(cat "$tmp/NOTES.md")" "# Notes" \
  "L10 backslash: the truncated payload was never written — NOTES.md is byte-identical to before"
rm -rf "$tmp"; trap - EXIT

# THE SAME HOLE IN A ROLLBACK is a different consequence, not a smaller one:
# the truncated body exits 0, so do_rollback records the rollback as having
# SUCCEEDED and the operator is told the tree was restored by a block that
# wrote a prefix of what it owed.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0063-l10-backslash-bare-rollback.md" 2>&1)"
assert_eq "$?" "1" "L10 backslash: the same shape in a ROLLBACK block exits 1"
assert_contains "$out" "L10: step 1: role 'rollback' opens a heredoc delimited by 'EOF'" \
  "L10 backslash: and names the rollback role specifically"

body="$(bash "$MR/extract.sh" block "$FIX/0063-l10-backslash-bare-rollback.md" 1 rollback)"
assert_eq "$?" "0" "L10 backslash: the truncated rollback body extracts"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
( cd "$tmp" && printf 'replaced\n' > NOTES.md && bash -c "$body" )
assert_eq "$?" "0" \
  "L10 backslash: the truncated rollback EXITS 0 — which is why the runner would report it as succeeded"
assert_eq "$(cat "$tmp/RESTORE.md")" "# restored" \
  "L10 backslash: having restored only a prefix — the fenced payload it owed is absent"
rm -rf "$tmp"; trap - EXIT

echo
echo "== lint-migration.sh: L11 — a sed -i only one of BSD and GNU accepts =="

# THIS RULE EXISTS BECAUSE THE CLASS SHIPPED IN THIS TREE, TWICE. Seven
# rollback blocks across six fixtures below carried `sed -i ''` (BSD-only) and
# §08's own worked example carried bare `sed -i` (GNU-only). The first set was
# green on macOS and red on every Linux; the second was the exact inverse.
# Neither survived contact with the other implementation, and neither was
# caught by review, because each reads correct to whoever shares the author's
# sed. Both directions are pinned here — a rule that rejects a valid migration
# is as bad as one that misses an invalid one.
mr_l11_probe() { # $1=apply body to substitute  $2=description  $3=expect: fire|clean
  local dir out rc
  dir="$(mktemp -d)"
  printf '%s\n' "$1" > "$dir/repl.txt"
  awk -v f="$dir/repl.txt" '
    /^printf .root = true/ { while ((getline l < f) > 0) print l; close(f); next }
    { print }
  ' "$FIX/0060-first-migration.md" | sed "s|^id: 0060|id: 0092|" > "$dir/0092-l11-probe.md"
  out="$(bash "$MR/lint-migration.sh" --threshold 16 "$dir/0092-l11-probe.md" 2>&1)"
  rc=$?
  if [ "$3" = "fire" ]; then
    assert_eq "$rc" "1" "L11: $2 — exits 1"
    assert_contains "$out" "L11: step 1: role 'apply'" "L11: $2 — names the rule, the step and the role"
  else
    assert_eq "$rc" "0" "L11 false-positive guard: $2 — lints clean"
    assert_eq "$out" "" "L11 false-positive guard: $2 — reports nothing at all"
  fi
  rm -rf "$dir"
}

# ---- MUST FIRE ----------------------------------------------------------
# Both non-portable spellings share one shape — a standalone `-i` token — so
# both are caught by one check and reported with one message. The message
# deliberately does not claim to know WHICH the author meant, because the text
# cannot tell and the fix is the same either way.
mr_l11_probe "sed -i '' 's/a/b/' .editorconfig"       'the BSD detached-suffix spelling'      fire
mr_l11_probe "sed -i 's/a/b/' .editorconfig"          'the GNU bare -i spelling'             fire
mr_l11_probe "sed --in-place 's/a/b/' .editorconfig"  'the GNU-only --in-place long option'  fire
mr_l11_probe "printf 'x\n' > .editorconfig; sed -i '' 's/a/b/' .editorconfig" \
  'a non-portable sed later in a compound line'                                              fire

# ---- MUST NOT FIRE ------------------------------------------------------
mr_l11_probe "sed -i.bak 's/a/b/' .editorconfig && rm -f .editorconfig.bak" \
  'the portable attached-suffix form — the one this rule is steering toward'                 clean
mr_l11_probe "sed 's/a/b/' .editorconfig > .tmp && mv .tmp .editorconfig" \
  'a sed with no -i at all'                                                                  clean
# The comment probe carries a real command TOO. Without one the body is pure
# comment, L8 fires on the emptiness, and the probe goes red for a reason that
# has nothing to do with L11 — which is exactly what happened when this was
# first written, and is why the pairing is spelled out rather than assumed.
mr_l11_probe "# sed -i '' 's/a/b/' file  <- explaining the bug in a comment
printf 'root = true\n' > .editorconfig" \
  'a whole-line comment MENTIONING the bad form is prose, not a command'                     clean
mr_l11_probe "gsed -i 's/a/b/' .editorconfig" \
  'gsed is GNU by name — the author has already chosen an implementation'                    clean

# A HEREDOC BODY IS PAYLOAD, NOT A COMMAND. A migration that WRITES a script
# containing `sed -i ''` is emitting text; flagging it would repeat exactly the
# false positive L10 already cost this format once (see 0061). Pinned in both
# directions on ONE probe: the heredoc payload stays silent while a real
# command on the line after the terminator still fires.
mr_l11_probe "cat <<'EOF' > .editorconfig
sed -i '' 's/a/b/' somefile
EOF" 'a bad sed inside a heredoc payload is emitted, not run'                                clean
mr_l11_probe "cat <<'EOF' > .editorconfig
sed -i '' 's/a/b/' somefile
EOF
sed -i '' 's/c/d/' .editorconfig" \
  'but a real one AFTER the terminator is still seen — the skip ends with the heredoc'       fire

echo
echo "== L8's residual: the rule rejects the provably inert, not the merely useless =="

# STATED HONESTLY RATHER THAN CLOSED. L8 rejects a body with nothing left after
# blank lines, whole-line `#` comments and the whole-line no-op builtins `:`
# and `true` are discarded. That is a WHOLE-LINE LEXICAL test, and the bodies
# below all get past it while accomplishing nothing on an untouched tree. They
# are pinned here as ACCEPTED so that the limit is machine-checked and cannot
# be quietly re-described as closed.
#
# THIS IS NOT A BUG LIST TO BURN DOWN. "Does this shell do anything?" is not
# decidable by inspection, and widening the rule to chase these would start
# rejecting real migrations — which is the failure mode 0061 above exists to
# prevent. lint-migration.sh's L8 comment previously said stripping `true`
# closed a hole that was otherwise "one keystroke away"; `true; true` is that
# keystroke, and it is right here.
mr_l8_residual() { # $1=check body  $2=description
  local dir out rc
  dir="$(mktemp -d)"
  printf '%s\n' "$1" > "$dir/repl.txt"
  awk -v f="$dir/repl.txt" '
    /^test -f \.editorconfig$/ { while ((getline l < f) > 0) print l; close(f); next }
    { print }
  ' "$FIX/0060-first-migration.md" | sed "s|^id: 0060|id: 0092|" > "$dir/0092-l8-residual.md"
  out="$(bash "$MR/lint-migration.sh" --threshold 16 "$dir/0092-l8-residual.md" 2>&1)"
  rc=$?
  assert_eq "$rc" "0" "L8 residual (ACCEPTED, documented limit): $2"
  assert_eq "$out" "" "L8 residual: $2 — and L8 says nothing about it"
  rm -rf "$dir"
}
mr_l8_residual 'true; true'   'two no-ops on one line are not a whole-line no-op'
mr_l8_residual ':;:'          'two colons on one line likewise'
mr_l8_residual '( : )'        'a no-op in a subshell likewise'
mr_l8_residual 'exit 0'       'an explicit exit 0 is a real statement that does nothing'
mr_l8_residual 'echo "checking whether the allowlist is hardened"' \
                              'an echo that only NARRATES the check is a real statement'

# The residual is a LIMIT, not an absence of a rule: the shapes L8 does reject
# are still rejected. 0053/0054 are the committed guards for that, asserted
# above; this is the boundary between them, stated in one place.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0054-bad-l8-noop-builtin-check.md" 2>&1)"
assert_eq "$?" "1" "L8 residual: a WHOLE-LINE no-op builtin is still rejected — the rule did not go away"

echo
echo "== the three documented escapes for emitting a fence, executed end to end =="

# 0059 is the CONFORMANT counterpart to 0052: the same job — emit a fenced code
# block into a file — written the three ways the README documents. This exists
# so that "there is an escape" is an executed fact and not a claim, and so that
# tightening L9/L10 is provably not a dead end for a migration that needs to
# patch an instruction file.
#
# STEP 3 (`<<-` with a TAB-indented payload) WAS ADDED AFTER THE README ALREADY
# SAID "TWO ESCAPES WORK". It is strictly better than step 2's indent escape on
# both axes that matter — the emitted fence lands at column 1 (byte-exact,
# where step 2 costs one leading space forever) and the migration's own source
# keeps the nested fence off column 1, which is what the fence state machine
# tests. It was found by trying it rather than by reasoning about it, which is
# also how the README came to be wrong about the count.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0059-heredoc-fence-escape.md" 2>&1)"
assert_eq "$?" "0" "escape: the printf, indented-heredoc and tab-stripped-heredoc forms lint clean"
assert_eq "$out" "" "escape: with no diagnostics at all"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '# Notes\n' > "$tmp/NOTES.md"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0059-heredoc-fence-escape.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "escape: all three steps run to completion"
assert_contains "$out" "step 1: applied" "escape: the printf form applied"
assert_contains "$out" "step 2: applied" "escape: the indented-heredoc form applied"
assert_contains "$out" "step 3: applied" "escape: the tab-stripped-heredoc form applied"
# BYTE-EXACT, not a substring probe. `assert_contains` shells out to `grep
# -qF`, which treats a MULTI-LINE needle as a set of alternative single-line
# patterns — so a multi-line "contains" check here would have passed on any ONE
# of its lines and silently stopped proving the block was emitted whole. The
# whole file is compared instead: step 1's printf form reproduces the payload
# byte-for-byte with the fence at column 1, step 2's indented-heredoc form
# costs exactly one leading space (below CommonMark's three-space limit, so the
# emitted block still renders as a fenced block), and step 3's `<<-` form
# reproduces it byte-for-byte with the fence at column 1 like step 1 does.
#
# THIS ASSERTION IS ALSO THE GUARD ON STEP 3'S TABS. `<<-` strips leading TABS
# only; spaces survive verbatim. If anything ever converts 0059's tabs to
# spaces, step 3 stops being an escape and becomes 0052's defect, and the
# ' ```text'-style leading whitespace shows up here as an inequality.
expected_notes="$(printf '%s\n' \
  '# Notes' \
  '' \
  '## Running the suite' \
  '' \
  '```bash' \
  'bash tools/migration-runner.test.sh' \
  '```' \
  '' \
  '## Indented escape' \
  '' \
  ' ```text' \
  ' payload' \
  ' ```' \
  '' \
  '## Dash escape' \
  '' \
  '```text' \
  'payload' \
  '```')"
assert_eq "$(cat "$tmp/NOTES.md")" "$expected_notes" \
  "escape: all three forms emitted complete, correctly-fenced blocks — the file matches byte for byte"

# Idempotent on a second run, per §08's idempotency contract.
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0059-heredoc-fence-escape.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "escape: a second run exits 0"
assert_contains "$out" "step 1: skipped (already applied)" "escape: step 1 is skipped on re-run"
assert_contains "$out" "step 2: skipped (already applied)" "escape: step 2 is skipped on re-run"
assert_contains "$out" "step 3: skipped (already applied)" "escape: step 3 is skipped on re-run"

# Rollback round trip, in reverse document order, back to the seeded state.
body="$(bash "$MR/extract.sh" block "$FIX/0059-heredoc-fence-escape.md" 3 rollback)"
assert_eq "$?" "0" "escape: step 3 rollback extracted"
( cd "$tmp" && bash -c "$body" ); assert_eq "$?" "0" "escape: step 3 rolled back"
body="$(bash "$MR/extract.sh" block "$FIX/0059-heredoc-fence-escape.md" 2 rollback)"
assert_eq "$?" "0" "escape: step 2 rollback extracted"
( cd "$tmp" && bash -c "$body" ); assert_eq "$?" "0" "escape: step 2 rolled back"
body="$(bash "$MR/extract.sh" block "$FIX/0059-heredoc-fence-escape.md" 1 rollback)"
assert_eq "$?" "0" "escape: step 1 rollback extracted"
( cd "$tmp" && bash -c "$body" ); assert_eq "$?" "0" "escape: step 1 rolled back"
assert_eq "$(cat "$tmp/NOTES.md")" "# Notes" \
  "escape: rolling both back in reverse document order restores the seeded file exactly"
rm -rf "$tmp"; trap - EXIT

echo
echo "== lint-migration.sh: an in-scope migration must declare at least one step =="

# IMPORTANT 3. §08 ("Step structure") has always said "Every migration body
# MUST contain at least one step" and nothing enforced it at lint time. That
# mattered because §08's Conformance section requires an adopting host to run
# the LINTER in CI — so CI was green on a document that cannot run. The review
# hit this on its first authored migration by typing `## Step 1:` instead of
# `### Step 1:`, which is what 0056 is. RED, before this rule:
#   $ lint-migration.sh --host claude-workflow 0056-...md ; echo $?
#   0
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0056-bad-zero-steps-heading-typo.md" 2>&1)"
assert_eq "$?" "1" "steps: a heading typed '## Step 1:' yields zero steps and is rejected"
assert_contains "$out" "declares no '### Step ' heading" "steps: the linter names the problem"

# Reported WITHOUT a step number, like the other whole-document checks — there
# is no step to attach it to.
assert_not_contains "$out" "step 1:" "steps: the diagnostic carries no step number"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0056-bad-zero-steps-heading-typo.md" "$tmp" 2>&1)"
assert_eq "$?" "65" "the runner refuses the heading-typo migration"
assert_eq "$(ls "$tmp"/.editorconfig 2>/dev/null; echo none)" "none" "nothing ran for it"
rm -rf "$tmp"; trap - EXIT

echo
echo "== lint-migration.sh: applies_to must be present on an in-scope migration =="

# The one frontmatter field this change newly makes load-bearing: at or above
# the threshold `applies_to` is the WRITE BOUNDARY an apply block may not
# cross, not merely plan-output metadata. Omitted entirely, the permitted write
# set is undefined and every statement about what the rollback owes the tree is
# vacuous. The linter checked no frontmatter field at all before fix round 4 —
# RED: 0057 is structurally perfect and linted clean at rc 0.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0057-bad-no-applies-to.md" 2>&1)"
assert_eq "$?" "1" "frontmatter: an in-scope migration with no applies_to is rejected"
assert_contains "$out" "no 'applies_to:' field" "frontmatter: the linter names the missing field"
assert_not_contains "$out" "L1" "frontmatter: the document is otherwise structurally perfect"

# ONLY PRESENCE IS CHECKED, and only for `applies_to`. The other §08-required
# frontmatter fields are deliberately not checked — none of them changes what a
# block is permitted to do. Proven by construction rather than asserted: 0057
# with an applies_to line added back lints CLEAN even though it still declares
# no slug, title, from_version or to_version.
probe="$(mktemp -d)/0062-applies-only.md"
awk '{ print } /^migration_format: executable$/ { print "applies_to:"; print "  - .editorconfig" }' \
  "$FIX/0057-bad-no-applies-to.md" | sed "s|^id: 0057|id: 0062|" > "$probe"
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$probe" 2>&1)"
assert_eq "$?" "0" "frontmatter: adding applies_to alone makes 0057's shape clean — no other field is checked"
assert_eq "$out" "" "frontmatter: and nothing else is reported"
rm -rf "$(dirname "$probe")"

echo
echo "== the README's worked example, machine-checked =="

# 0060 is reproduced verbatim in the README's "Your first executable migration"
# section. IMPORTANT 4: the README documented the five headings, the roles and
# the grammar but never once showed `### Step ` — grep confirmed zero
# occurrences — and never showed a complete migration, so authoring from it
# alone produced a document that linted clean and refused to run. Committing
# the example as a fixture is what keeps the README's example true.
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0060-first-migration.md" 2>&1)"
assert_eq "$?" "0" "README example: lints clean"
assert_eq "$out" "" "README example: with no diagnostics"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0060-first-migration.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "README example: runs"
assert_contains "$out" "step 1: applied" "README example: reports the step applied"
assert_eq "$(cat "$tmp/.editorconfig")" "root = true" "README example: and actually wrote the file"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0060-first-migration.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "README example: a second run exits 0"
assert_contains "$out" "step 1: skipped (already applied)" "README example: and is idempotent"
rm -rf "$tmp"; trap - EXIT

echo
echo "== usage errors are 64 everywhere, in both scripts =="

# MINORS from the final whole-branch review. Three usage errors exited 1 — the
# VIOLATION code — and two unknown-flag shapes were silently accepted as
# positionals. Each RED state is recorded beside its assertion.

# RED: `run-migration.sh` with no args printed a raw
# "line 102: DOC: usage: ..." and exited 1.
out="$(bash "$MR/run-migration.sh" 2>&1)"
assert_eq "$?" "64" "usage: run-migration.sh with no arguments is 64, not 1"
assert_contains "$out" "no migration document given" "usage: and says what is missing"
assert_not_contains "$out" "line " "usage: not a raw bash parameter-expansion message"

# RED: `--dryrun` (a typo for --dry-run) was accepted as $DOC by the `*)`
# catch-all and produced "run-migration: --dryrun: no such file" (exit 66) — a
# diagnostic that names the flag but blames the filesystem.
out="$(bash "$MR/run-migration.sh" --host codex-workflow --dryrun "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "64" "usage: an unknown runner flag is 64, not a filesystem error"
assert_contains "$out" "unknown flag '--dryrun'" "usage: and names the flag as a flag"

# RED: `--on-failure skip` (a space instead of '=') put "--on-failure" in $DOC
# and "skip" in $WORKDIR, so a caller asking for the skip policy silently got
# something else entirely.
out="$(bash "$MR/run-migration.sh" --host codex-workflow --on-failure skip "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "64" "usage: '--on-failure skip' (space, not '=') is rejected rather than silently mis-parsed"
assert_contains "$out" "unknown flag '--on-failure'" "usage: and names it"

# A third positional is an error rather than "last one wins".
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0016-conformant.md" "$tmp" extra 2>&1)"
assert_eq "$?" "64" "usage: a third positional argument is an error, not silently ignored"
assert_contains "$out" "unexpected extra argument 'extra'" "usage: and names it"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "usage: nothing ran"
rm -rf "$tmp"; trap - EXIT

# RED: the deferred bare `${2:?}` expansions in lint-migration.sh gave rc 1 and
# a raw bash message for a flag missing its value.
out="$(bash "$MR/lint-migration.sh" --threshold 2>&1)"
assert_eq "$?" "64" "usage: lint --threshold with no value is 64, not 1"
assert_contains "$out" "--threshold needs a value" "usage: and says so cleanly"
assert_not_contains "$out" "line " "usage: not a raw bash parameter-expansion message"

out="$(bash "$MR/lint-migration.sh" --host 2>&1)"
assert_eq "$?" "64" "usage: lint --host with no value is 64, not 1"
assert_contains "$out" "--host needs a value" "usage: and says so cleanly"
assert_not_contains "$out" "line " "usage: not a raw bash parameter-expansion message"

out="$(bash "$MR/lint-migration.sh" --threshold 16 2>&1)"
assert_eq "$?" "64" "usage: lint with no document is 64, not 1"
assert_contains "$out" "no migration document given" "usage: and says what is missing"

# The codes that are NOT 64 must stay where they are: 65 for a resolvable-but-
# wrong host/threshold VALUE, 66 for a missing document. Re-asserted here
# because widening 64's remit is exactly how those two get swallowed.
out="$(bash "$MR/lint-migration.sh" --host nonexistent-host "$FIX/0016-conformant.md" 2>&1)"
assert_eq "$?" "65" "usage: a bad host VALUE is still 65, not folded into 64"
out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/0099-does-not-exist.md" 2>&1)"
assert_eq "$?" "66" "usage: a missing document is still 66, not folded into 64"

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
assert_contains "$out" "migration partial:" \
  "A2: the migration-level summary line reports it as partial (not just the per-step warning)"
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
# Same shape as 0048's order check below, not the earlier grep|cut-vs-grep|cut
# comparison this replaced: two empty extractions there would have compared
# "" to "" and passed vacuously if rollback.log were ever missing. The
# arithmetic comparison fails (0, not the expected 1) in that same missing-log
# case instead, because bash arithmetic treats an unset/empty operand as 0.
line2="$(printf '%s\n' "$log" | grep -n 'rollback:2' | head -1 | cut -d: -f1)"
line1="$(printf '%s\n' "$log" | grep -n 'rollback:1' | head -1 | cut -d: -f1)"
assert_eq "$(( line2 < line1 ? 1 : 0 ))" "1" \
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
# apply/verify BLOCK_MISSING does NOT go through fail_policy's INTERACTIVE
# branch: fix round 1 of this task's review found "Nothing was rolled back"
# is the wrong discriminator for that claim, because abort_no_rollback (a
# reporting helper, called directly from the BLOCK_MISSING sites too, so the
# operator still gets an applied-steps summary on this half-applied tree)
# prints that exact phrase from BOTH call sites now. The needle that
# actually discriminates "fail_policy's prompt loop was never entered" is
# the PROMPT TEXT ITSELF ("roll [b]ack"), which only ever appears from
# inside fail_policy's own interactive branch.
tmp="$(mktemp -d)"
cp "$FIX/0046-apply-dropped-by-step1.md" "$tmp/0046-doc.md"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$tmp/0046-doc.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "apply BLOCK_MISSING: exits 1"
assert_eq "$(cat "$tmp/s1.txt" 2>/dev/null)" "s1" "apply BLOCK_MISSING: step 1 (which did the mutating) applied fine"
assert_contains "$out" "apply block missing" "apply BLOCK_MISSING: named as missing, not merely failed"
assert_not_contains "$out" "step 2: applied" "apply BLOCK_MISSING: step 2 never reported as applied"
assert_eq "$(ls "$tmp"/s2.txt 2>/dev/null; echo none)" "none" "apply BLOCK_MISSING: step 2's apply never ran"
assert_contains "$out" "Nothing was rolled back" \
  "apply BLOCK_MISSING: still gets the applied-steps report (abort_no_rollback is called directly)"
assert_not_contains "$out" "roll [b]ack" \
  "apply BLOCK_MISSING: fail_policy's own prompt was never reached (the real discriminator)"
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
assert_contains "$out" "Nothing was rolled back" \
  "verify BLOCK_MISSING: still gets the applied-steps report (abort_no_rollback is called directly)"
assert_not_contains "$out" "roll [b]ack" \
  "verify BLOCK_MISSING: fail_policy's own prompt was never reached (the real discriminator)"
rm -rf "$tmp" "$stubdir"; trap - EXIT

echo
echo "== run-migration.sh: every hard-abort path reports applied steps (fix round 2) =="

# 0051-failing-precondition-after-apply.md: step 1 genuinely applies, then
# step 2's pre-condition fails. Fix round 1 wired abort_no_rollback into only
# the apply/verify BLOCK_MISSING sites and its own comment claimed every
# hard abort already gave this report — disproved by construction in fix
# round 2's review, reached through the real CLI with no stub: this exact
# shape gave `step 1: applied` / `step 2: pre-condition failed — aborting`,
# rc=1, s1.txt on disk, and NO "applied steps" report at all.
tmp="$(mktemp -d)"
out="$(cd "$tmp" && bash "$MR/run-migration.sh" --host codex-workflow "$FIX/0051-failing-precondition-after-apply.md" "$tmp" </dev/null 2>&1)"
assert_eq "$?" "1" "hard-abort report: pre-condition failure after an earlier apply exits 1"
assert_eq "$(cat "$tmp/s1.txt" 2>/dev/null)" "s1" "hard-abort report: step 1's work survives on disk"
assert_contains "$out" "pre-condition failed" "hard-abort report: names the pre-condition failure"
assert_contains "$out" "applied steps: 1" \
  "hard-abort report: NOW names which steps applied, same as the apply/verify BLOCK_MISSING paths"
assert_contains "$out" "Nothing was rolled back" \
  "hard-abort report: NOW gives the same summary everywhere a hard abort can happen"
rm -rf "$tmp"

echo
echo "== rollback fixtures: the blocks the runner never reaches (group 7) =="

# WHY THIS SECTION EXISTS. The A2 failure policy (group 6) only ever reaches
# a step's `rollback` block when an interactive operator answers the prompt
# with "rollback" — unattended, no rollback ever runs. Every step is
# nonetheless REQUIRED to declare one (L1), which makes rollback the least-
# exercised block in every migration and the most likely to be silently
# wrong. This section drives extract.sh DIRECTLY — never run-migration.sh —
# so it reaches blocks the runner's own tests structurally cannot.
#
# FIXTURE SELECTION — surveyed, not assumed, and re-surveyed in fix round 1.
# `bash lint-migration.sh --threshold 16 <fixture>` was run against every
# file in test-fixtures/. Every "bad-*"/malformed fixture (plus 0028, 0030,
# 0035, 0038, unparseable-filename.md) fails lint and is excluded on that
# basis alone. 0004/0005 pass lint but never opt in and sit below every host
# threshold — genuinely out of scope, excluded. That leaves EXACTLY SIXTEEN
# lint-clean, in-scope fixtures: 0006, 0016, 0023, 0024, 0029, 0031, 0034,
# 0036, 0037, 0039, 0040, 0043, 0046, 0047, 0048, 0051.
#
# Fix round 1's finding: excluding a fixture WHOLESALE because "some step
# deliberately fails" was wrong — 0023/0024/0051 all fail in `precondition`/
# `check`, never in `apply`, so every one of their applies succeeds when
# driven directly (exactly what this group does) and their exclusion had no
# real basis. The fix is per-STEP, not per-fixture — but NOT because
# `mr_rollback_roundtrip` already tolerated a failing apply on its own (fix
# round 2 correction: an earlier version of this comment claimed exactly
# that, and it was false — left alone, a failing apply records `FAIL …
# apply ran and exited 0` and `continue`s, it does not "tolerate" anything).
# `mr_apply_expected_to_fail` (below) is the actual per-step mechanism: it
# names 0036 step 2 and 0047 step 2 specifically and asserts the OPPOSITE
# — that they deliberately fail — so those two steps stay meaningful
# instead of being either silently skipped or a permanent false FAIL. Most
# of the sixteen lint-clean in-scope fixtures are in ROLLBACK_FIXTURES
# below, each step's own apply (or `mr_apply_expected_to_fail`, or
# `mr_step_excluded`) deciding its fate — 0037, 0039 and 0048 are the three
# NOT in that list, exactly as the next paragraph says.
#
# Three fixtures still need a per-step (not per-fixture) carve-out, each
# VERIFIED BY RUNNING IT — not assumed:
#
# - 0037-failing-verify.md and 0048-rollback-order-and-membership.md: EVERY
#   step whose apply succeeds (0037's steps 1 and 2; 0048's steps 1 and 2)
#   was run directly and its rollback provably does NOT restore the
#   pre-apply tree — both append a line to a shared `rollback.log` that
#   persists after "rollback" (0037 step 1: apply gives tree={s1.txt},
#   rollback gives tree={rollback.log}, a real mismatch, checked by hand);
#   0048 step 1's rollback never even removes s1.txt, and 0048 step 2's
#   rollback deliberately `exit 1`s — that fixture's own stated purpose
#   ("a rollback that itself fails") requires that. That log is the exact
#   mechanism the existing "A2 interactive rollback" tests further up this
#   file use to prove rollback ORDER and membership across a whole
#   multi-step migration — these two fixtures were built for that
#   multi-step, log-based property, not for this group's single-step,
#   full-tree-parity oracle, and forcing them through it would flag their
#   own by-design behaviour as a defect. Both fixtures are left out of
#   ROLLBACK_FIXTURES entirely (every non-apply-failing step in each was
#   individually verified to mismatch — this is not the old blanket
#   "contains a failing step" excuse); 0036 and 0047 also contain a
#   deliberately-failing apply step and are NOT excluded, because their
#   OTHER steps were individually verified clean (see below).
# - 0046-apply-dropped-by-step1.md: step 2 (apply writes only s2.txt,
#   rollback removes only s2.txt) was run directly and round-trips clean —
#   included below with no special-casing. Step 1 is different: its apply
#   body itself rewrites `0046-doc.md` — a COPY of the migration document,
#   present in the workdir only so this fixture can probe extract.sh's live
#   re-read behaviour, and never declared in the fixture's own `applies_to`
#   list — while its rollback (`rm -f s1.txt`) scopes only to its own
#   declared artefact and never restores that copy. This harness deliberately
#   creates no such copy (unlike the existing BLOCK_MISSING test, which
#   does), so run exactly as this section runs it: apply rc=2 (`awk: can't
#   open file 0046-doc.md`), s1.txt written anyway (the `echo` before the
#   `awk` in the same body already ran) plus a stray empty
#   `0046-doc.md.new`. Run the OTHER way, WITH the copy present (as the
#   BLOCK_MISSING test does): apply rc=0, rollback rc=0, and the tree still
#   mismatches on 0046-doc.md's content afterward. Both were verified by
#   running them; either way step 1 cannot demonstrate a clean round trip
#   here, genuinely and by design, orthogonal to whether s1.txt itself
#   round-trips correctly (it does, in the second scenario).
#   `mr_step_excluded` below skips exactly this one step, by name, with
#   this reasoning attached; step 2
#   runs normally.
#
# Cross-checked against the WHOLE suite before finalising this list: the
# eight rollback blocks that execute nowhere else at all are 0023/1, 0024/1,
# 0046/1 (excluded above, so still never runs anywhere — a real, currently-
# unclosed gap, noted rather than hidden), 0046/2, 0047/1, 0047/3, 0051/1,
# 0051/2. 0036/2 and 0048/3 also never run anywhere, but are correctly
# excluded (their own apply fails — no post-apply state exists to roll back
# from, by spec design). 0036/1, 0037/1, 0037/2, 0048/1 and 0048/2 DO already
# run — via the existing "A2 interactive rollback" tests further up this
# file — so, while 0036/1 is exercised again below (it costs nothing and
# round-trips clean), 0037/0048's steps are not: re-proving a property a
# dedicated existing test already covers, at the cost of forcing a
# multi-step-only fixture through a single-step oracle it was never built
# for, is not worth it.
#
# CORRECTED EVIDENCE (fix round 1). An earlier version of this comment
# claimed grep showed 0006/0029/0031/0034/0040/0043 "never appear anywhere
# else except as extract.sh/--dry-run calls" — false: 0006 (line ~929),
# 0029 (line ~509) and 0043 (line ~584) all appear in FULL, non-dry-run
# `run-migration.sh` invocations elsewhere in this file. The conclusion
# survives anyway, for a more precise reason: 0006's and 0029's existing
# runs are happy-path (every step applies and — where present — verifies
# cleanly, exit 0), and 0043's hard-aborts at its pre-condition BEFORE apply
# ever runs (exit 1) — rollback is only ever invoked from `fail_policy`'s
# interactive branch (A2), and none of those three existing invocations
# reaches it. So their steps' rollback blocks genuinely have zero prior
# executions; the "only extract.sh/--dry-run" phrasing was simply wrong.
ROLLBACK_FIXTURES="0006-belowthreshold-optin-conformant.md 0016-conformant.md 0023-failing-precondition.md 0024-failing-check.md 0029-block-isolation.md 0031-heredoc-step-heading.md 0034-escape-probe.md 0036-failing-apply.md 0040-symlink-escape-probe.md 0043-precondition-127.md 0046-apply-dropped-by-step1.md 0047-skip-continues.md 0051-failing-precondition-after-apply.md 0060-first-migration.md"

# 0059-heredoc-fence-escape.md is lint-clean and in scope but is deliberately
# NOT in the list above, and the reason is checked rather than asserted: its
# steps append to a file the workdir does not start with, and its rollbacks
# (`sed` deleting from an anchor to EOF) leave an EMPTY NOTES.md behind where
# the pre-apply state had no file at all — so this sweep's snapshot equality
# would go red on a rollback that is doing exactly what it says. It gets its own
# seeded round trip instead, in the "two documented escapes" section above,
# which applies both steps and rolls both back in reverse document order
# against a NOTES.md that existed beforehand.

# 0039-zero-steps.md is lint-clean and in scope but declares no steps at
# all — confirmed directly rather than assumed, so it is excluded from the
# loop below with evidence, not a bare claim.
out="$(bash "$MR/extract.sh" steps "$FIX/0039-zero-steps.md")"
assert_eq "$out" "" \
  "0039-zero-steps.md: extract.sh confirms zero steps — nothing for this section to iterate"

# mr_snapshot $1=workdir $2=escape_target(optional) — FIX ROUND 1, IMPORTANT
# 2. `tree_snapshot` alone is blind to anything outside $1: 0034's apply
# writes to an absolute path OUTSIDE the workdir ($ESCAPE_TARGET/ran) and
# 0040's writes through a symlink `find -type f` neither reports nor
# descends (escape-link/ran). A mutation that deletes either fixture's own
# cleanup line (`rm -rf "$ESCAPE_TARGET"` / `rm -f escape-link/ran`) left
# the suite fully green under a workdir-only snapshot — proven by running
# that exact mutation (see task-7-report.md fix round 1) — because half of
# what "rollback" is supposed to undo was never in the picture the
# equality check compares. Folding the escape target's own tree into the
# same snapshot string closes that: an apply that escapes is now visible to
# the SAME check every other fixture is held to, not a second bespoke one.
mr_snapshot() {
  local et="${2:-}"
  # `[ -d "$et" ]` guards 0034's own correct rollback behaviour: it removes
  # $ESCAPE_TARGET entirely (`rm -rf`), not merely the file inside it, and
  # tree_snapshot cd-ing into a directory that no longer exists would
  # otherwise print a stderr "No such file or directory" every run. Falling
  # back to tree_snapshot "$1" alone when $et is missing is safe — but ONLY
  # because tree_snapshot itself was fixed (fix round 2) to use `find -exec
  # ... +` rather than `find -print0 | xargs -0`: under the OLD
  # implementation, "an EXISTING-but-empty escape target already snapshots
  # to the same nothing an ABSENT one does" was an unverified claim this
  # comment used to state as fact, and it was FALSE on Linux — BSD xargs
  # skips invoking `shasum` on empty input, GNU/busybox xargs run it once
  # against an empty stdin, hashing zero bytes into a real (non-empty) line
  # — so an empty existing directory and a missing one snapshotted
  # DIFFERENTLY there, and this exact fallback broke 0034's own assertion
  # on Linux (reproduced in a container; see task-7-report.md). `find -exec
  # ... +` does not invoke its utility on zero matches on any of the three
  # xargs/find variants tested, so the claim is now actually true, verified
  # on both platforms, not assumed. This does NOT weaken Important 2's own
  # fix: a rollback that leaves the escape target present with its file
  # still inside it (the mutation that check guards against) hits the `-d`
  # branch and is fully visible to the equality check either way.
  if [ -n "$et" ] && [ -d "$et" ]; then
    printf '%s\n%s' "$(tree_snapshot "$1")" "$(tree_snapshot "$et")"
  else
    tree_snapshot "$1"
  fi
}

# mr_step_excluded $1=fixture $2=step -> prints why and returns 0 (skip) for
# the one step (see the fixture-selection comment above) whose apply and
# rollback both succeed but whose rollback provably cannot restore the tree
# for a documented, executed reason unrelated to a failing apply. Every
# other exclusion in this section is already handled by the ordinary
# apply-failed `continue` path below — this function exists ONLY for that
# one different case, named individually rather than folded into a
# fixture-wide judgement.
mr_step_excluded() {
  case "$1:$2" in
    "0046-apply-dropped-by-step1.md:1")
      echo "  SKIP  $1 step $2: apply rewrites 0046-doc.md (a workdir copy of the document itself, not a declared applies_to artefact), and this harness deliberately creates no such copy — verified directly, apply actually exits rc=2 here (awk: can't open file 0046-doc.md), leaving s1.txt written plus a stray empty 0046-doc.md.new; WITH the copy present (as the existing BLOCK_MISSING test provides it), apply rc=0 but rollback (rm -f s1.txt only) still never restores that copy either way — genuinely unexercisable here either way, not a rollback this group can pass; step 2 is unaffected and runs below"
      return 0
      ;;
    *) return 1 ;;
  esac
}

# mr_apply_expected_to_fail $1=fixture $2=step -> true for the two steps in
# this selection whose OWN fixture purpose (named in its slug/title) is a
# deliberately-failing apply (0036's step 2: `exit 7`; 0047's step 2: `exit
# 9`) — included in ROLLBACK_FIXTURES because their OTHER steps are real,
# exercisable rollbacks, but these two specific steps have no post-apply
# state to roll back from by design. Asserting "apply ran and exited 0"
# unconditionally against a step whose entire documented purpose is to fail
# would register a permanent, expected FAIL on every run; asserting the
# OPPOSITE here instead — that it deliberately fails — keeps the check
# meaningful (it would go red if one of these ever started succeeding,
# which would itself be a change worth noticing) without polluting the
# total with a "failure" that is not one.
mr_apply_expected_to_fail() {
  case "$1:$2" in
    "0036-failing-apply.md:2") return 0 ;;
    "0047-skip-continues.md:2") return 0 ;;
    *) return 1 ;;
  esac
}

# mr_expected_step_count $1=fixture -> echoes the exact step count fix round
# 1 originally read off the fixture at survey time. Fix round 2 minor: a
# bare non-emptiness check on `extract.sh steps` still lets a renamed
# heading in a multi-step fixture silently drop every assertion for the
# missing step (proved: renaming 0047's own "### Step 3:" heading vanishes
# 8 assertions with nothing red anywhere in this section) — pinning the
# exact count catches that specific shape, cheaply, on top of the existing
# reliance on other tests elsewhere in this file going red for most rename
# shapes.
mr_expected_step_count() {
  case "$1" in
    0006-belowthreshold-optin-conformant.md) echo 1 ;;
    0016-conformant.md) echo 2 ;;
    0023-failing-precondition.md) echo 1 ;;
    0024-failing-check.md) echo 1 ;;
    0029-block-isolation.md) echo 1 ;;
    0031-heredoc-step-heading.md) echo 1 ;;
    0034-escape-probe.md) echo 1 ;;
    0036-failing-apply.md) echo 2 ;;
    0040-symlink-escape-probe.md) echo 1 ;;
    0043-precondition-127.md) echo 1 ;;
    0046-apply-dropped-by-step1.md) echo 2 ;;
    0047-skip-continues.md) echo 3 ;;
    0051-failing-precondition-after-apply.md) echo 2 ;;
    0060-first-migration.md) echo 1 ;;
    *) echo -1 ;; # deliberately unmatchable — a fixture reaching here was added to ROLLBACK_FIXTURES without a case here too
  esac
}

# mr_rollback_roundtrip <fixture> — cumulative, per-step round trip against
# ONE tmp workdir for the whole fixture. For step i: snapshot the tree
# BEFORE step i's apply (this is the state steps 1..i-1 left behind, or
# empty for step 1), apply step i, snapshot again and require it to DIFFER
# from the "before" snapshot — the vacuous-pass guard IMPORTANT 1 calls for:
# two empty snapshots would satisfy an equality check for the wrong reason,
# so a positive "apply actually changed something" check runs BEFORE the
# rollback is ever invoked, on the tree that rollback is about to be judged
# against. Roll back step i, snapshot a third time and require it to equal
# the "before" snapshot exactly (Scenario 1). Then re-apply step i so step
# i+1's own pre-condition-shaped assumptions about prior state hold for the
# next iteration (e.g. 0016 step 2's apply appends to a file step 1's apply
# created) — that re-apply's own exit status is checked too (fix round 1:
# it used to be discarded, the one unchecked shell-out in this function),
# even though it is setup, not itself under test.
mr_rollback_roundtrip() {
  local fixture="$1" doc tmp escape_target="" step steps_list body rc before after_apply after_rollback
  doc="$FIX/$fixture"
  tmp="$(mktemp -d)"

  case "$fixture" in
    0034-escape-probe.md)
      escape_target="$(mktemp -d)"
      export ESCAPE_TARGET="$escape_target"
      ;;
    0040-symlink-escape-probe.md)
      escape_target="$(mktemp -d)"
      ln -s "$escape_target" "$tmp/escape-link"
      ;;
  esac
  # 0046-apply-dropped-by-step1.md needs no case here: its step 1 (the only
  # one whose apply touches a workdir-resident "0046-doc.md" copy) is
  # skipped entirely by mr_step_excluded above, so nothing ever needs that
  # copy to exist — step 2's own apply/rollback pair concerns only s2.txt.

  steps_list="$(bash "$MR/extract.sh" steps "$doc")"
  local expected_count actual_count
  expected_count="$(mr_expected_step_count "$fixture")"
  actual_count="$(printf '%s' "$steps_list" | wc -w | tr -d '[:space:]')"
  assert_eq "$actual_count" "$expected_count" \
    "$fixture: extract.sh reports exactly $expected_count step(s) — the exact COUNT is pinned, not just non-emptiness, so a renamed heading that silently drops one step's worth of assertions is caught here rather than passing through unnoticed"

  for step in $steps_list; do
    if mr_step_excluded "$fixture" "$step"; then continue; fi

    before="$(mr_snapshot "$tmp" "$escape_target")"

    body="$(bash "$MR/extract.sh" block "$doc" "$step" apply 2>/dev/null)"; rc=$?
    assert_eq "$rc" "0" "$fixture step $step: apply block extracted"
    if [ "$rc" -ne 0 ]; then continue; fi
    ( cd "$tmp" && bash -c "$body" ); rc=$?
    if mr_apply_expected_to_fail "$fixture" "$step"; then
      assert_eq "$([ "$rc" -ne 0 ] && echo failed || echo succeeded)" "failed" \
        "$fixture step $step: apply deliberately fails as designed (rc=$rc) — no post-apply state exists to roll back from, so nothing further is checked for this step"
      continue
    fi
    assert_eq "$rc" "0" "$fixture step $step: apply ran and exited 0"
    if [ "$rc" -ne 0 ]; then continue; fi

    after_apply="$(mr_snapshot "$tmp" "$escape_target")"
    assert_eq "$([ "$after_apply" != "$before" ] && echo changed || echo unchanged)" "changed" \
      "$fixture step $step: apply changed the tree (guards the rollback check below against two empty snapshots matching for the wrong reason)"

    body="$(bash "$MR/extract.sh" block "$doc" "$step" rollback 2>/dev/null)"; rc=$?
    assert_eq "$rc" "0" "$fixture step $step: rollback block extracted"
    if [ "$rc" -ne 0 ]; then continue; fi
    # Belt-and-braces, confirmed redundant rather than assumed: a temp-copy
    # corruption experiment (documented in task-7-report.md) showed
    # extract.sh happily returns rc=0 with an EMPTY body for a tagged-but-
    # empty rollback fence — L8 is what actually refuses that fixture at
    # lint time, and since every fixture in ROLLBACK_FIXTURES is lint-clean
    # by construction, none of them can carry one. The same experiment
    # showed the round-trip equality check two lines below would ALSO have
    # caught an empty rollback on its own (a no-op rollback cannot restore
    # a tree that "apply changed the tree" above just proved was changed).
    # Kept anyway because it is one cheap `[ -n ... ]` and gives a more
    # specific failure message than a downstream tree mismatch would.
    assert_eq "$([ -n "$body" ] && echo nonempty || echo empty)" "nonempty" \
      "$fixture step $step: rollback body is non-empty"

    ( cd "$tmp" && bash -c "$body" ); rc=$?
    assert_eq "$rc" "0" "$fixture step $step: rollback ran and exited 0"

    after_rollback="$(mr_snapshot "$tmp" "$escape_target")"
    assert_eq "$after_rollback" "$before" \
      "$fixture step $step: rollback returned the tree to its pre-apply state"

    # Setup only, not itself under test, but its OWN exit status is now
    # checked too (fix round 1, minor 2): a silent failure here would judge
    # step i+1 against a tree this comment no longer accurately describes.
    body="$(bash "$MR/extract.sh" block "$doc" "$step" apply 2>/dev/null)"
    ( cd "$tmp" && bash -c "$body" ) >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "0" "$fixture step $step: re-apply for chaining exited 0 (setup, checked so it cannot silently leave a different tree than later steps assume)"
  done

  rm -rf "$tmp"
  if [ -n "$escape_target" ]; then rm -rf "$escape_target"; fi
  unset ESCAPE_TARGET
}

for fixture in $ROLLBACK_FIXTURES; do
  mr_rollback_roundtrip "$fixture"
done

echo
echo "== rollback fixtures: surgical rollback — rolling back step 2 alone leaves step 1 intact =="

# Dedicated, hand-legible version of Scenario 2 (spec.md), independent of
# the generic sweep above: apply both of 0016's steps, roll back ONLY step
# 2, and check step 1's own content directly rather than only a tree hash.
tmp="$(mktemp -d)"
doc="$FIX/0016-conformant.md"

body="$(bash "$MR/extract.sh" block "$doc" 1 apply)"; rc=$?
assert_eq "$rc" "0" "surgical: step 1 apply extracted"
( cd "$tmp" && bash -c "$body" )
assert_eq "$?" "0" "surgical: step 1 applied"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "applied" "surgical: step 1's content is on disk"

body="$(bash "$MR/extract.sh" block "$doc" 2 apply)"; rc=$?
assert_eq "$rc" "0" "surgical: step 2 apply extracted"
( cd "$tmp" && bash -c "$body" )
assert_eq "$?" "0" "surgical: step 2 applied"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "$(printf 'applied\nsecond')" \
  "surgical: both steps' content present before either rollback runs"

body="$(bash "$MR/extract.sh" block "$doc" 2 rollback)"; rc=$?
assert_eq "$rc" "0" "surgical: step 2 rollback extracted"
( cd "$tmp" && bash -c "$body" )
assert_eq "$?" "0" "surgical: step 2 rolled back"

assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "applied" \
  "surgical: step 1's work SURVIVES, and step 2's own contribution is gone — an EXACT match to just 'applied' proves both at once (fix round 1: a separate assert_not_contains 'second' here was dropped as vacuous, since it was already implied by this equality and would have passed even against a missing file)"

rm -rf "$tmp"

echo
echo "TOTAL: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
