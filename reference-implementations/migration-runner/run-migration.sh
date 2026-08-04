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
# applied. A missing block (extract.sh exits 1) is reported as exit 127 so it
# is never confused with a real block's own exit code of 1.
run_block() {
  local body
  body="$(bash "$EXTRACT" block "$DOC" "$1" "$2" 2>/dev/null)" || return 127
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

steps="$(bash "$EXTRACT" steps "$DOC")"

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
    if [ "$rc" -eq 127 ]; then
      echo "step $s: pre-condition block missing — aborting" >&2
    else
      echo "step $s: pre-condition failed — aborting" >&2
    fi
    exit 1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "step $s: would apply:"
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
