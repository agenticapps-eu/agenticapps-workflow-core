#!/usr/bin/env bash
# migration-runner-version: 0.1.0
# lint-migration.sh — enforce the executable migration format.
#
# L1  every step has exactly one check, precondition, apply, rollback;
#     verify is 0 or 1
# L2  each role= fence sits under its matching **Label:** heading
# L3  no duplicate roles within a step
# L4  unknown role values are rejected
# L5  role= appears only on bash fences, and only in the exact grammar
#     ^bash[ \t]+role=[a-z]+$
# L6  steps are numbered consecutively from 1 (a gap is a violation, even
#     though the extractor deliberately tolerates it structurally — see
#     mr_steps's "bound by the next heading, not N+1" comment)
# L7  every fence a migration opens must be closed before end of file
# L8  a tagged fence's body must not be empty or whitespace-only, for ANY
#     role (check, precondition, apply, verify, rollback) — see the header
#     comment just above the L8 scan for why this is a linter rule and not a
#     runner one
#
# Every rule above is implemented in this script.
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

THRESHOLD=""
DOC=""
SCOPE_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --scope-only) SCOPE_ONLY=1; shift ;;
    --threshold) THRESHOLD="${2:?--threshold needs a value}"; shift 2 ;;
    --host)
      # Resolve from the declared file rather than making every caller
      # remember a number. THRESHOLDS is core's declaration, one row per host.
      _h="${2:?--host needs a value}"; shift 2
      THRESHOLD="$(sed 's/#.*//' "$SCRIPT_DIR/THRESHOLDS" | awk -v h="$_h" '$1 == h { print $2; exit }')"
      [ -n "$THRESHOLD" ] || { echo "lint: no threshold declared for host '$_h'" >&2; exit 65; }
      ;;
    --*)
      echo "lint: unknown flag '$1'" >&2
      exit 64
      ;;
    *)
      if [ -n "$DOC" ]; then
        echo "lint: unexpected extra argument '$1' (doc already set to '$DOC')" >&2
        exit 64
      fi
      DOC="$1"; shift
      ;;
  esac
done
: "${DOC:?usage: lint-migration.sh [--scope-only] (--threshold N | --host NAME) <doc>}"

# NO "NO THRESHOLD GIVEN" PATH. Omitting both flags is an error, not an
# empty scope — see the header comment above. A caller who forgot --host
# must not silently get "nothing in scope, everything passes."
: "${THRESHOLD:?lint: --threshold or --host is required (no default; see THRESHOLDS) — with neither, every migration would be out of scope and every lint would pass trivially}"

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

steps="$(bash "$SCRIPT_DIR/extract.sh" steps "$DOC")"

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

  # L8 — a tagged fence must not be empty or whitespace-only, for ANY role.
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
  # three real commands, left unclosed at EOF, IS present per `roles` (mr_roles
  # reports a role from the fence's OPENING line) but `extract.sh block`
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
    stripped="$(printf '%s' "$body" | tr -d '[:space:]')"
    if [ -z "$stripped" ]; then
      report "L8: step $s: role '$r' is empty or whitespace-only"
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
