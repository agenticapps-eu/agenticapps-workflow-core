#!/usr/bin/env bash
# migration-runner-version: 0.1.0
# run-migration.sh — apply an executable migration.
#
# Per step, in order:
#   check        exit 0 => already applied; skip the step
#                exit 1 => not applied; proceed
#                anything else => the check itself could not run; ABORT.
#                Conflating "not applied" with "could not tell" would silently
#                re-apply a step whose state is unknown.
#   precondition non-zero => hard-abort, always, terminal or not. The block's
#                OWN stderr is reproduced verbatim here — never paraphrased —
#                because a precondition is where a migration explains what it
#                found and what the operator may do about it.
#   apply        non-zero => failure policy
#   verify       optional; non-zero => failure policy
#
# DRY-RUN evaluates check and precondition up to and INCLUDING the first
# pending step (the three-valued check contract is unchanged — it is never
# relaxed in dry-run), prints that step's apply source, then stops evaluating
# anything: every step after the first pending one has its apply source
# printed UNEVALUATED, with neither its check nor its precondition run. This
# is deliberate: a later step's check may depend on state only an earlier
# step's real apply would create, and dry-run never applies anything — not to
# the working tree, and not to a copy of it. There is no scratch mirror here;
# an earlier version tried one and a review found it could still write
# outside the workdir (an apply doing `mkdir -p "$HOME/..."`, `git push` with
# `.git` copied along, `cp -R` preserving a symlink back into the real tree)
# — a "no writes" guarantee that held only for the fixtures it was tested
# against. Never evaluating a later step's blocks at all closes that
# permanently, at the cost of not previewing anything past the first pending
# step.
#
# SCOPE OF THIS FILE (tasks 4-5 of the executable-migration-format plan):
# the dispatch loop, dry-run, exit-code semantics, and refusing to run a
# migration that would do nothing.
#   - Lint-before-execute (refusing to run a migration that fails
#     lint-migration.sh, that yields zero steps, or where any step yields no
#     apply block) is task 5's job — see "LINT BEFORE EXECUTING ANYTHING"
#     below. --host is REQUIRED for exactly this reason: see the check
#     immediately after argument parsing.
#   - The interactive failure policy (retry / skip-with-warning / roll back,
#     and the non-interactive "abort in place, report what applied, roll back
#     nothing" behaviour) is task 6's job. fail_policy() below is a STUB: it
#     reports the failure and returns non-zero (abort) unconditionally, no
#     matter what --on-failure says. Task 6 fills in the real policy.
#
# Usage: run-migration.sh --host NAME [--dry-run] [--on-failure=abort|prompt|skip] <doc> [<workdir>]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT="$SCRIPT_DIR/extract.sh"

DRY_RUN=0
ON_FAILURE=""
HOST=""
DOC=""
WORKDIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --on-failure=*) ON_FAILURE="${1#*=}"; shift ;;
    --host)
      if [ $# -lt 2 ]; then
        echo "run-migration: --host needs a value" >&2
        exit 64
      fi
      HOST="$2"; shift 2
      ;;
    *) if [ -z "$DOC" ]; then DOC="$1"; else WORKDIR="$1"; fi; shift ;;
  esac
done
: "${DOC:?usage: run-migration.sh --host NAME [--dry-run] [--on-failure=P] <doc> [<workdir>]}"

# --host IS REQUIRED. THERE IS DELIBERATELY NO DEFAULT AND NO "NO THRESHOLD"
# PATH.
#
# An optional threshold looks harmless and reopens the silent-no-op hole one
# layer down: with no threshold, nothing is in scope for the linter, so the
# lint passes trivially, so this runner — which now lints before executing —
# executes anything at all. That is the exact defect this group exists to
# close, wearing the lint step as a disguise. A missing --host is therefore a
# usage error, checked alongside the other required arguments, before this
# script ever looks at the filesystem.
if [ -z "$HOST" ]; then
  echo "run-migration: --host is required (no default; see THRESHOLDS) — omitting it would leave every migration out of scope, every lint trivially clean, and this runner willing to execute anything" >&2
  exit 64
fi

WORKDIR="${WORKDIR:-.}"

# A nonexistent or unreadable document must be a hard error, not a silent
# zero-step, zero-anything success — `steps="$(extract.sh steps "$DOC")"`
# below would otherwise just capture awk's own error text on stderr while
# `steps` comes back empty, the for-loop runs zero times, and the script
# exits 0 having done nothing. That is the exact silent-success failure this
# format exists to prevent. Mirrors lint-migration.sh's own exit 66.
[ -f "$DOC" ] || { echo "run-migration: $DOC: no such file" >&2; exit 66; }
[ -r "$DOC" ] || { echo "run-migration: $DOC: cannot read file" >&2; exit 66; }

case "$ON_FAILURE" in
  ""|abort|prompt|skip) ;;
  *)
    echo "run-migration: --on-failure must be abort, prompt or skip (got '$ON_FAILURE')" >&2
    exit 64
    ;;
esac

if [ -z "$ON_FAILURE" ]; then
  if [ -t 0 ]; then ON_FAILURE="prompt"; else ON_FAILURE="abort"; fi
fi

applied=""

# run_block $1=step $2=role
#
# Each block gets its OWN shell (a `bash -c` subshell), cd'd into WORKDIR. No
# step may inherit env vars, functions, or a working directory left behind by
# an earlier block or an earlier step — that dependency would be invisible in
# the document and would break the moment a step is skipped as already
# applied.
#
# BLOCK_MISSING is an OUT-OF-BAND signal, not a sentinel exit code. Fix
# round 3 found that a sentinel of 127 collides with a REAL exit code: `bash
# -c "$body"` also returns 127 when the block's own command is not found
# (e.g. a pre-condition that shells out to `jq`/`gh`/`rg`/`openspec` on a
# machine where it is not installed). A fully lint-clean, in-scope,
# well-formed migration whose pre-condition happens to invoke a missing
# tool would then be misreported as "block missing" — the exact
# looks-correct-does-nothing-shaped misreport this format exists to guard
# against, in the mirror direction: not a phantom success, but a false "the
# document is malformed" pointed at a document that is not. Callers that
# need to tell "extract.sh found nothing" apart from "the block ran and
# exited 127 on its own" check $BLOCK_MISSING immediately after calling
# run_block, before any other run_block call overwrites it.
run_block() {
  local body
  BLOCK_MISSING=0
  if ! body="$(bash "$EXTRACT" block "$DOC" "$1" "$2" 2>/dev/null)"; then
    BLOCK_MISSING=1
    return 1
  fi
  ( cd "$WORKDIR" && bash -c "$body" )
}

# fail_policy $1=failing step — returns 0 to continue, 1 to abort.
#
# STUB for task 4. The real interactive/non-interactive policy (retry, skip
# with warning, or roll back in reverse document order) is task 6's job. Until
# then every failure aborts: this reports which steps applied, on stderr, and
# always returns 1. Nothing is rolled back here, which matches the spec's
# unattended behaviour exactly — this stub simply never takes the interactive
# branch yet.
fail_policy() {
  echo "applied steps:${applied:- none}" >&2
  echo "step $1 left in place. Nothing was rolled back — inspect before re-running." >&2
  return 1
}

# EXIT-CODE SCHEME (fix round 1, per spec's "Refusal is distinguishable from
# failure by exit code"):
#   64 = usage error — a problem with how THIS SCRIPT was invoked (missing
#        --host, unresolvable --host/threshold, bad --on-failure). Already
#        used above for the other usage checks.
#   65 = REFUSAL — a pre-execution refusal because the DOCUMENT does not
#        qualify to run: out of scope, a lint violation, zero steps, or a
#        step with no apply block. Nothing has executed yet in every one of
#        these cases; the tree is guaranteed untouched.
#   66 = missing/unreadable document (already used above).
#   1  = a failure once execution has begun (a step's check/precondition/
#        apply/verify), where earlier steps may already have applied.
# A CI caller can therefore always tell "refused, tree untouched" (65, or 64/
# 66 for a usage/environment problem) from "ran partway, tree may have
# changed" (1) without parsing stderr.
REFUSAL=65

# A RUNNER EXECUTES ONLY MIGRATIONS THE LINTER JUDGED.
#
# The linter's silence on a below-threshold, non-opted-in document means NOT
# EXAMINED, not EXAMINED AND FOUND WELL-FORMED — lint-migration.sh exits 0 in
# both cases, and a runner that treats "exit 0" as "approved" cannot tell
# them apart. Renaming a migration to a low-numbered filename would then
# evaporate the format gate at run time: the very same "no threshold, nothing
# in scope, everything passes" hole --host closes globally, reopened per
# document. --scope-only asks lint-migration.sh the scope question alone,
# using its own scope computation (never a second copy of the ID/threshold
# rule here), before any structural rule or block ever runs. An opted-in
# below-threshold migration is still in scope and still runs normally.
#
# THESE TWO GATES ALWAYS RUN. NOTHING IN THIS SCRIPT BYPASSES THEM.
#
# Fix round 2 added an environment-variable escape hatch
# (_RUN_MIGRATION_TEST_ONLY_SKIP_LINT) so the test suite could reach
# dispatch-loop code paths that these gates make hard to reach through this
# CLI. Fix round 3 removed it: it was read from the process environment, so
# anything upstream of an invocation could set it — a CI `env:` block, a
# wrapper script, `.envrc`, `docker run -e`, an agent's own tool
# configuration — and it is inherited transitively, so a migration whose own
# apply block shells out to a nested run-migration.sh invocation would carry
# the bypass into it. A bypassed run is byte-identical to a real one: no
# output difference, no log line, nothing to grep for, because nobody was
# ever told it existed. The test suite now reaches the same dispatch-loop
# code via a stub-collaborator test double instead (a temp dir of symlinks
# to the real run-migration.sh/extract.sh plus a stub lint-migration.sh that
# exits 0) — see tools/migration-runner.test.sh. That keeps zero bypass
# surface in this file.
bash "$SCRIPT_DIR/lint-migration.sh" --scope-only --host "$HOST" "$DOC" >/dev/null
scope_rc=$?
case "$scope_rc" in
  0) : ;; # in scope — the linter will actually examine this document
  1)
    echo "refusing to run: $DOC is out of scope for $HOST (below threshold, not opted in) — the linter never examined it, which is not the same as approving it" >&2
    exit "$REFUSAL"
    ;;
  65)
    # A bad/unresolvable --host or --threshold is a problem with this
    # invocation, not with the document — same class as the other usage
    # errors above, so it gets the same code lint-migration.sh itself
    # documents as "usage" for a caller of THIS script (64), not the
    # document-refusal code (65) despite lint's own internal 65 meaning
    # something different ("bad threshold/host") in its own contract.
    exit 64
    ;;
  66)
    echo "run-migration: $DOC: no such file" >&2
    exit 66
    ;;
  *)
    echo "run-migration: lint-migration.sh --scope-only exited unexpectedly ($scope_rc)" >&2
    exit "$REFUSAL"
    ;;
esac

# LINT BEFORE EXECUTING ANYTHING.
#
# Rejecting a bad migration at lint time is not enough on its own, because
# nothing obliges the operator to have linted. A runner that executes
# whatever it is given can be handed an all-illustration document — every
# fence un-annotated — and report success having changed nothing. That is
# the exact silent-no-op failure this whole format exists to prevent, and it
# is worst when the step it silently skipped was the security-relevant one.
bash "$SCRIPT_DIR/lint-migration.sh" --host "$HOST" "$DOC"
lint_rc=$?
case "$lint_rc" in
  0) : ;;
  1)
    echo "refusing to run: $DOC does not satisfy the executable format" >&2
    exit "$REFUSAL"
    ;;
  65) exit 64 ;; # bad/unresolvable host or threshold — a usage problem, see above
  66)
    echo "run-migration: $DOC: no such file" >&2
    exit 66
    ;;
  *)
    echo "run-migration: lint-migration.sh exited unexpectedly ($lint_rc)" >&2
    exit "$REFUSAL"
    ;;
esac

steps="$(bash "$EXTRACT" steps "$DOC")"

# ABORT ON ZERO STEPS.
#
# An in-scope migration that declares no `### Step ` heading at all lints
# clean — every per-step rule iterates zero times over an empty step list —
# and would otherwise run to completion having dispatched nothing. The
# linter cannot catch this; only the runner can, because only the runner
# knows what "ran to completion" is about to mean.
if [ -z "$steps" ]; then
  echo "refusing to run: $DOC declares no steps" >&2
  exit "$REFUSAL"
fi

# ABORT IF ANY STEP YIELDS NO APPLY BLOCK.
#
# L1 only checks that a role=apply fence is PRESENT, not what is inside it.
# A fence that opens and closes with nothing between its delimiters passes
# L1 and every other structural rule, but running it would apply literally
# nothing (`bash -c ''` exits 0, untouched). Checking for an EMPTY captured
# body — not just extract.sh's exit code — is what catches both an ABSENT
# apply block (extract.sh exits 1, body empty) and a TAGGED-BUT-EMPTY one
# (extract.sh exits 0, body still empty): both are the same silent-no-op
# outcome from the operator's point of view, so both refuse to run.
for s in $steps; do
  apply_body="$(bash "$EXTRACT" block "$DOC" "$s" apply)"
  apply_rc=$?
  if [ "$apply_rc" -ne 0 ] || [ -z "$apply_body" ]; then
    echo "refusing to run: $DOC step $s has no apply block" >&2
    exit "$REFUSAL"
  fi
done

# pending_seen / pending_step: DRY-RUN ONLY bookkeeping. Once a pending step
# is found, every later step's blocks — check and precondition included — go
# entirely unevaluated; only its apply source is printed, clearly labelled
# as such. A real run never sets this: pending_seen stays 0 for the whole
# real-run loop, so the "already past the first pending step" branch below
# is dead code on that path.
pending_seen=0
pending_step=""

for s in $steps; do
  if [ "$DRY_RUN" -eq 1 ] && [ "$pending_seen" -eq 1 ]; then
    echo "step $s: would apply (not evaluated — follows pending step $pending_step):"
    # Check the exit status and emptiness explicitly BEFORE printing — piping
    # straight into sed would silently swallow extract.sh's own exit code,
    # since sed still exits 0 having formatted zero lines of input. The
    # pre-flight scan above already guarantees every step has a non-empty
    # apply block before this loop ever runs, so this is defense in depth,
    # not the primary guard — hence the reserved refusal code, unreachable in
    # practice but consistent with the pre-flight scan's own refusal above.
    # The presence check captures via "$(...)" (which strips trailing
    # newlines) purely to test emptiness/exit code; the actual print re-runs
    # extract.sh and pipes it directly, so a body with meaningful trailing
    # blank lines prints byte-for-byte as extract.sh produced it, not
    # re-normalized through a second round of newline stripping.
    apply_src="$(bash "$EXTRACT" block "$DOC" "$s" apply)"
    apply_rc=$?
    if [ "$apply_rc" -ne 0 ] || [ -z "$apply_src" ]; then
      echo "step $s: has no apply block — aborting" >&2
      exit "$REFUSAL"
    fi
    bash "$EXTRACT" block "$DOC" "$s" apply | sed 's/^/    /'
    continue
  fi

  # THREE-VALUED CHECK: 0 = applied, 1 = not applied, anything else = the
  # check itself could not run. Conflating the last two would silently
  # re-apply a step whose state is unknown, so this hard-aborts on anything
  # other than 0 or 1 — UNCHANGED in dry-run. A dry run never relaxes this;
  # it simply stops evaluating anything once it hits the first step that
  # returns 1, rather than tolerating a check that returns something else.
  run_block "$s" check >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "step $s: skipped (already applied)"
    continue
  elif [ "$rc" -ne 1 ]; then
    echo "step $s: idempotency check could not run (exit $rc) — aborting" >&2
    exit 1
  fi

  # A failed pre-condition ALWAYS hard-aborts, terminal or not, and its own
  # stderr — not a paraphrase of it — is what the operator sees. The
  # interactive failure policy governs apply and verify only; a precondition
  # failure means the migration's assumptions about the tree do not hold, and
  # neither retrying nor skipping can change that. This is unconditional in
  # both real and dry runs, including for the first pending step in a dry
  # run: dry-run evaluates check and precondition up to and including that
  # step, no further.
  run_block "$s" precondition
  rc=$?
  if [ "$rc" -ne 0 ]; then
    # BLOCK_MISSING, not "rc -eq 127": the block's OWN body can legitimately
    # exit 127 (its command wasn't found — jq, gh, rg, openspec are the
    # common ones), and that is a REAL pre-condition failure, not a missing
    # block. Only BLOCK_MISSING (extract.sh itself found nothing) means the
    # block is actually absent. See run_block's header comment.
    if [ "$BLOCK_MISSING" -eq 1 ]; then
      echo "step $s: pre-condition block missing — aborting" >&2
    else
      echo "step $s: pre-condition failed — aborting" >&2
    fi
    exit 1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "step $s: would apply:"
    # Same fix as the other dry-run print site above: check the exit status
    # and emptiness explicitly before printing, rather than piping straight
    # into sed (which would mask extract.sh having found nothing), and print
    # via a fresh direct pipe so trailing blank lines in the body survive
    # byte-for-byte rather than being stripped by command substitution.
    apply_src="$(bash "$EXTRACT" block "$DOC" "$s" apply)"
    apply_rc=$?
    if [ "$apply_rc" -ne 0 ] || [ -z "$apply_src" ]; then
      echo "step $s: has no apply block — aborting" >&2
      exit "$REFUSAL"
    fi
    bash "$EXTRACT" block "$DOC" "$s" apply | sed 's/^/    /'
    # This step is now the first pending one. Nothing past this point is
    # ever executed or evaluated — not against WORKDIR, and not against any
    # copy of it — so every later step's blocks are skipped outright above.
    pending_seen=1
    pending_step="$s"
    continue
  fi

  if ! run_block "$s" apply; then
    echo "step $s: apply failed" >&2
    fail_policy "$s" || exit 1
    continue
  fi

  if bash "$EXTRACT" roles "$DOC" "$s" | grep -qx verify; then
    if ! run_block "$s" verify; then
      # NOT recorded as applied — apply ran, but the result is not what the
      # migration said it should be, so the step did not succeed.
      echo "step $s: verify failed" >&2
      fail_policy "$s" || exit 1
      continue
    fi
  fi

  applied="$applied $s"
  echo "step $s: applied"
done

exit 0
