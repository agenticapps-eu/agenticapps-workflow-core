#!/usr/bin/env bash
# conformance-harness-reporting.test.sh — asserts core's conformance harnesses
# report honestly about targets they cannot score.
#
# This is a TEST, not a conformance harness. Conformance harnesses score HOST
# implementations of the gate, the producer and the reviewer wrapper; this
# scores core's own tools against the `conformance-harness-reporting`
# capability. Named per the `drift-report.test.sh` precedent.
#
# THE DEFECT IT PINS
#
#   $ bash tools/change-gate-conformance.sh /nonexistent/gate.sh
#     SKIP  /nonexistent/gate.sh (not found)
#   ═══ TOTAL: 0 passed, 0 failed, 0 inconclusive
#   $ echo $?
#   0
#
# A measurement tool that returns "pass" having measured nothing is the exact
# failure it exists to prevent.
#
# WHY MOST ROWS ASSERT ON OUTPUT, NOT JUST THE EXIT CODE
#
# For several inputs the exit code is non-zero *for the wrong reason*, and a
# row that checked only the code would score green against unfixed tooling:
#
#   * an EMPTY target exits 0 on every invocation, so it passes every `expect 0`
#     row and fails every `expect 2` row — a non-zero tally produced by a file
#     containing no code
#   * an UNREADABLE target makes the shell exit 126, so every row fails — the
#     run is red, but the operator is told the gate is broken when the fault is
#     a file mode
#   * a fully-absent ROSTER currently reports a usage error, which is non-zero
#     while telling the operator their command line was wrong rather than that
#     their fleet is missing
#
# So rows assert the REASON wherever the exit code cannot distinguish the fixed
# behaviour from the broken one.
#
# COST
#
# Scoring one real gate takes ~35s, so rows are built to terminate before any
# fixture is constructed wherever the point can be made that way. The two rows
# that genuinely need a full scoring run are marked SLOW and skipped unless
# HARNESS_TEST_SLOW=1.
#
# Usage: tools/conformance-harness-reporting.test.sh [harness-name-substring]

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTER="${1:-}"

pass=0 fail=0 skip=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── the harnesses, with their shape ──────────────────────────────────────────
# M = multi-target (tally, continues past a bad target)
# S = single-target (aborts on a bad target)
#
# resolve-core-artifact-conformance.sh was removed on 2026-08-12 with the
# artifact it scored. resolve-core-artifact.sh existed so that a HOST repo's
# install.sh could publish core's artifacts from a pin instead of vendoring
# their bytes; all four host repositories were deleted the same day, and core's
# own install.sh has never used it — it publishes through
# install-shared-artifact.sh directly.
HARNESSES="
change-gate-conformance.sh:M:roster
run-plan-review-conformance.sh:M:norost
reviewer-cli-conformance.sh:M:roster
shared-install-conformance.sh:S:norost
installer-prereq-conformance.sh:S:norost
"

ok()   { echo "  PASS  $1"; pass=$((pass + 1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail + 1)); [ -n "${2:-}" ] && echo "        $2"; }
note() { echo "  SKIP  $1"; skip=$((skip + 1)); }

# Runs a harness and captures exit code + combined output.
# Sets: RC, OUT
run_harness() { # $1 = harness path, rest = args
  local h="$1"; shift
  OUT="$(timeout 120 bash "$h" "$@" 2>&1)"
  RC=$?
}

# ── row helpers ──────────────────────────────────────────────────────────────

# The load-bearing assertion: a harness must never exit 0 on a target it did
# not score.
row_nonzero() { # $1 = desc, $2 = harness, rest = args
  local desc="$1" h="$2"; shift 2
  run_harness "$h" "$@"
  if [ "$RC" -ne 0 ]; then ok "$desc"
  else bad "$desc" "exited 0; output: $(printf '%s' "$OUT" | tr '\n' '|' | cut -c1-160)"; fi
}

# Non-zero AND the output explains WHY the target could not be scored. Used
# where a broken harness is also non-zero, for a different reason.
row_reason() { # $1 = desc, $2 = harness, $3 = extended regex the output must match, rest = args
  local desc="$1" h="$2" want="$3"; shift 3
  run_harness "$h" "$@"
  if [ "$RC" -eq 0 ]; then
    bad "$desc" "exited 0"
  elif printf '%s' "$OUT" | grep -qiE "$want"; then
    ok "$desc"
  else
    bad "$desc" "non-zero but no reason matching /$want/; got: $(printf '%s' "$OUT" | tr '\n' '|' | cut -c1-160)"
  fi
}

# Output must match a pattern, whatever the exit code.
row_output() { # $1 = desc, $2 = harness, $3 = regex, rest = args
  local desc="$1" h="$2" want="$3"; shift 3
  run_harness "$h" "$@"
  if printf '%s' "$OUT" | grep -qiE "$want"; then ok "$desc"
  else bad "$desc" "no match for /$want/; got: $(printf '%s' "$OUT" | tr '\n' '|' | cut -c1-200)"; fi
}

# Output must NOT match — used where a wrong-but-plausible path produces the
# right exit code.
row_output_lacks() { # $1 = desc, $2 = harness, $3 = regex, rest = args
  local desc="$1" h="$2" bad_re="$3"; shift 3
  run_harness "$h" "$@"
  if printf '%s' "$OUT" | grep -qiE "$bad_re"; then
    bad "$desc" "matched forbidden /$bad_re/: $(printf '%s' "$OUT" | tr '\n' '|' | cut -c1-200)"
  else ok "$desc"; fi
}

# ── fixtures ─────────────────────────────────────────────────────────────────
# Fixture names are deliberately NEUTRAL — t1, t2, t3 rather than empty.sh,
# a-directory, unreadable.sh.
#
# The first run of this test scored rows B, C and D green against unfixed
# harnesses. Every harness echoes the target path, so a fixture called
# `empty.sh` satisfies a /empty/ reason-check by having been named, and
# `a-directory` satisfies /directory/, and `unreadable.sh` satisfies
# /unreadable/. Three rows asserting that the tool EXPLAINS itself were in fact
# asserting that the operator had named the file helpfully.
#
# With neutral names the only way to match a reason is for the harness to say
# it. This is the failure mode the rows exist to catch, found in the rows
# themselves.
mkfix() {
  MISSING="$WORK/absent/t0"                    # never created
  EMPTY="$WORK/t1";            : > "$EMPTY"
  DIRTGT="$WORK/t2";           mkdir -p "$DIRTGT"
  UNREADABLE="$WORK/t3"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$UNREADABLE"; chmod 000 "$UNREADABLE"
  BROKENLINK="$WORK/t4"
  ln -sf "$WORK/absent/nothing-here" "$BROKENLINK"
}
mkfix

# Root defeats the readability check: `test -r` is true for root and the shell
# reads the file regardless of mode. Detect rather than assert a falsehood.
IS_ROOT=0
[ -r "$UNREADABLE" ] && IS_ROOT=1

# ── per-harness rows ─────────────────────────────────────────────────────────
for entry in $HARNESSES; do
  name="${entry%%:*}"; rest="${entry#*:}"
  shape="${rest%%:*}"; roster="${rest#*:}"
  H="$HERE/$name"

  [ -n "$FILTER" ] && case "$name" in *"$FILTER"*) ;; *) continue ;; esac
  [ -f "$H" ] || { note "$name — harness itself not found"; continue; }

  echo
  echo "═══ $name  (shape=$shape roster=$roster)"

  # A. a named target that does not exist
  row_nonzero "A. missing target -> non-zero" "$H" "$MISSING"

  # B-E assert a STRUCTURED MARKER, not free prose:
  #
  #     UNSCOREABLE  <label> — <reason>
  #
  # with <reason> one of `not a regular file`, `empty`, `unreadable`.
  #
  # Free-prose matching does not work here and the first two runs of this test
  # proved it twice. /empty/ is satisfied by change-gate's own row description
  # "empty stdin -> allow (fail-open)"; /permission/ is satisfied by the shell's
  # own "Permission denied" when it refuses an unreadable file. Both made rows
  # green against harnesses that say nothing about the target at all.
  #
  # A marker no current output can emit is the only assertion that distinguishes
  # "the harness explained itself" from "some word happened to appear".

  # B. a named target that is empty. The exit code alone is NOT discriminating:
  #    an empty script exits 0, passing every `expect 0` row and failing every
  #    `expect 2` row, so the tally goes non-zero for the wrong reason.
  row_reason "B. empty target -> UNSCOREABLE, reason empty" \
    "$H" 'UNSCOREABLE.*empty' "$EMPTY"

  # C. a named target that is a directory. `[ -s ]` is true for one.
  row_reason "C. directory target -> UNSCOREABLE, reason not-a-regular-file" \
    "$H" 'UNSCOREABLE.*not a regular file' "$DIRTGT"

  # D. a named target that is unreadable. Not a false-green risk — the shell
  #    refuses it with 126 and rows fail loudly — but an illegible one: the
  #    operator is shown row failures when the fault is a file mode.
  if [ "$IS_ROOT" = "1" ]; then
    note "D. unreadable target — running as root, test -r cannot fail (specified)"
  else
    row_reason "D. unreadable target -> UNSCOREABLE, reason unreadable" \
      "$H" 'UNSCOREABLE.*unreadable' "$UNREADABLE"
  fi

  # E. overlapping conditions: a broken symlink is non-regular, empty AND
  #    unreadable at once. Precedence is regular -> empty -> unreadable.
  row_reason "E. broken symlink -> UNSCOREABLE, not-a-regular-file wins" \
    "$H" 'UNSCOREABLE.*not a regular file' "$BROKENLINK"

  # F. a target path carrying a newline must not be able to forge a PASS line.
  FORGED="$WORK/$(printf 't5\n  PASS  forged row')"
  row_output_lacks "F. newline in a path cannot forge a PASS line" \
    "$H" '^  PASS  forged row' "$FORGED"

  # G. multi-target only: one bad target must not deny the caller the others.
  if [ "$shape" = "M" ]; then
    if [ "${HARNESS_TEST_SLOW:-0}" = "1" ]; then
      row_nonzero "G. SLOW three targets, middle absent -> non-zero" \
        "$H" "$MISSING" "$MISSING" "$MISSING"
    else
      note "G. three-target row (set HARNESS_TEST_SLOW=1)"
    fi
  fi

  # ── roster rows ────────────────────────────────────────────────────────────
  if [ "$roster" = "roster" ]; then
    # H. a roster flag plus an explicit path must be a usage error, not a
    #    silent discard of the path.
    row_reason "H. roster flag + explicit path -> usage error" \
      "$H" 'usage|cannot be combined|both' --family "$EMPTY"

    # I. a fully-absent roster must still print coverage, and must NOT be
    #    reported as the operator having mistyped the command.
    #    Relocate the harness so its FAMILY root resolves into an empty tree
    #    and HOME has no ~/.agenticapps.
    FAKE="$WORK/fake-$name"
    mkdir -p "$FAKE/root/tools" "$FAKE/home"
    cp "$H" "$FAKE/root/tools/$name"
    OUT="$(cd "$FAKE" && HOME="$FAKE/home" timeout 120 bash "$FAKE/root/tools/$name" --family 2>&1)"
    RC=$?
    if printf '%s' "$OUT" | grep -qiE 'scored 0 of [0-9]+'; then
      ok "I. whole roster absent -> coverage line printed"
    else
      bad "I. whole roster absent -> coverage line printed" \
        "got: $(printf '%s' "$OUT" | tr '\n' '|' | cut -c1-160)"
    fi
    if printf '%s' "$OUT" | grep -qiE '^usage:'; then
      bad "I2. whole roster absent -> NOT reported as a usage error" \
        "reported a usage error instead of missing hosts"
    else
      ok "I2. whole roster absent -> NOT reported as a usage error"
    fi

    # J. coverage must be declared on EVERY roster run, including complete
    #    ones — a line that appears only when something is wrong becomes the
    #    signal, and its absence then has to be noticed to mean anything.
    if [ "${HARNESS_TEST_SLOW:-0}" = "1" ]; then
      row_output "J. SLOW real sweep declares coverage 'scored N of M'" \
        "$H" 'scored [0-9]+ of [0-9]+' --family
      row_output_lacks "J2. SLOW roster output carries no absolute \$HOME path" \
        "$H" "$HOME/" --family
    else
      note "J. roster coverage rows (set HARNESS_TEST_SLOW=1) — needs a real sweep"
    fi

    # K. THE ROSTER IS A DECLARATION, so it is asserted literally rather than
    #    counted. `core` is this repo's working-tree reference implementation
    #    and `shared-install` the copy install.sh publishes; between them a
    #    sweep measures publish drift, which is the only thing left to measure
    #    since the four host repositories were deleted on 2026-08-12.
    #
    #    Asserted against the SOURCE, not a run: a roster entry whose repo is
    #    absent produces no output naming it, so a run cannot distinguish "not
    #    declared" from "declared and missing" — which is the whole defect this
    #    file exists to pin, met one level up. Adding an entry must therefore
    #    fail here and be added here deliberately.
    declared="$(sed -n '/^ *ROSTER="/,/"$/p' "$H" |
                sed 's/^ *ROSTER="//' |
                grep -oE '^[a-z][a-z0-9-]*\|' | tr -d '|' | sort | tr '\n' ' ')"
    if [ "$declared" = "core shared-install " ]; then
      ok "K. roster declares exactly core + shared-install"
    else
      bad "K. roster declares exactly core + shared-install" \
        "declares: ${declared:-<nothing parsed>}"
    fi
  fi

  # L. --resolve went with the pin-and-resolve branch it drove. It fetched an
  #    artifact from a host's pinned commit and executed it; with no host
  #    repository left, it can only ever resolve nothing. Asserted as a usage
  #    error rather than as absent output, because a flag that is silently
  #    ignored looks identical to one that ran and found nothing.
  if [ "$name" = "change-gate-conformance.sh" ]; then
    row_reason "L. --resolve is rejected, not silently ignored" \
      "$H" 'usage|unknown|unrecognized' --family --resolve
  fi
done

echo
echo "═══ TOTAL: $pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ] && [ $((pass + fail)) -gt 0 ]
