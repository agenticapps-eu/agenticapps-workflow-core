#!/usr/bin/env bash
# migration-runner-version: 0.1.0
# lint-migration.sh — enforce the executable migration format.
#
# L1  every step has check/precondition/apply/rollback each PRESENT at
#     least once (verify is optional, so absent is fine). PRESENCE only —
#     a duplicate of any role, including a second verify, is L3's job, not
#     L1's; see the "L1's job is presence only" note further down.
# L2  each role= fence sits under its matching **Label:** heading
# L3  no duplicate roles within a step
# L4  unknown role values are rejected
# L5  role= appears only on bash fences, and only in the exact grammar
#     ^bash[ \t]+role=[a-z]+$
# L6  steps are numbered consecutively from 1 (a gap is a violation, even
#     though the extractor deliberately tolerates it structurally — see
#     mr_steps's "bound by the next heading, not N+1" comment)
# L7  every fence a migration opens must be closed before end of file
# L8  a tagged fence's body must contain at least one executable statement,
#     for ANY role (check, precondition, apply, verify, rollback) — see the
#     header comment just above the L8 scan for why this is a linter rule and
#     not a runner one
# L9  a tagged fence must not be TERMINATED by a line that is itself a fence
#     OPENER (a "```" line carrying a non-empty info string). Under this
#     format's fence state machine such a line closes the tagged fence, so the
#     captured body stops there — see the L9 scan's own header for the
#     executed proof
# L10 a tagged fence's body must not leave a heredoc unterminated — the
#     semantic half of the same truncation class L9 catches structurally
#
# Every rule above is implemented in this script. Whole-document problems
# (filename ID, threshold, frontmatter cross-checks, zero steps, a missing
# `applies_to`) are deliberately NOT numbered — they are properties of the
# document rather than of a step or a fence. L0 is the one exception, and it
# is numbered for historical reasons only; see the README's own note.
#
# WHY L7 EXISTS. extract.sh's mr_roles prints a role from the fence's
# OPENING line; mr_block only sets found=1 on the fence's CLOSING line (see
# extract.sh's header and its END block). An unclosed fence at EOF is
# therefore PRESENT to mr_roles — and so to L1, which is built on mr_roles —
# but ABSENT to mr_block, which is what run_block actually calls. Without
# L7, such a document lints clean and fails at runtime with "block missing"
# for a role the linter just confirmed was there: the exact
# looks-correct-does-nothing class this whole format exists to prevent, and
# a linter gap rather than a runner one, since it is the linter's own role
# listing that has the blind spot. Found by construction in fix round 2's
# review: an in-scope, otherwise-conformant document whose `**Pre-condition:**`
# fence is the last thing in the file and is never closed lints clean and
# aborts with "pre-condition block missing" at run time.
#
# L1's job is presence only: "verify appears at most once" and "no role
# appears more than once" are both L3's problem, so a required role that
# shows up twice is NOT also reported as missing by L1 — grep -qx a role
# name matches on any of its occurrences.
#
# L5 checks EVERY fence whose info string contains the substring "role=",
# not just fences that are already known to be tagged apply/check/etc. A
# fence opened as ```bash role=apply retry=2``` is syntactically a bash
# fence but still fails L5: the exact grammar is anchored at both ends
# (^...$), so a trailing extra key is a grammar violation exactly like a
# non-bash fence type is. Silently accepting "close enough" info strings is
# how a typo'd or embellished role= fence stops being annotated without
# anyone noticing — L4's docstring above makes the same point about typo'd
# role names; this is the same failure mode for the fence's info string as
# a whole.
#
# FENCE STATE FIRST, ALWAYS. The L2/L4 scan below (and the L5 scan further
# down) check `infence` BEFORE any step-boundary or heading logic, exactly
# like extract.sh's mr_roles/mr_block/mr_steps. This is the THIRD time this
# exact ordering mistake has had to be fixed in this plan (mr_roles/mr_block,
# then mr_steps, then this file's first draft of the L2/L4 pass, which
# checked "### Step " boundaries before checking whether a line was inside a
# fence). Getting it backwards means a heredoc body containing the literal
# text "### Step 2" turns a step "off" mid-fence, silently suppressing every
# L2/L4 check for the rest of that step — including a role=aply fence that
# would otherwise be caught. Confirmed by reproduction against
# 0031-heredoc-step-heading.md; see the Task 3 fix-round report for the
# RED/GREEN transcript.
#
# THE ID THRESHOLD.
#
# A migration's ID comes from its FILENAME BASENAME, never from frontmatter.
# The threshold mechanism exists so migrations written before this format did
# are never judged — but it was chosen over a frontmatter declaration
# precisely because a filename cannot be forgotten. Reading `id:` from
# frontmatter instead throws that away: delete one line and the file evades
# the linter entirely. That was a real defect found in this plan's Stage 2
# review; 0026-bad-no-frontmatter-id.md and 0027-bad-id-mismatch.md are its
# regression guards, and 0030-scope-by-filename.md guards specifically
# against "simplifying" scope back to reading frontmatter (its frontmatter id
# would put it below every threshold; only its filename puts it in scope).
# Do not "simplify" this back to reading frontmatter.
#
# A filename with no parseable leading `<digits>-` is a VIOLATION, never a
# skip — an unreadable ID must not be a quiet route out of scope.
#
# `--host NAME` resolves the threshold from THRESHOLDS (core's per-host
# declaration file). `--threshold N` sets it directly. There is deliberately
# NO path for "neither given": that would mean every migration is out of
# scope, every lint trivially clean, and — because the runner lints before
# executing — every migration runnable. An unknown host, a non-numeric
# threshold (from either source), and the absence of both flags, are all
# errors, not defaults.
#
# Below the threshold and not opted in, a migration predates the format and
# is skipped entirely (exit 0) rather than judged: retrofit scope is zero. A
# migration MAY opt in early by declaring `migration_format: executable`;
# that can only ADD it to scope, never remove one that's already in it.
#
# Usage: lint-migration.sh [--scope-only] (--threshold N | --host NAME) <doc>
# Exit 0 = clean. Exit 1 = one violation line per problem, on stderr, in
# `L<n>: step <s>: <message>` form for per-step rules; whole-document
# problems (filename ID, threshold, frontmatter cross-checks) are reported
# without a step number.
#
# --scope-only answers ONE question — "would the full lint above even
# examine this document, or would it skip it as frozen pre-format history?"
# — without running any structural rule. Exit 0 = in scope (the document
# will be examined: either it's at/above threshold, it opted in, or its
# filename ID couldn't even be parsed, which is never a skip — see below).
# Exit 1 = truly out of scope: below threshold and no migration_format
# declared at all. This exists so a CALLER (run-migration.sh) can tell "the
# linter examined this and found it clean" apart from "the linter never
# looked at this," which a bare exit-0-from-full-lint cannot distinguish —
# both look identical from outside. Deliberately the SAME scope computation
# as the full lint below, just short-circuited before any L-rule runs, so
# there is exactly one implementation of the scope rule to drift.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# USAGE ERRORS ARE ALWAYS 64, WITHOUT EXCEPTION.
#
# Every "you invoked this wrong" outcome exits 64: an unknown flag, a flag
# missing its value, a second positional document, no document at all, and
# neither --threshold nor --host. Before fix round 4 three of those exited 1 —
# the VIOLATION code — via bare `${VAR:?message}` expansions, so a CI job that
# forgot `--host` (or typed `--threshold` with nothing after it) got a raw bash
# diagnostic and the same exit status a real format violation produces. A
# caller cannot then tell "this document is malformed" from "I called the
# linter wrong", which is precisely the distinction the runner's own exit-code
# scheme (run-migration.sh's header) exists to preserve one layer up. 65 stays
# reserved for a resolvable-but-wrong host/threshold VALUE, and 66 for a
# missing document.
USAGE=64
usage_error() { echo "lint: $*" >&2; echo "usage: lint-migration.sh [--scope-only] (--threshold N | --host NAME) <doc>" >&2; exit "$USAGE"; }

THRESHOLD=""
DOC=""
SCOPE_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --scope-only) SCOPE_ONLY=1; shift ;;
    --threshold)
      [ $# -ge 2 ] || usage_error "--threshold needs a value"
      THRESHOLD="$2"; shift 2
      ;;
    --host)
      # Resolve from the declared file rather than making every caller
      # remember a number. THRESHOLDS is core's declaration, one row per host.
      [ $# -ge 2 ] || usage_error "--host needs a value"
      _h="$2"; shift 2
      THRESHOLD="$(sed 's/#.*//' "$SCRIPT_DIR/THRESHOLDS" | awk -v h="$_h" '$1 == h { print $2; exit }')"
      [ -n "$THRESHOLD" ] || { echo "lint: no threshold declared for host '$_h'" >&2; exit 65; }
      ;;
    --*)
      usage_error "unknown flag '$1'"
      ;;
    *)
      if [ -n "$DOC" ]; then
        usage_error "unexpected extra argument '$1' (doc already set to '$DOC')"
      fi
      DOC="$1"; shift
      ;;
  esac
done
[ -n "$DOC" ] || usage_error "no migration document given"

# NO "NO THRESHOLD GIVEN" PATH. Omitting both flags is an error, not an
# empty scope — see the header comment above. A caller who forgot --host
# must not silently get "nothing in scope, everything passes."
[ -n "$THRESHOLD" ] || usage_error "--threshold or --host is required (no default; see THRESHOLDS) — with neither, every migration would be out of scope and every lint would pass trivially"

# Validate once, after both possible sources (a literal --threshold, or a row
# resolved from THRESHOLDS via --host) have landed in the same variable. A
# non-numeric value here — a typo'd CLI arg, or a typo'd THRESHOLDS row like
# "O016" with a letter O — must not silently make every comparison against it
# fail closed-as-open: bash arithmetic on a non-numeric string errors out,
# `above` would stay 0, and every migration that doesn't separately declare
# `executable` would exit 0 clean. That reopens the no-silent-threshold hole
# one layer down, just moved from "no threshold" to "bad threshold".
case "$THRESHOLD" in
  ''|*[!0-9]*) echo "lint: threshold '$THRESHOLD' is not numeric" >&2; exit 65 ;;
esac

[ -f "$DOC" ] || { echo "lint: $DOC: no such file" >&2; exit 66; }

violations=0
report() { echo "$*" >&2; violations=$((violations + 1)); }

REQUIRED="check precondition apply rollback"
VALID="check precondition apply verify rollback"

# THE ID COMES FROM THE FILENAME, NEVER FROM FRONTMATTER — see header.
base="$(basename "$DOC")"
file_id="$(printf '%s' "$base" | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p')"
if [ -z "$file_id" ]; then
  if [ "$SCOPE_ONLY" -eq 1 ]; then
    # An unparseable ID is never a skip (see the threshold requirement's own
    # "unparseable filename is a violation" scenario) — it must always be
    # EXAMINED, by the full lint pass, which reports the real diagnostic.
    # --scope-only therefore answers "in scope" here rather than inventing a
    # violation of its own: the caller is expected to run the full lint next.
    echo "in-scope: $DOC (unparseable filename ID — full lint will report it)"
    exit 0
  fi
  echo "lint: $DOC: filename does not begin with a numeric migration ID" >&2
  exit 1
fi

fm_fmt="$(awk -F': *' '/^migration_format:/ { print $2; exit }' "$DOC" | tr -d '[:space:]')"
fm_id="$(awk -F': *' '/^id:/ { print $2; exit }' "$DOC" | tr -d '[:space:]')"

# In scope if the filename says so. A declaration may ADD a migration to scope
# but never remove one — opting in is always allowed, opting out is not
# expressible.
in_scope=0
above=0
if [ "$((10#$file_id))" -ge "$((10#$THRESHOLD))" ]; then
  above=1; in_scope=1
fi
[ "$fm_fmt" = "executable" ] && in_scope=1

if [ "$SCOPE_ONLY" -eq 1 ]; then
  # "In scope" here means "the full lint pass would examine this document at
  # all" — which includes the in_scope=1 case above AND a below-threshold
  # document that declared a garbage migration_format value (that document
  # is not skipped either; the full pass reports it as an L0 violation
  # below). The ONLY true skip is below-threshold with NOTHING declared.
  if [ "$in_scope" -eq 1 ] || [ -n "$fm_fmt" ]; then
    echo "in-scope: $DOC"
    exit 0
  fi
  echo "out-of-scope: $DOC: id $file_id is below threshold $THRESHOLD and declares no migration_format"
  exit 1
fi

# Below the threshold and not opted in, this document predates the executable
# format. It is frozen history — skip it rather than reporting violations
# nobody will ever fix. Retrofit scope is deliberately zero.
if [ "$in_scope" -eq 0 ]; then
  if [ -n "$fm_fmt" ]; then
    echo "L0: $DOC: unknown migration_format value '$fm_fmt'" >&2
    exit 1
  fi
  exit 0
fi

if [ -n "$fm_fmt" ] && [ "$fm_fmt" != "executable" ]; then
  report "L0: $DOC: unknown migration_format value '$fm_fmt'"
fi
if [ "$above" -eq 1 ] && [ "$fm_fmt" != "executable" ]; then
  report "threshold: $DOC: id $file_id is at or above threshold $THRESHOLD but frontmatter does not declare migration_format: executable"
fi
# Frontmatter `id:` is a human-readable assertion, cross-checked against the
# filename that actually decides scope. The two can only disagree in the
# direction of "frontmatter is wrong", never in a way that changes what got
# judged — scope was already decided above, from the filename alone. A
# non-numeric frontmatter id (e.g. `id: abc`) is reported directly rather
# than handed to bash arithmetic, which would error out and report nothing.
if [ -n "$fm_id" ]; then
  case "$fm_id" in
    *[!0-9]*)
      report "id-mismatch: $DOC: frontmatter id '$fm_id' is not numeric"
      ;;
    *)
      if [ "$((10#$fm_id))" -ne "$((10#$file_id))" ]; then
        report "id-mismatch: $DOC: frontmatter id '$fm_id' does not match filename id '$file_id'"
      fi
      ;;
  esac
fi

# `applies_to` MUST BE PRESENT — the one frontmatter field this format newly
# makes load-bearing.
#
# §08 has always listed `applies_to` as a required field, but below the
# threshold it is only impact-awareness metadata for plan output, so its
# absence costs nothing an operator would notice. At or above the threshold it
# becomes the WRITE BOUNDARY: "a step's apply block MUST NOT modify any file or
# directory outside the paths its migration's applies_to declares" is the
# clause that makes the rollback contract bounded rather than aspirational. A
# boundary that can be omitted entirely is not a boundary — an in-scope
# migration with no `applies_to` line at all has an *undefined* permitted write
# set, and every subsequent statement about what its rollback owes the tree is
# vacuous. Verified absent from this linter by construction in the final
# whole-branch review (0040-no-frontmatter-fields.md linted clean at exit 0
# with no `applies_to`, no `slug`, no `title`, no versions).
#
# ONLY PRESENCE IS CHECKED, deliberately. Whether the declared paths are the
# ones the apply block actually writes to is unenforceable here and is stated
# in §08 as an author obligation — see the "no rule in this format's linter
# checks which paths an apply block actually writes to" paragraph. Presence is
# the part that IS checkable, and it is the part whose absence makes the rest
# meaningless. The other §08-required fields (`slug`, `title`, `from_version`,
# `to_version`) are deliberately NOT checked here: none of them changes what
# any block is permitted to do, and inventing four more frontmatter rules in a
# fix round is how a linter grows checks nobody asked for.
fm_applies="$(awk '/^applies_to:/ { found = 1; exit } END { print (found ? "yes" : "no") }' "$DOC")"
if [ "$fm_applies" != "yes" ]; then
  report "frontmatter: $DOC: no 'applies_to:' field — at or above the threshold this is the write boundary an apply block may not cross, not merely plan-output metadata"
fi

steps="$(bash "$SCRIPT_DIR/extract.sh" steps "$DOC")"

# AN IN-SCOPE MIGRATION MUST DECLARE AT LEAST ONE STEP.
#
# §08 ("Step structure"): "Every migration body MUST contain at least one
# step." Nothing enforced that at lint time until fix round 4, and the omission
# was not benign: §08's Conformance section requires an adopting host to run
# this linter IN CI, so a document that cannot run — because it declares
# nothing to run — turned that CI job GREEN. run-migration.sh refuses it, but
# CI is where a host finds out, and CI runs the linter, not the runner.
#
# THE COMMENT THIS REPLACES WAS FALSE. tools/migration-runner.test.sh said, of
# 0039-zero-steps.md: "Lint alone cannot catch this (every per-step rule
# iterates zero times over an empty step list) — only the runner's own
# zero-steps refusal closes this one." Every per-step rule does indeed iterate
# zero times; that is an argument about the per-step rules, not about the
# linter, which can count `### Step ` headings exactly as L6 already iterates
# them. Reproduced RED before this rule existed:
#   $ lint-migration.sh --host claude-workflow 0039-zero-steps.md ; echo $?
#   0
# The reviewer hit the same thing on a first authored migration by typing
# `## Step 1:` instead of `### Step 1:`.
#
# NOT NUMBERED: this is a property of the document, like the filename-ID and
# frontmatter checks above, not of a step (there is no step to attach it to).
#
# The runner's own zero-steps refusal STAYS. It is not made redundant by this:
# it is the guard that still holds on a path where the lint gate is bypassed or
# stubbed, and the suite exercises exactly that path.
if [ -z "$steps" ]; then
  report "steps: $DOC: declares no '### Step ' heading — an in-scope migration with no steps cannot run, and §08 requires at least one"
fi

# L6 — steps numbered consecutively from 1. The extractor deliberately
# tolerates a gap structurally (bounding a step at "the next heading", not at
# "N+1", so a gap can't merge two steps) but that tolerance is a defense
# against a heading gap hiding a step's roles, not a license for gaps to
# exist. The linter is where authoring discipline is enforced.
prev=0
for s in $steps; do
  prev=$((prev + 1))
  if [ "$s" -ne "$prev" ]; then
    report "L6: step $s: steps are not numbered consecutively (expected step $prev)"
  fi
done

for s in $steps; do
  roles="$(bash "$SCRIPT_DIR/extract.sh" roles "$DOC" "$s")"

  # L1 — every required role present at least once (duplicates are L3's job)
  for r in $REQUIRED; do
    printf '%s\n' "$roles" | grep -qx "$r" || \
      report "L1: step $s: missing required role '$r'"
  done

  # L3 — no role (required or optional) may appear more than once
  dupes="$(printf '%s\n' "$roles" | awk 'NF' | sort | uniq -d)"
  for d in $dupes; do
    report "L3: step $s: role '$d' appears more than once"
  done

  # L2 + L4 — one pass, tracking the most recent **Label:** heading. FENCE
  # STATE IS CHECKED FIRST, before step-boundary logic — see the header
  # comment. Bounded on "the next `### Step ` heading of any number", not
  # `nextp`/N+1, for the same reason mr_steps is: a numbering gap must not
  # extend a step past where it should actually end (L6 above is what
  # penalises the gap itself).
  bad="$(awk -v stepp="### Step ${s}" '
    function delim_ok(line, plen,   d) {
      d = substr(line, plen + 1, 1)
      return (d == "" || d == ":" || d == " ")
    }
    BEGIN {
      want["check"]        = "**Idempotency check:**"
      want["precondition"] = "**Pre-condition:**"
      want["apply"]        = "**Apply:**"
      want["verify"]       = "**Verify:**"
      want["rollback"]     = "**Rollback:**"
    }
    !infence && index($0, "```") == 1 {
      infence = 1
      info = substr($0, 4); sub(/[ \t]+$/, "", info)
      if (!in_step) next
      if (info !~ /^bash[ \t]+role=/) next
      r = info; sub(/^bash[ \t]+role=/, "", r)
      if (!(r in want)) { printf "L4|%s\n", r; next }
      if (label != want[r]) printf "L2|%s|%s|%s\n", r, want[r], label
      next
    }
    infence && index($0, "```") == 1 { infence = 0; next }
    infence { next }
    index($0, "### Step ") == 1 {
      in_step = (index($0, stepp) == 1 && delim_ok($0, length(stepp)))
      label = ""
      next
    }
    !in_step { next }
    index($0, "**") == 1 { label = $0; sub(/[ \t]+$/, "", label); next }
  ' "$DOC")"

  while IFS='|' read -r rule a b c; do
    [ -n "$rule" ] || continue
    case "$rule" in
      L4) report "L4: step $s: unknown role '$a' — valid roles are $VALID" ;;
      L2) report "L2: step $s: role '$a' expects heading $b but follows $c" ;;
    esac
  done <<EOF
$bad
EOF

  # L8 — a tagged fence's body must contain at least one EXECUTABLE STATEMENT,
  # for ANY role.
  #
  # WIDENED IN FIX ROUND 4, from "empty or whitespace-only". The old test was
  # `tr -d '[:space:]'`, so a body of
  #
  #     # TODO: check whether the allowlist is already hardened
  #
  # was one character past it and linted clean. Reproduced RED against the real
  # CLI before this change, on 0036-silent-noop.md (an otherwise perfectly
  # well-formed, in-scope migration whose only defect is that placeholder in
  # its `check` fence):
  #   $ lint-migration.sh --host claude-workflow 0036-silent-noop.md ; echo $?
  #   0
  #   $ run-migration.sh --host claude-workflow 0036-silent-noop.md wd ; echo $?
  #   step 1: skipped (already applied)
  #   0
  #   $ ls -a wd     # empty — the apply never ran
  # `bash -c '# comment'` exits 0, and the three-valued check contract reads
  # exit 0 as ALREADY APPLIED. The step is therefore never attempted at all,
  # which is strictly worse than the apply-only-a-comment variant (attempted,
  # and vacuous) that an earlier round recorded as an accepted gap. One test
  # closes all three: check, apply, and precondition alike.
  #
  # `:` AND `true` COUNT AS NON-EXECUTABLE when they are the WHOLE body.
  # This is a decision, not an oversight. `:` is the shell's explicit no-op; a
  # fence whose entire body is `:` provably does nothing and exits 0 — the same
  # observable outcome as an empty body, reached deliberately. Reproduced RED
  # on 0038-colon.md: lint 0, `step 1: skipped (already applied)`, empty
  # workdir. Nothing legitimate is lost: a `check` that must always report "not
  # applied" writes `false`, and a step whose `apply` genuinely has nothing to
  # do is a step that should not exist. `true` is stripped for the identical
  # reason. Both are stripped only as a WHOLE LINE (optionally with a trailing
  # `;`): `:` inside a larger body (`while :; do`, `: "${VAR:?}"`) is ordinary
  # shell and is left completely alone, because the line then does not match.
  #
  # WHAT THIS RULE DOES NOT DO — STATED, NOT CLOSED. An earlier version of this
  # comment said stripping `true` closed a hole that would otherwise be "one
  # keystroke away". That overclaimed: the keystroke is `true; true`, and it
  # lints clean right now. The test here is WHOLE-LINE and LEXICAL, so every
  # one of these gets past it and still does nothing on an untouched tree —
  # each executed against the real CLI, not reasoned about:
  #     true; true            :;:            ( : )            exit 0
  #     echo "checking whether the allowlist is hardened"
  # As a `check`, each exits 0, which the three-valued contract reads as
  # ALREADY APPLIED — `step 1: skipped (already applied)` on a tree where
  # nothing was applied. As an `apply`, `echo "TODO: write the file"` reports
  # `step 1: applied` having written nothing.
  #
  # THE RULE IS NOT WIDENED TO CHASE THESE, deliberately. "Does this shell
  # accomplish anything?" is not answerable by inspecting the text, and a
  # widening that tries trades a caught no-op for a risk of rejecting real
  # migrations — a trade this format has already lost once: L10 rejected a valid,
  # README-following migration for exactly that kind of over-reach, and
  # 0061-l10-comment-mentions-heredoc.md is the committed guard against it.
  # What L8 promises is bounded and honest: it rejects a body that is provably
  # inert by inspection. It does not detect a body that executes and
  # accomplishes nothing. §08 and the README state the same limit in the same
  # terms, and the accepted shapes above are pinned as ACCEPTED in
  # tools/migration-runner.test.sh so the limit stays machine-checked.
  #
  # WHY THIS IS A LINTER RULE, NOT A RUNNER ONE. Run for real, `bash -c ''`
  # (and `bash -c '<blank line>'`) exits 0 — which the three-valued check
  # contract reads as "already applied" — so a tagged-but-empty `check` fence
  # makes the runner report `step N: skipped (already applied)` and apply
  # nothing, on a tree where nothing was ever applied. Reproduced against the
  # REAL CLI (see 0049-bad-l8-empty-check.md), not merely asserted: this is
  # the exact silent-no-op class the whole format exists to close, one layer
  # beneath an un-annotated fence — this one IS tagged, and still does
  # nothing. The pre-flight scan in run-migration.sh already tests emptiness
  # for `apply` specifically (a step whose apply fence is present but empty),
  # but `check` and `precondition` have no equivalent there — an empty
  # `precondition` passes just as vacuously, for the same reason. Fixing this
  # in the linter, once, for every role uniformly, is what the runner's own
  # lint-before-execute gate already turns into a hard refusal for all five
  # roles, rather than bolting a sixth ad hoc emptiness check onto the
  # runner's dispatch loop.
  #
  # Reuses extract.sh's own `block` subcommand — the exact same extraction
  # `run_block` itself calls — rather than a second, drifting reimplementation
  # of "capture this fence's body." `tr -d '[:space:]'` collapses blank lines
  # and spaces alike, so a fence containing only a blank line does not pass
  # as "non-empty" merely because it has bytes in it.
  #
  # EXIT STATUS CHECKED FIRST, BEFORE TRUSTING EMPTINESS. An earlier version
  # of this comment claimed "an absent role is already L1's job; this only
  # fires for a role that IS present but resolves to whitespace" — disproved
  # by construction in fix round 1's review: a `role=verify` fence containing
  # one real command (see 0045-unclosed-fence-verify.md's `grep`), left
  # unclosed at EOF, IS present per `roles` (mr_roles reports a role from the
  # fence's OPENING line) but `extract.sh block`
  # still exits 1 for it (mr_block only confirms a role on the CLOSING line —
  # see L7's own header comment for the same asymmetry). Without checking the
  # exit status, that extraction FAILURE was silently read as an EMPTY body,
  # and L8 reported "role 'verify' is empty or whitespace-only" — false; the
  # body is real, non-empty content that extraction simply never got to
  # return. That is the exact BLOCK_MISSING-vs-127 conflation this codebase
  # already had to fix once in run-migration.sh's run_block; fixed the same
  # way here: an extraction failure is skipped, not reported, and is left to
  # whichever rule actually diagnoses it (L7, for an unclosed fence).
  #
  # De-duplicated via `sort -u`: a role appearing twice in $roles (already
  # its own L3 violation) would otherwise resolve to the same fence twice via
  # mr_block and print the identical L8 line once per occurrence — cosmetic,
  # but pointless noise on a document already flagged elsewhere.
  for r in $(printf '%s\n' "$roles" | sort -u); do
    body="$(bash "$SCRIPT_DIR/extract.sh" block "$DOC" "$s" "$r" 2>/dev/null)"
    extract_rc=$?
    [ "$extract_rc" -eq 0 ] || continue
    # Drop blank lines, full-line `#` comments, and whole-line no-op builtins,
    # then ask whether anything at all is left. `tr -d '[:space:]'` is retained
    # on the RESIDUE so a line of nothing but spaces still counts as blank.
    meaningful="$(printf '%s\n' "$body" | awk '
      { line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
      line == "" { next }
      substr(line, 1, 1) == "#" { next }
      line == ":" || line == ":;" || line == "true" || line == "true;" { next }
      { print line }
    ' | tr -d '[:space:]')"
    if [ -z "$meaningful" ]; then
      report "L8: step $s: role '$r' contains no executable statement (only blank lines, comments, or no-op builtins)"
    fi

    # L10 — an UNTERMINATED HEREDOC in a tagged fence's body.
    #
    # This is the semantic half of the truncation class L9 catches
    # structurally, and it is the half that reaches cases L9 does not: a
    # truncating line that is a BARE "```" (which L9 cannot distinguish from a
    # legitimate closing fence), and an author who simply mistyped the
    # terminator. In both cases `bash -c "$body"` writes the partial payload
    # and EXITS 0 — so an apply "succeeds", and a check written against the
    # intended full payload does not match, while a check written against a
    # prefix of it does, which is how the truncated migration in the review's
    # Critical 1 permanently self-certified as done.
    #
    # WHAT THE PAIR ACTUALLY COVERS, RE-STATED AFTER THE BACKSLASH FIX BELOW.
    # An earlier version of this comment said L9 "covers the tagged-fence
    # truncation case independently of this scan". It does not, and the
    # counter-example was constructed: 0062-l10-backslash-bare-fence.md
    # truncates a `<<\EOF` heredoc with a BARE "```" and, before that fix, fired
    # NEITHER rule (lint rc 0, `step 1: applied`, truncated payload, second run
    # `skipped (already applied)`). The honest division of labour, as tested:
    #   - the truncating line carries an INFO STRING (```bash, ```markdown):
    #     L9 fires, from the terminator alone, whatever the body contains.
    #     0052-bad-l9-heredoc-fence.md.
    #   - the truncating line is BARE and the body opened a heredoc this scan
    #     can parse: L10 fires. 0062-l10-backslash-bare-fence.md,
    #     0063-l10-backslash-bare-rollback.md.
    #   - no nested fence at all, terminator mistyped `EOFF`: L10 fires and
    #     nothing else does — L7, L8 and L9 all pass it.
    #     0058-bad-l10-mistyped-heredoc.md.
    # A BARE truncating line inside a body whose heredoc opener this scan does
    # NOT parse is covered by neither, and the narrowings listed below are the
    # list of such openers. That residue is a real one; it is not claimed away.
    #
    # WHY THIS IS HAND-ROLLED RATHER THAN DELEGATED TO BASH'S OWN PARSER.
    # `bash -n` looked like the precise, heuristic-free answer and was tried
    # first. It does not work on the bash this fleet actually runs: bash 5
    # warns "here-document at line N delimited by end-of-file", but bash 3.2 —
    # what macOS ships as /bin/bash, and what every one of these scripts runs
    # under here — is completely silent and exits 0. Executed:
    #   $ printf "cat >> X <<'EOF'\n\n## hi\n" > h1.sh
    #   $ bash -n h1.sh ; echo $?      # -> 0, no stderr at all
    #   $ bash h1.sh    ; echo $?      # -> 0, and X contains the partial payload
    # A detector that only fires on some operators' machines is not a detector,
    # so the scan below reads the operators itself.
    #
    # DELIBERATELY CONSERVATIVE — it skips rather than guesses, because a FALSE
    # POSITIVE here rejects a valid migration. It ignores a `<<` that is inside
    # an odd number of preceding quotes on its line (`echo "a << b"`), one
    # inside a `$((...))` span (`x=$((1<<2))`), and a `<<<` herestring; and it
    # only accepts an unquoted delimiter matching ^[A-Za-z_][A-Za-z0-9_]*$. A
    # quoted delimiter (`<<'EOF'`, `<<"EOF"`, `<<\EOF`) may be anything
    # non-empty. The terminator must match exactly at column 1 for `<<`, and
    # after leading tabs for `<<-`, which is what bash itself requires.
    #
    # COMMENT LINES. A whole-line `#` comment is skipped before any of that.
    # THE NARROWINGS ARE NOT ALL MISSED-DETECTION-ONLY — an earlier version of
    # this comment said "each narrowing is a possible missed detection, not a
    # possible false accusation", and the comment-line gap disproved it: this
    # scan read a heredoc opener out of PROSE and rejected a valid migration.
    # The worst case was a migration following this runner's own README, whose
    # apply was
    #     # Emitted with printf, not <<EOF: a fence delimiter inside a heredoc
    #     # would truncate this block (see the runner README, L9/L10).
    #     { printf ... ; } >> CLAUDE.md
    # — valid bash that does its work. Reproduced RED on
    # 0061-l10-comment-mentions-heredoc.md:
    #   $ lint-migration.sh --host claude-workflow 0061-...md ; echo $?
    #   L10: step 1: role 'apply' opens a heredoc delimited by 'EOF' that is
    #   never terminated ... running it writes a partial payload
    #   1
    # Every substantive clause of that message was false: no heredoc is opened, nothing is unterminated, and no partial payload is written. Only the trailing "and still exits 0" is true, and it is true of the CORRECT behaviour — the body exits 0 having written the payload WHOLE. `# do not use << here` fired the
    # same way, naming the delimiter `here`. L8's scan in this same loop
    # already discarded full-line `#` comments; L10 now agrees with it. The
    # heredoc-BODY branch runs first, so a PAYLOAD line beginning with `#` (a
    # markdown heading being emitted, say) is unaffected — 0059's own payload
    # is exactly that shape and still lints clean.
    #
    # BACKSLASH-QUOTED DELIMITER. `<<\EOF` is bash's third heredoc quoting
    # form and bash 3.2 treats it identically to `<<'EOF'`; this scan accepted
    # only `<<WORD`, `<<'W'` and `<<"W"`, so it parsed no delimiter and skipped
    # the opener entirely. Combined with a BARE truncating "```" that leaves L9
    # silent by design, that reopened the review's Critical 1 verbatim against
    # this very linter — see the "WHAT THE PAIR ACTUALLY COVERS" note above for
    # the executed transcript.
    heredoc="$(printf '%s\n' "$body" | awk '
      function quoted(line, upto,   i, c, sq, dq) {
        sq = 0; dq = 0
        for (i = 1; i < upto; i++) {
          c = substr(line, i, 1)
          if (c == "\\") { i++; continue }
          if (c == "'"'"'" && dq == 0) sq = 1 - sq
          else if (c == "\"" && sq == 0) dq = 1 - dq
        }
        return (sq || dq)
      }
      function in_arith(line, upto,   pre, n, m) {
        pre = substr(line, 1, upto - 1)
        n = gsub(/\$\(\(/, "&", pre)
        m = gsub(/\)\)/, "&", pre)
        return (n > m)
      }
      # Inside a heredoc body: consume until the pending terminator matches.
      npend > 0 {
        cand = $0
        if (dash[1]) sub(/^\t+/, "", cand)
        if (cand == delim[1]) {
          for (k = 1; k < npend; k++) { delim[k] = delim[k+1]; dash[k] = dash[k+1] }
          npend--
        }
        next
      }
      {
        line = $0
        # A whole-line shell comment is prose, not an operator. See the
        # COMMENT LINES header note above for the reproduction.
        probe = line; sub(/^[ \t]+/, "", probe)
        if (substr(probe, 1, 1) == "#") next
        i = 1
        while (1) {
          p = index(substr(line, i), "<<")
          if (p == 0) break
          abs = i + p - 1
          if (substr(line, abs, 3) == "<<<") { i = abs + 3; continue }
          if (quoted(line, abs) || in_arith(line, abs)) { i = abs + 2; continue }
          rest = substr(line, abs + 2)
          d = 0
          if (substr(rest, 1, 1) == "-") { d = 1; rest = substr(rest, 2) }
          sub(/^[ \t]+/, "", rest)
          # A backslash-quoted delimiter is the third heredoc quoting form
          # bash accepts, equivalent to the single-quoted one. Strip the
          # backslash and let the unquoted-word branch below read the word.
          # See the BACKSLASH-QUOTED DELIMITER header note above.
          # (No apostrophes in this comment: it sits inside a single-quoted
          # awk program, where one would end the program mid-file.)
          if (substr(rest, 1, 1) == "\\") rest = substr(rest, 2)
          q = substr(rest, 1, 1)
          w = ""
          if (q == "'"'"'" || q == "\"") {
            e = index(substr(rest, 2), q)
            if (e > 0) w = substr(rest, 2, e - 1)
          } else if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/)) {
            w = substr(rest, RSTART, RLENGTH)
          }
          if (w == "") { i = abs + 2; continue }
          npend++; delim[npend] = w; dash[npend] = d
          i = abs + 2
        }
      }
      END { if (npend > 0) print delim[1] }
    ')"
    if [ -n "$heredoc" ]; then
      report "L10: step $s: role '$r' opens a heredoc delimited by '$heredoc' that is never terminated in the captured body — running it writes a partial payload and still exits 0"
    fi
  done
done

# L5 — role= only on bash fences, and only in the exact grammar. Scans every
# fence in the document (fence state tracked first, exactly like
# extract.sh's mr_roles/mr_block, so a "```" inside a heredoc body is not
# mistaken for a real fence delimiter) and remembers the most recently seen
# step heading so each violation can be reported as `L5: step <s>: ...`.
while IFS= read -r line; do
  [ -n "$line" ] && report "$line"
done < <(awk '
  !infence && index($0, "```") == 1 {
    infence = 1
    info = substr($0, 4); sub(/[ \t]+$/, "", info)
    if (info ~ /role=/ && info !~ /^bash[ \t]+role=[a-z]+$/) {
      s = (curstep == "" ? "0" : curstep)
      printf "L5: step %s: role= info string does not match ^bash[ \\t]+role=[a-z]+$: %s\n", s, info
    }
    next
  }
  infence && index($0, "```") == 1 { infence = 0; next }
  infence { next }
  index($0, "### Step ") == 1 {
    rest = substr($0, 10); n = ""
    for (i = 1; i <= length(rest); i++) {
      c = substr(rest, i, 1)
      if (c >= "0" && c <= "9") n = n c; else break
    }
    if (n != "") curstep = n + 0
    next
  }
' "$DOC")

# L9 — a TAGGED fence must not be terminated by a line that is itself a fence
# OPENER, i.e. a "```" line carrying a non-empty info string.
#
# THE DEFECT THIS CLOSES. extract.sh's mr_block ends its capture on ANY line
# whose first three characters are three backticks. A heredoc body containing
# such a line therefore ends the apply block THERE, silently. §08 already
# mandates heredoc-awareness for `### Step` headings and was silent on the
# identical hazard for fences. Reproduced RED against the real CLI on
# 0039-patch-claude-md.md — an in-scope migration whose apply is
# `cat >> CLAUDE.md <<'EOF'` … containing a nested ```bash fence … `EOF`:
#   $ lint-migration.sh --host claude-workflow 0039-patch-claude-md.md ; echo $?
#   0
#   $ run-migration.sh --host claude-workflow 0039-patch-claude-md.md wd
#   step 1: applied            (rc 0)
#   $ cat wd/CLAUDE.md         # only the truncated prefix
#   $ run-migration.sh ... wd  # step 1: skipped (already applied)
# The step's own idempotency check then MATCHES the truncated output, so the
# migration permanently self-certifies as done. Every existing guard passes it:
# L1 reads the role from the OPENING line, L7 balances (the inner fence closes
# and the real closer re-opens), L8 sees a non-empty body, the runner's
# zero-apply pre-flight sees a non-empty body, and `bash -c` on an unterminated
# heredoc writes the partial payload and exits 0.
#
# THE PREVALENCE ARGUMENT THAT USED TO SIT HERE WAS FABRICATED. This comment
# said "6 of the 73 migrations in the fleet today already emit a three-backtick
# line from inside a heredoc, which is this fleet's normal idiom for patching
# CLAUDE.md and skill files." The number was relayed from a review and never
# measured. Measured directly across all four hosts' migrations/ directories —
# 73 numbered migrations (claude-workflow 34, codex-workflow 16,
# opencode-workflow 12, pi-agentic-apps-workflow 11):
#   - 7 use a heredoc at all inside a fenced body;
#   - 0 emit a three-backtick line from inside a heredoc;
#   - 0 emit a three-backtick line into a file by any means.
# Running this file's own L10 scan over all 482 fenced bodies in those 73
# documents fires 0 times.
#
# THAT DOES NOT WEAKEN L9. Its justification is the constructed vulnerability
# above, which is executed and committed as
# 0052-bad-l9-heredoc-fence.md. A rule that closes a demonstrated
# silent-self-certifying write does not need the defect to be popular first —
# and quoting a number nobody measured is how a rule acquires a justification
# that evaporates when someone checks it.
#
# WHY THIS FORMULATION, AND NOT "the body's last line opens a fence". The
# nested fence line is CONSUMED as the closer — it never appears in the
# captured body at all (0039's body ends at "## Running the suite"), so a rule
# phrased over the body's last line does not fire on the very case it was
# proposed for. Verified by extracting 0039's apply block directly. The
# observable that actually distinguishes truncation is the TERMINATOR: a
# CommonMark closing fence may not carry an info string, so a "```" line with
# one is never a legitimate closer, and a tagged fence closed by one is
# definitively truncated. That makes this lexical and exact — no shell parsing,
# no heuristics.
#
# WHAT L10 ADDS, AND WHERE THE PAIR STILL DOES NOT REACH. L10 sees a truncating
# BARE "```" (and an ordinary mistyped terminator) by detecting the
# unterminated heredoc such a truncation leaves behind — but only for a heredoc
# opener its scan can parse. An earlier version of this paragraph said the two
# rules covered the case "independently" of each other, which was disproved by
# construction: 0062-l10-backslash-bare-fence.md truncates a `<<\EOF` heredoc
# with a bare fence and, before the backslash fix, fired neither rule. See the
# "WHAT THE PAIR ACTUALLY COVERS" note above L10's scan for the tested
# division of labour and the residue that remains outside both.
#
# THERE IS NO ESCAPE VIA A FOUR-BACKTICK OUTER FENCE, so this rule does not
# forbid something the format otherwise permits. Verified:
#   $ printf '### Step 1: x\n\n**Apply:**\n````bash role=apply\necho hi\n````\n' > probe4.md
#   $ extract.sh roles probe4.md 1
#   (no output)
# — `substr($0,4)` on a four-backtick opener starts with a backtick, so the
# info string fails the `^bash[ \t]+role=[a-z]+$` grammar and the fence carries
# no role at all. The documented escapes are to indent the nested fence or to
# emit it via `printf '%s\n' '```bash'`; both are in the README.
#
# SCOPED TO TAGGED FENCES ON PURPOSE, and the two cases that scoping leaves
# alone were BOTH constructed and run rather than reasoned about:
#
#   - An illustration fence containing an EVEN number of nested fence lines
#     (``` ```markdown / ```bash / ``` / ``` ```) re-synchronises the state
#     machine by the time the illustration ends: every tagged fence after it
#     parses correctly and the document lints clean at rc 0 — verified. Its
#     content is never executed, so nothing silent happens. Reporting it would
#     be a false accusation.
#   - An ODD number desynchronises the rest of the document, and that is loud,
#     not quiet — verified on the same shape with one fence line removed:
#       L1: step 1: missing required role 'check'   (and precondition, apply,
#       rollback)
#       L7: step 1: fence opened at line 39 ... is never closed
#     Four L1s and an L7 is not a document anyone ships by accident.
#
# Widening this rule to every fence would also reject a legitimate
# four-backtick illustration block, which nothing else in this format forbids.
while IFS= read -r line; do
  [ -n "$line" ] && report "$line"
done < <(awk '
  !infence && index($0, "```") == 1 {
    infence = 1
    openinfo = substr($0, 4); sub(/[ \t]+$/, "", openinfo)
    opentagged = (openinfo ~ /^bash[ \t]+role=[a-z]+$/)
    openrole = openinfo; sub(/^bash[ \t]+role=/, "", openrole)
    openline = NR
    openstep = (curstep == "" ? "0" : curstep)
    next
  }
  infence && index($0, "```") == 1 {
    infence = 0
    closeinfo = substr($0, 4); sub(/[ \t]+$/, "", closeinfo)
    if (opentagged && closeinfo != "") {
      printf "L9: step %s: role %c%s%c fence opened at line %d is terminated by a nested fence line at line %d (info string: %s) — its body is truncated there\n", \
        openstep, 39, openrole, 39, openline, NR, closeinfo
    }
    opentagged = 0
    next
  }
  infence { next }
  index($0, "### Step ") == 1 {
    rest = substr($0, 10); n = ""
    for (i = 1; i <= length(rest); i++) {
      c = substr(rest, i, 1)
      if (c >= "0" && c <= "9") n = n c; else break
    }
    if (n != "") curstep = n + 0
    next
  }
' "$DOC")

# L7 — every fence a migration opens must be closed. Same fence-state
# tracking as every other scan in this file, plus the same step-tracking
# used by L5, but reporting only from END: there can be at most one
# genuinely unclosed fence per document. Once inside an unclosed fence,
# EVERY line after it — including any later "```" — is consumed by this
# same state machine as that fence's own content (the `infence &&
# index($0, "```") == 1` rule closes it), so the state machine can never
# close one fence and then leave a second one open; only the LAST fence
# opened in the document can possibly still be open at EOF.
unclosed="$(awk '
  !infence && index($0, "```") == 1 {
    infence = 1
    openinfo = substr($0, 4); sub(/[ \t]+$/, "", openinfo)
    openline = NR
    openstep = (curstep == "" ? "0" : curstep)
    next
  }
  infence && index($0, "```") == 1 { infence = 0; next }
  infence { next }
  index($0, "### Step ") == 1 {
    rest = substr($0, 10); n = ""
    for (i = 1; i <= length(rest); i++) {
      c = substr(rest, i, 1)
      if (c >= "0" && c <= "9") n = n c; else break
    }
    if (n != "") curstep = n + 0
    next
  }
  END {
    if (infence) printf "%s|%s|%s\n", openstep, openline, openinfo
  }
' "$DOC")"
if [ -n "$unclosed" ]; then
  IFS='|' read -r ol_step ol_line ol_info <<EOF
$unclosed
EOF
  report "L7: step $ol_step: fence opened at line $ol_line (info string: $ol_info) is never closed before end of file"
fi

[ "$violations" -eq 0 ]
