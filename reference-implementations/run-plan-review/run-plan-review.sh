#!/usr/bin/env bash
# run-plan-review-version: 1.0.0
#
# VERSION MARKER — read by every host installer before writing this file to the
# SHARED path ~/.agenticapps/bin/. Installers MUST refuse to overwrite a higher
# version (treat an unmarked file as 0.0.0). Bump whenever behaviour changes.
#
# This marker is LATE. The gate and reviewer-cli were both given one after
# core#41 — a host installer blind-installed its 3-arm reviewer-cli over a 4-arm
# one, the `opencode` arm vanished, and the next review that asked for it was
# recorded as "reviewer unavailable" and waved through with one fewer opinion.
# The producer sat in the same shared directory, installed by the same script,
# three lines below the gate's arbitration block — and was left blind. Nothing
# has broken yet only because no sibling host ships a producer to overwrite it
# with; that is luck, not design.
#
#   1.0.0 — first marked version. Carries the stdout sanitiser (vendor banners
#           and session-hook logs were landing in REVIEWS.md as review prose),
#           the `## Reviewer:` forge guard, and per-code reporting of
#           reviewer-cli 1.1.0's 3/4/5 exits.
#
# run-plan-review.sh — drive >=2 other-vendor agent CLIs to adversarially review an
# active OpenSpec change and write changes/<slug>/REVIEWS.md. Retarget of ADR-0018.
#
# This is the REVIEW PRODUCER. The §18 change-gate (openspec-change-gate.sh) is the
# VERIFIER: it refuses code edits until this script has written REVIEWS.md with
# >= MIN_REVIEWERS (default 2) `## Reviewer:` sections and `openspec validate --all`
# is green. Producer and verifier are deliberately separate processes.
#
# Usage: run-plan-review.sh <change-slug> [reviewer1 reviewer2 ...]
#   default reviewers tried (any that are installed, excluding the implementing agent):
#     gemini, codex, claude, opencode
#
# Env:
#   AGENT_SELF        implementing agent to exclude (default `claude` on this host, so
#                     the >=2 reviewers are always OTHER vendors — the ADR-0018 property)
#   REVIEW_TIMEOUT    hard wall-clock cap per reviewer, seconds (default 180)
#   MIN_REVIEWERS     reviewers required for a non-warning exit (default 2)
#   REVIEWER_CLI      override the wrapper path (default: the shared install, then bin/)
#
# Pilot friction #3 — a reviewer CLI that reads stdin and hangs — is fixed in
# reviewer-cli.sh, not here. This script picks the vendor set and records the
# evidence; the wrapper pins stdin and bounds the clock for every arm. The
# vendor set is core's: claude | gemini | opencode | codex. A name outside it is
# reported unavailable rather than run unbounded.

set -uo pipefail
SLUG="${1:-}"; shift || true
[ -n "$SLUG" ] || { echo "usage: run-plan-review.sh <change-slug> [reviewers...]" >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# $SLUG is pasted straight into a path and the result is later written to, so a
# traversing or absolute slug would make this script overwrite an arbitrary file
# (`run-plan-review.sh ../../src` -> writes src/REVIEWS.md). Accept only a plain
# change-directory name.
case "$SLUG" in
  */*|.|..|-*|"") echo "invalid change slug: '$SLUG' (expected a single directory name)" >&2; exit 2 ;;
esac

CHANGE_DIR="$ROOT/openspec/changes/$SLUG"
[ -d "$CHANGE_DIR" ] || { echo "no such active change: $SLUG" >&2; exit 2; }
# Refuse a symlinked change dir for the same reason: REVIEWS.md must land inside
# the repo's spec slot, not wherever a link points.
[ -L "$CHANGE_DIR" ] && { echo "change dir is a symlink, refusing: $SLUG" >&2; exit 2; }

TIMEOUT="${REVIEW_TIMEOUT:-180}"                 # seconds per reviewer
SELF="${AGENT_SELF:-claude}"                     # this host IS claude — exclude it by default
REVIEWERS=("$@"); [ ${#REVIEWERS[@]} -gt 0 ] || REVIEWERS=(gemini codex claude opencode)

# A non-numeric MIN_REVIEWERS makes `[ "$count" -lt "$MIN" ]` an error, not a
# comparison: bash prints "integer expression expected", the `if` reads false,
# and the script falls through to publish and exit 0 — announcing that the
# floor was met when it was never evaluated.
#
# The floor DEFAULTS TO ONE, matching §18's truth table and the gate, which has
# defaulted to 1 since gate 1.4.0. A default of 2 here meant the producer and
# the verifier disagreed about the same rule: on 2026-07-29 one vendor returned
# and two timed out, and this script discarded the surviving review and wrote
# nothing — evidence the gate would have accepted, thrown away by its producer.
# One floor, stated once. An explicit MIN_REVIEWERS still wins.
MIN="${MIN_REVIEWERS:-1}"
# ZERO IS REJECTED, not merely defaulted away. The previous guard passed `0`,
# and a floor of zero is not a lax policy — it is a live evidence-destroying
# bug: with every reviewer failing, `count` is 0, `0 -lt 0` is false, and the
# script publishes a ZERO-BYTE REVIEWS.md over whatever was there, reports
# "wrote 0 reviewer section(s)" and exits 0. The gate then reads an empty
# artifact where a real review used to be. A floor is a floor; below one there
# is no review to have.
case "$MIN" in
  ''|*[!0-9]*) echo "MIN_REVIEWERS must be a positive integer, got '$MIN'" >&2; exit 2 ;;
  0)           echo "MIN_REVIEWERS must be at least 1, got '0' — a floor of zero publishes empty evidence" >&2; exit 2 ;;
esac

# Validated HERE, before the first vendor is invoked, not after the loop.
# Invoking the producer is the egress act: it hands the change to third-party
# agentic CLIs. Discovering a malformed floor afterwards means the artifacts
# have already left the machine for a run whose result was never usable.
# Reject a bad invocation before anything is sent.

# Vendor dispatch, the stdin pin, and the wall-clock bound all live in
# reviewer-cli.sh — core's reference implementation, vendored at
# `# reviewer-cli-version: 1.0.0` and scored by tools/reviewer-cli-conformance.sh.
# This script used to carry its own copy of the four vendor arms. That is exactly
# the shape that produced core#41: three divergent copies of one wrapper, one of
# them missing the `opencode` arm, all writing the same shared path. A private
# copy of a shared artifact is not a fork, it is a race. Fix behaviour in core
# alongside a harness row and re-vendor; never patch the arms back in here.
#
# Same resolution order as the PreToolUse gate shim, for the same reason: the
# global install is what a scaffolded project gets, and the repo copy is what a
# scaffolder checkout runs before anything is installed.
# `${HOME:-}` because this runs under `set -u`: with HOME unset (cron, a stripped
# CI env) a bare $HOME aborts the script before it can reach the repo fallback
# that would have worked.
REVIEWER_CLI="${REVIEWER_CLI:-${HOME:-}/.agenticapps/bin/reviewer-cli.sh}"
[ -x "$REVIEWER_CLI" ] || REVIEWER_CLI="$ROOT/bin/reviewer-cli.sh"
[ -x "$REVIEWER_CLI" ] || {
  echo "reviewer-cli.sh not found (looked at \$REVIEWER_CLI, ~/.agenticapps/bin, $ROOT/bin)." >&2
  echo "Run install.sh, or apply migration 0032 Step 1, to install the shared wrapper." >&2
  exit 2
}

# ── the verdict-and-substance predicate ──────────────────────────────────────
# THE SAME RULE THE GATE APPLIES. A section this counts must be one the gate
# counts; if the two drift, the producer publishes evidence its own verifier
# rejects, which is the defect class this whole change exists to close. The
# gate carries a byte-identical copy of this awk program under the marker
# `shared-predicate v1`. Change both together or neither.
#
# Reads a review body on stdin. Prints one token and exits 0 when the body is a
# review; prints a reason token and exits 1 when it is not:
#   ok:APPROVE | ok:REQUEST-CHANGES
#   no-verdict | no-substance | conflicting-verdicts
#
# A verdict alone is not a review, and a body alone is not a verdict. Both
# halves were observed counting in production on this repo's own changes.
classify_review() {
  LC_ALL=C awk '
    # shared-predicate v1
    function norm(s) {
      gsub(/[*_]/, "", s)                       # emphasis is removed, not placed
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      gsub(/[[:space:]]+/, " ", s)
      return s
    }
    BEGIN { fence = 0; verdict = ""; conflict = 0; substance = 0 }
    # Fenced blocks are skipped entirely: a verdict quoted in an example is not
    # a verdict, and this is what makes that rule implementable — fence
    # tracking, not regex cleverness.
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      raw = $0
      n = norm(raw)
      if (n == "") next                                  # blank
      # The producer'"'"'s own generation-timestamp line, by its exact shape.
      if (raw ~ /^[[:space:]]*_generated .* timeout [0-9]+s_[[:space:]]*$/) next
      # Trailer block, opening delimiter through closing.
      if (raw ~ /^[[:space:]]*<!--[[:space:]]*openspec-review-trailer/) { intrailer = 1; next }
      if (intrailer) { if (raw ~ /-->/) intrailer = 0; next }
      # Any markdown heading. The reviewer heading is the section label, not
      # its content; a vendor'"'"'s own subheadings are interior but are still
      # structure rather than substance.
      if (raw ~ /^[[:space:]]*#{1,6}[[:space:]]/) next

      lower = tolower(n)
      if (lower ~ /^verdict[[:space:]]*:[[:space:]]*(approve|request-changes)$/) {
        v = (lower ~ /approve/) ? "APPROVE" : "REQUEST-CHANGES"
        if (verdict != "" && verdict != v) conflict = 1
        verdict = v
        next                                             # a verdict is not substance
      }
      substance = 1
    }
    END {
      if (conflict)        { print "conflicting-verdicts"; exit 1 }
      if (verdict == "")   { print "no-verdict";           exit 1 }
      if (!substance)      { print "no-substance";         exit 1 }
      print "ok:" verdict
    }
  '
}

# Assemble the review prompt from the change artifacts.
read -r -d '' INSTRUCT <<EOF || true
You are an adversarial reviewer. Review this OpenSpec change for correctness, missing
scenarios, wrong assumptions, security/PII issues, and whether the spec delta actually
captures the intent. Reply with a verdict line "VERDICT: APPROVE" or
"VERDICT: REQUEST-CHANGES", then a short bullet list of concrete issues.
EOF
CONTEXT="$(cat "$CHANGE_DIR"/proposal.md "$CHANGE_DIR"/design.md \
             "$CHANGE_DIR"/specs/*/spec.md 2>/dev/null)"
PROMPT="$INSTRUCT

--- CHANGE: $SLUG ---
$CONTEXT"

OUT="$CHANGE_DIR/REVIEWS.md"
# Accumulate into a temp file and only publish at the end. A partial run must not
# destroy the REVIEWS.md an earlier successful run produced — that evidence is what
# the gate reads, and wiping it would silently re-block a reviewed change.
# The trap is armed BEFORE the second mktemp, over both names, so a failure
# between the two cannot leak the first file.
TMP=""; PROMPT_FILE=""
trap 'rm -f "$TMP" "$PROMPT_FILE"' EXIT
TMP="$(mktemp "${TMPDIR:-/tmp}/reviews.XXXXXX")" || { echo "mktemp failed" >&2; exit 2; }
# The wrapper takes the prompt as a FILE and hands it to the vendor as an
# argument — stdin is pinned to /dev/null on every arm, so it can never be the
# delivery channel. Write it once; every reviewer reads the same bytes.
PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/review-prompt.XXXXXX")" || { echo "mktemp failed" >&2; exit 2; }
# A short write (ENOSPC, EDQUOT) would hand every reviewer a truncated change to
# review and their verdicts would still count. Fail instead of reviewing nothing.
printf '%s' "$PROMPT" > "$PROMPT_FILE" || { echo "failed writing the review prompt" >&2; exit 2; }
count=0
for r in "${REVIEWERS[@]}"; do
  [ "$r" = "$SELF" ] && continue
  command -v "$r" >/dev/null 2>&1 || continue
  echo "· running reviewer: $r" >&2
  # REVIEW_TIMEOUT is this producer's knob; REVIEWER_TIMEOUT is the wrapper's.
  # Map one onto the other so the cap documented at the top of this file is the
  # cap actually applied.
  resp="$(REVIEWER_TIMEOUT="$TIMEOUT" "$REVIEWER_CLI" "$r" "$PROMPT_FILE" 2>/dev/null)"
  rc=$?
  # ANY non-zero wrapper exit means "not counted" — §18's whole purpose is TWO
  # independent opinions, and one reachable vendor scored twice is one opinion
  # wearing two names. Checked explicitly rather than inferred from empty
  # output: a vendor can fail late and still have printed something.
  #
  # But WHICH failure decides what the operator does next, and collapsing them
  # sent someone to check PATH for an opencode that was present and working —
  # it had timed out at the default bound on a full-artifact prompt.
  # reviewer-cli 1.1.0 splits the codes; report them apart. An unrecognised code
  # is described as such rather than guessed at, so an older wrapper (where
  # every failure was 3) still degrades honestly instead of lying specifically.
  if [ "$rc" -ne 0 ]; then
    case "$rc" in
      3) echo "  (reviewer unavailable: $r — CLI absent or usage error; not counted)" >&2 ;;
      4) echo "  (reviewer timed out: $r exceeded ${TIMEOUT}s — not counted; raise REVIEW_TIMEOUT to keep this opinion)" >&2 ;;
      5) echo "  (unknown vendor: $r is not one of claude|gemini|opencode|codex — not counted)" >&2 ;;
      *) echo "  ($r failed with exit $rc — not counted)" >&2 ;;
    esac
    continue
  fi
  [ -n "$resp" ] || { echo "  (no output from $r — skipped)" >&2; continue; }

  # SANITISE before this reaches REVIEWS.md. Vendor CLIs print banners and
  # session-hook logs to STDOUT, inline with the review: gemini emitted four
  # lines of SessionEnd hook expansion into a recorded review, and opencode
  # prints a `> build · <model>` banner ahead of any content. Discarding stderr
  # (the 2>/dev/null above) touches neither. REVIEWS.md is the gate's evidence
  # artifact, so what lands in it has to be the review.
  #
  # Strip banner/log lines from BOTH ENDS, never from between content. Leading
  # covers opencode's `> build · <model>`; TRAILING is the one that actually
  # bit — gemini's four SessionEnd hook lines landed AFTER its findings, so a
  # leading-only filter would have sailed straight past the case this exists
  # for. Anything between the first and last content line is passed through
  # untouched: a filter that dropped mid-review lines would silently edit a
  # reviewer's findings, a worse failure than a surviving banner.
  resp="$(printf '%s' "$resp" | awk '
    function is_noise(s) {
      return s ~ /^[[:space:]]*$/ \
          || s ~ /^[[:space:]]*[>[]/ \
          || s ~ /^[[:space:]]*(Created execution plan|Expanding hook command|Hook execution)/
    }
    { line[NR] = $0 }
    END {
      first = 0; last = 0
      for (i = 1; i <= NR; i++) if (!is_noise(line[i])) { if (!first) first = i; last = i }
      if (!first) exit          # nothing but noise — caller skips this reviewer
      for (i = first; i <= last; i++) print line[i]
    }
  ')"
  [ -n "$resp" ] || { echo "  (only banner output from $r — skipped)" >&2; continue; }

  # A captured body carrying its own `## Reviewer:` heading would FORGE extra
  # reviewers: the gate counts distinct headings, so one vendor whose chatter
  # contained that string could clear a threshold that exists to require two.
  # The gate already hardens against this for hand-written document content
  # (fence skipping, distinct names) — this is the same attack arriving through
  # captured stdout, which no amount of gate-side hardening can see.
  # Refuse the whole response rather than rewriting it: a reviewer emitting
  # section headings is not answering in the format we asked for.
  if printf '%s' "$resp" | grep -qE '^[[:space:]]*##[[:space:]]*[Rr]eviewer[[:space:]]*:'; then
    echo "  (rejected $r: response contains a '## Reviewer:' heading — would forge reviewers; not counted)" >&2
    continue
  fi

  # Same guard, same anchoring, for the trailer's opening delimiter. A vendor
  # emitting one yields a file with TWO trailers, which the gate reads as zero
  # reviewers — fail-closed, but an availability hole any single vendor can
  # trigger.
  #
  # ANCHORED AT LINE START, exactly like the guard above, and that is
  # load-bearing rather than tidy: the spec delta states this trailer grammar
  # literally, so a reviewer discussing it necessarily quotes the delimiter. In
  # round 6 of this change's own review, opencode quoted `openspec-review-trailer`
  # inline while arguing this very point. A substring guard would have destroyed
  # the review that found the problem. The mechanism has to survive being
  # talked about.
  if printf '%s' "$resp" | grep -qE '^[[:space:]]*<!--[[:space:]]*openspec-review-trailer'; then
    echo "  (rejected $r: response opens a review trailer — would invalidate the artifact; not counted)" >&2
    continue
  fi

  # A heading is not a review. Reject a response that carries no verdict, or a
  # verdict with nothing under it, BEFORE it is written and counted — the
  # producer and the gate apply one predicate, so evidence this publishes is
  # evidence the gate accepts.
  verdict_class="$(printf '%s' "$resp" | classify_review)"
  case "$verdict_class" in
    ok:*) ;;
    no-verdict)
      echo "  (rejected $r: no verdict line — a review states APPROVE or REQUEST-CHANGES; not counted)" >&2
      continue ;;
    no-substance)
      echo "  (rejected $r: verdict with no body — a verdict alone is not a review; not counted)" >&2
      continue ;;
    conflicting-verdicts)
      echo "  (rejected $r: two conflicting verdicts — malformed; not counted)" >&2
      continue ;;
    *)
      echo "  (rejected $r: unclassifiable response '$verdict_class'; not counted)" >&2
      continue ;;
  esac

  {
    echo "## Reviewer: $r"
    echo "_generated $(date -u +%Y-%m-%dT%H:%M:%SZ) · timeout ${TIMEOUT}s_"
    echo
    printf '%s\n\n' "$resp"
  } >> "$TMP"
  count=$((count+1))
done

if [ "$count" -lt "$MIN" ]; then
  echo "only $count reviewer(s) produced output (need $MIN) — ${OUT#"$ROOT"/} left unchanged." >&2
  echo "Install another other-vendor agent CLI, or use GSD_SKIP_REVIEWS=1 for a logged emergency override." >&2
  exit 1
fi

# An unchecked `cp` is a false success report: it can truncate $OUT and fail, and
# the echo below still says the file was written. The evidence the gate reads
# would then be whatever survived the partial copy.
cp "$TMP" "$OUT" || { echo "failed writing ${OUT#"$ROOT"/} — earlier review evidence may be incomplete" >&2; exit 2; }
echo "wrote $count reviewer section(s) to ${OUT#"$ROOT"/}" >&2
