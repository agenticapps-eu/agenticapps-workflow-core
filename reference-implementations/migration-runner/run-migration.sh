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
# SCOPE OF THIS FILE (task 4 of the executable-migration-format plan):
# the dispatch loop, dry-run, and exit-code semantics only.
#   - Lint-before-execute (refusing to run a migration that fails
#     lint-migration.sh, or that yields zero steps / a step with no apply
#     block) is task 5's job. This runner does not call lint-migration.sh.
#   - The interactive failure policy (retry / skip-with-warning / roll back,
#     and the non-interactive "abort in place, report what applied, roll back
#     nothing" behaviour) is task 6's job. fail_policy() below is a STUB: it
#     reports the failure and returns non-zero (abort) unconditionally, no
#     matter what --on-failure says. Task 6 fills in the real policy.
#
# Usage: run-migration.sh [--dry-run] [--on-failure=abort|prompt|skip] <doc> [<workdir>]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT="$SCRIPT_DIR/extract.sh"

DRY_RUN=0
ON_FAILURE=""
DOC=""
WORKDIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --on-failure=*) ON_FAILURE="${1#*=}"; shift ;;
    *) if [ -z "$DOC" ]; then DOC="$1"; else WORKDIR="$1"; fi; shift ;;
  esac
done
: "${DOC:?usage: run-migration.sh [--dry-run] [--on-failure=P] <doc> [<workdir>]}"
WORKDIR="${WORKDIR:-.}"

if [ -z "$ON_FAILURE" ]; then
  if [ -t 0 ]; then ON_FAILURE="prompt"; else ON_FAILURE="abort"; fi
fi

applied=""
SCRATCH=""
cleanup() { [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"; }
trap cleanup EXIT

if [ "$DRY_RUN" -eq 1 ]; then
  # Dry-run SHALL NOT write to the real working tree — but a later step's
  # check or precondition may legitimately depend on state an EARLIER step's
  # apply would have created (0016-conformant.md's step 2 check greps a file
  # step 1's apply writes). A dry run never runs any real apply against
  # WORKDIR, so without help that prerequisite genuinely would not exist yet
  # by the time step 2 is evaluated — not because the step's state is
  # unknown, but because dry-run itself never let step 1 create it. To let
  # later steps evaluate meaningfully, dry-run mirrors WORKDIR into a
  # throwaway scratch copy and runs every block — including each pending
  # step's apply — there instead. WORKDIR itself is never touched, and the
  # copy is discarded when the run ends.
  SCRATCH="$(mktemp -d)"
  if [ -d "$WORKDIR" ]; then
    cp -R "$WORKDIR"/. "$SCRATCH"/ 2>/dev/null || true
  fi
fi

# run_block $1=step $2=role
#
# Each block gets its OWN shell (a `bash -c` subshell), cd'd into the target
# directory. No step may inherit env vars, functions, or a working directory
# left behind by an earlier block or an earlier step — that dependency would
# be invisible in the document and would break the moment a step is skipped
# as already applied. A missing block (extract.sh exits 1) is reported as
# exit 127 so it is never confused with a real block's own exit code of 1.
# In dry-run mode the target directory is the scratch copy, never WORKDIR.
run_block() {
  local body dir
  dir="$WORKDIR"
  [ "$DRY_RUN" -eq 1 ] && dir="$SCRATCH"
  body="$(bash "$EXTRACT" block "$DOC" "$1" "$2" 2>/dev/null)" || return 127
  ( cd "$dir" && bash -c "$body" )
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

steps="$(bash "$EXTRACT" steps "$DOC")"

for s in $steps; do
  # THREE-VALUED CHECK: 0 = applied, 1 = not applied, anything else = the
  # check itself could not run. Conflating the last two would silently
  # re-apply a step whose state is unknown, so a REAL run hard-aborts on
  # anything other than 0 or 1.
  #
  # A dry run is the one place this is deliberately relaxed: the spec's
  # dry-run requirement calls out only a failing precondition as aborting
  # "exactly as it would during a real run" — it says nothing of the sort
  # about an ambiguous check. That omission matters here, because a later
  # step's check can legitimately depend on state an EARLIER step's apply
  # would have created (0016-conformant.md's step 2 check greps a file that
  # step 1's apply creates). A dry run never runs any apply, so by the time a
  # later step's check runs, that prerequisite genuinely does not exist yet —
  # not because the step is in an unknown state, but because dry-run mode
  # itself never lets an earlier step create it. Since dry-run never applies
  # anything either way, there is no "silently re-applies unknown state" risk
  # to guard against: rc==0 still means "already applied, skip"; any other
  # exit just means "not (yet) applied", so the step is pending and its apply
  # source is printed.
  run_block "$s" check >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "step $s: skipped (already applied)"
    continue
  elif [ "$rc" -ne 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "step $s: idempotency check could not run (exit $rc) — aborting" >&2
    exit 1
  fi

  # A failed pre-condition ALWAYS hard-aborts, terminal or not, and its own
  # stderr — not a paraphrase of it — is what the operator sees. The
  # interactive failure policy governs apply and verify only; a precondition
  # failure means the migration's assumptions about the tree do not hold, and
  # neither retrying nor skipping can change that. This is unconditional in
  # both real and dry runs.
  if ! run_block "$s" precondition; then
    echo "step $s: pre-condition failed — aborting" >&2
    exit 1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "step $s: would apply:"
    bash "$EXTRACT" block "$DOC" "$s" apply | sed 's/^/    /'
    # Advance the scratch copy so a later step's check/precondition see this
    # step's effect, exactly as they would after a real apply. This never
    # touches WORKDIR, and its outcome is not itself reported — only the
    # source above is dry-run's contract; this is bookkeeping to keep the
    # scratch copy representative.
    run_block "$s" apply >/dev/null 2>&1
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
