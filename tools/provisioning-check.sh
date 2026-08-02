#!/usr/bin/env bash
# provisioning-check.sh — report THIS MACHINE's provisioning state.
#
# Every other check this change specifies is per-repository: contract markers,
# byte-identity, the override scan. None of them can see whether the machine
# holds the implementations the shims resolve. This one answers that, and it
# answers it about the machine, not about any repository (task 3.6).
#
# USAGE
#   provisioning-check.sh [--dest DIR] [--source-check DIR] [--strict]
#
#     --dest          shared bin directory (default: $HOME/.agenticapps/bin)
#     --source-check  additionally compare each executed copy against the
#                     maintained file in core (task 3.2a-ii)
#     --strict        exit 1 when the state is anything but complete + attested
#
# THE STATE IS A PAIR, NOT ONE OF FOUR (design Decision 12)
#
# An earlier revision listed four flat states — unprovisioned / partially
# provisioned / provisioned / drifted — and round 9 showed the members overlap.
# A manifest whose files are all absent is both unprovisioned AND drifted; one
# unattested file beside one missing file is both partially provisioned AND
# drifted. "Exactly one of four" was false of the set as written.
#
# Two things were being conflated, and they vary independently:
#
#   completeness  none | partial | complete    how much is installed
#   integrity     attested | drifted           whether what is installed attests
#
# The case that broke the flat list — everything deleted while the manifest
# still claims otherwise — is `none` + `drifted`, and it needs a different
# remedy from a clean fresh clone.
#
# EVERY STATE IS OBSERVED, NEVER INFERRED FROM HISTORY (task 3.2d-i)
#
# "The installer has never run" and "a publishing run completed" are not
# evaluable after the fact, and a history-based definition classifies a
# completed-then-hand-edited install as *provisioned* — the exact condition the
# manifest exists to detect. Nothing here reads a log or a timestamp; it reads
# the files.
#
# DRIFT DETECTION, NOT TAMPER-PROOFING (task 3.2a-iii)
#
# The manifest is unsigned and sits beside the artifacts under the same
# ownership. Anyone who can alter an implementation can alter its row. This
# catches hand-edits, half-finished upgrades and stale copies. It does not
# catch an adversary.

set -uo pipefail

DEST_DIR="$HOME/.agenticapps/bin"
SOURCE_CHECK=""
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)         DEST_DIR="$2"; shift 2 ;;
    --dest=*)       DEST_DIR="${1#*=}"; shift ;;
    --source-check) SOURCE_CHECK="$2"; shift 2 ;;
    --source-check=*) SOURCE_CHECK="${1#*=}"; shift ;;
    --strict)       STRICT=1; shift ;;
    -h|--help)      sed -n '1,20p' "$0"; exit 0 ;;
    *) echo "provisioning-check: unknown option: $1" >&2; exit 64 ;;
  esac
done

MANIFEST="$(dirname "$DEST_DIR")/manifest.tsv"

sha_of() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' | tr 'A-F' 'a-f'; }

# The set to judge against is the DECLARED set, unioned with what the manifest
# claims and what is on disk.
#
# The declaration has to lead. Judging only the union of manifest-and-disk made
# the expected set a function of what was found: a machine holding one of two
# implementations, with no row for the other, reported `complete` — because a
# smaller install was indistinguishable from a smaller expectation. The union
# still matters for the other direction, so that an artifact nobody expects but
# which is nonetheless installed does not go unreported.
declare -a NAMES=()
add_name() {
  local n="$1"
  for e in ${NAMES+"${NAMES[@]}"}; do [ "$e" = "$n" ] && return; done
  NAMES+=("$n")
}
DECL="${PROJECT_HOOKS_ARTIFACTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reference-implementations/project-hooks/ARTIFACTS}"
if [ -f "$DECL" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && add_name "$line"
  done < "$DECL"
else
  echo "provisioning-check: WARNING — no artifact declaration at $DECL." >&2
  echo "  Falling back to what is installed, which CANNOT detect a missing" >&2
  echo "  implementation: an absent artifact will read as a smaller install" >&2
  echo "  rather than an incomplete one." >&2
fi
if [ -f "$MANIFEST" ]; then
  while IFS=$'\t' read -r p v h; do
    [ -n "${p:-}" ] || continue
    add_name "$(basename "$p" .sh)"
  done < "$MANIFEST"
fi
declare -a DECLARED=(${NAMES+"${NAMES[@]}"})
is_declared() {
  for e in ${DECLARED+"${DECLARED[@]}"}; do [ "$e" = "$1" ] && return 0; done
  return 1
}

for f in "$DEST_DIR"/*.sh; do
  [ -e "$f" ] || continue
  add_name "$(basename "$f" .sh)"
done

row_for() { # $1 = artifact name -> "version<TAB>sha" or empty
  [ -f "$MANIFEST" ] || return 0
  awk -F'\t' -v n="$1" '
    { split($1, parts, "/"); base = parts[length(parts)]; sub(/\.sh$/, "", base)
      if (base == n) { print $2 "\t" $3; exit } }' "$MANIFEST"
}

present=0
absent=0
drift=0
findings=0

if [ "${#NAMES[@]}" -eq 0 ]; then
  echo "MANIFEST  (nothing installed and nothing claimed)"
else
  for n in "${NAMES[@]}"; do
    art="$DEST_DIR/$n.sh"
    row="$(row_for "$n")"

    # The shared bin directory is not this manifest's private property.
    # install-shared-artifact.sh publishes openspec-change-gate, reviewer-cli
    # and run-plan-review into the same place and writes no row here, so an
    # undeclared artifact is out of THIS manifest's scope, not evidence of
    # drift. Reporting it as drift called a healthy machine broken; omitting it
    # would hide a project-hook artifact nobody declared. So it is named,
    # scoped, and excluded from the verdict.
    if ! is_declared "$n"; then
      echo "MANIFEST  $n  not covered — published by another installer; outside this manifest's scope"
      continue
    fi
    rv="$(printf '%s' "$row" | cut -f1)"
    rh="$(printf '%s' "$row" | cut -f2)"

    if [ ! -f "$art" ]; then
      absent=$((absent + 1))
      if [ -n "$rh" ]; then
        # Claimed but gone. Not a clean uninstall, and not a fresh machine.
        echo "MANIFEST  $n  absent — the manifest attests $rv but no file is present"
        drift=$((drift + 1)); findings=$((findings + 1))
      else
        echo "MANIFEST  $n  absent — not installed and not claimed"
      fi
      continue
    fi

    present=$((present + 1))

    if [ ! -x "$art" ]; then
      echo "MANIFEST  $n  present but NOT EXECUTABLE — the shim cannot resolve it"
      drift=$((drift + 1)); findings=$((findings + 1))
      continue
    fi

    if [ -z "$rh" ]; then
      # Task 3.2c-i: renamed into place before a crash, with no row yet. This is
      # the inconsistency the publication order deliberately chooses, and it is
      # neither absence nor a clean install.
      echo "MANIFEST  $n  unverifiable — present, but the manifest carries no row for it"
      drift=$((drift + 1)); findings=$((findings + 1))
      continue
    fi

    ah="$(sha_of "$art")"
    if [ "$ah" != "$rh" ]; then
      # Covers the hand-edit, the replacement, and the interrupted upgrade —
      # new bytes against an old row. All three are drift, and the remedy for
      # all three is re-running the installer.
      echo "MANIFEST  $n  drifted — on disk ${ah:0:12}…, manifest attests ${rh:0:12}… (v$rv)"
      drift=$((drift + 1)); findings=$((findings + 1))
    else
      echo "MANIFEST  $n  attested v$rv"
    fi
  done
fi

# ── the source check, reported SEPARATELY ───────────────────────────────────
# Task 3.2a-ii. The manifest check asks "does the executed copy match what was
# published". The source check asks the stronger question "does it match what
# core maintains" — which requires core on this machine, so it is optional and
# must never be conflated with the weaker one. A machine can be perfectly
# attested against a manifest that published last month's implementation.
if [ -n "$SOURCE_CHECK" ]; then
  echo
  if [ ! -d "$SOURCE_CHECK" ]; then
    echo "SOURCE    skipped — $SOURCE_CHECK is not a directory"
  else
    for n in ${NAMES+"${NAMES[@]}"}; do
      art="$DEST_DIR/$n.sh"
      src="$SOURCE_CHECK/$n.sh"
      [ -f "$art" ] || continue
      if [ ! -f "$src" ]; then
        echo "SOURCE    $n  no maintained file at $src — cannot compare"
        continue
      fi
      if cmp -s "$art" "$src"; then
        echo "SOURCE    $n  matches the maintained implementation"
      else
        echo "SOURCE    $n  DIFFERS from the maintained implementation in $SOURCE_CHECK"
        findings=$((findings + 1))
      fi
    done
  fi
fi

# ── the pair ────────────────────────────────────────────────────────────────
total=$((present + absent))
if   [ "$present" -eq 0 ];      then completeness=none
elif [ "$absent"  -eq 0 ];      then completeness=complete
else                                 completeness=partial
fi
[ "$drift" -eq 0 ] && integrity=attested || integrity=drifted

echo
echo "COMPLETENESS  $completeness   ($present of $total expected artifact(s) present)"
echo "INTEGRITY     $integrity"

if [ "$completeness" = complete ] && [ "$integrity" = attested ]; then
  echo "This machine is provisioned. The shims will resolve."
else
  echo "This machine is NOT fully provisioned. Shims that cannot resolve will"
  echo "report and ALLOW — they do not block — so the protection is absent"
  echo "rather than the repository being unusable. Re-run install-project-hooks.sh."
fi

[ "$STRICT" -eq 1 ] && [ "$findings" -gt 0 ] && exit 1
[ "$STRICT" -eq 1 ] && [ "$completeness" != complete ] && exit 1
exit 0
