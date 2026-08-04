#!/usr/bin/env bash
# provisioning-check.sh — report THIS MACHINE's provisioning state.
#
# Every other check this change specifies is per-repository: contract markers,
# byte-identity, the override scan. None of them can see whether the machine
# holds the implementations the shims resolve. This one answers that, and it
# answers it about the machine, not about any repository (task 3.6).
#
# USAGE
#   provisioning-check.sh [--dest DIR] [--source-check DIR]
#                         [--no-source-check] [--strict]
#
#     --dest              shared bin directory (default: $HOME/.agenticapps/bin)
#     --source-check DIR  compare each executed copy against the maintained file
#                         in the authority checkout DIR. This is the CURRENCY
#                         axis, and it is ON BY DEFAULT — the flag names an
#                         authority other than the one beside this script
#     --no-source-check   do not ask the currency question. The report says so;
#                         it does not read as a pass
#     --strict            exit 1 on any finding, on anything but `complete`, or
#                         on anything but `current`
#
# THE STATE IS A TRIPLE (design Decision 12, third axis added 2026-08-03)
#
# An earlier revision listed four flat states — unprovisioned / partially
# provisioned / provisioned / drifted — and round 9 showed the members overlap.
# A manifest whose files are all absent is both unprovisioned AND drifted; one
# unattested file beside one missing file is both partially provisioned AND
# drifted. "Exactly one of four" was false of the set as written.
#
# Three things were being conflated, and they vary independently:
#
#   completeness  none | partial | complete       how much is installed
#   integrity     attested | drifted              whether it matches what was installed
#   currency      current | stale | unknown       whether that is still what the
#                                                 authority holds
#
# The case that broke the flat list — everything deleted while the manifest
# still claims otherwise — is `none` + `drifted`, and it needs a different
# remedy from a clean fresh clone.
#
# WHY CURRENCY IS AN AXIS AND NOT A THIRD REPORT BLOCK
#
# The comparison it names already existed, as `--source-check`, and it worked.
# What it lacked was a VERDICT: it reported `DIFFERS` into a block of its own,
# the summary was computed without it, and so on 2026-08-03 this tool printed
#
#     SOURCE    database-sentinel  DIFFERS from the maintained implementation
#     SOURCE    normalize-claude-md  DIFFERS from the maintained implementation
#     COMPLETENESS  complete
#     INTEGRITY     attested
#     This machine is provisioned. The shims will resolve.
#
# on a machine running two implementations three landed fixes behind — one of
# which took CLAUDE.md to 0600 on every write, and one of which did not block
# `DELETE FROM public.users`. The check found it and the summary said provisioned
# anyway. An axis is what obliges the summary to agree with the comparison.
#
# `stale` and `drifted` stay distinct: `drifted` means a published file was
# edited or replaced and the answer is to investigate, `stale` most often means
# the machine did exactly what it was told and the world moved on. Merging them
# would train an operator to answer real tampering by re-running the installer.
#
# --STRICT CAN NOW FAIL WHERE IT PREVIOUSLY PASSED
#
# This is a behaviour change, not a reporting one. A CI job on a machine whose
# authority checkout lags, or which has no authority at all, newly exits 1.
# Recorded here rather than discovered: `unknown` fails --strict too, because an
# unchecked claim and a verified one must not exit the same.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# One semver implementation, extracted when a second tool needed it. Refusing
# rather than degrading is deliberate: without an ordering
# the direction of a staleness cannot be reported, and a currency report with no
# direction hands the operator the wrong remedy half the time.
if [ ! -f "$SCRIPT_DIR/lib/semver.sh" ]; then
  echo "provisioning-check: $SCRIPT_DIR/lib/semver.sh is missing." >&2
  echo "  Version direction cannot be computed without it, and a currency" >&2
  echo "  report with no direction names the wrong remedy. Refusing to report." >&2
  exit 65
fi
# shellcheck source=lib/semver.sh
. "$SCRIPT_DIR/lib/semver.sh"

DEST_DIR="$HOME/.agenticapps/bin"
STRICT=0

# The authority defaults to the tracked implementations beside this script.
#
# The same fixed-point argument the gate hook makes about its own path: this
# tool lives INSIDE core, so the authority it needs is a sibling of tools/ at
# the repository root — $SCRIPT_DIR/.. and then down, not "two levels up" — and
# the file's own location cannot be stale or wrong the way an environment
# variable or a working directory can. Defaulting this OFF is what made the
# fifteen hours possible — a run without the flag read exactly like a run where
# the stronger question was asked and answered.
#
# No --authority flag. The first draft of this change proposed one; the plan
# review pointed out it would overlap --source-check with no conflict semantics
# defined, and --source-check is the flag that already exists.
AUTHORITY="$ROOT/reference-implementations/project-hooks"
AUTHORITY_MODE=default       # default | explicit | off

need() { [ $# -ge 2 ] || { echo "provisioning-check: $1 needs a value" >&2; exit 64; }; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)         need "$@"; DEST_DIR="$2"; shift 2 ;;
    --dest=*)       DEST_DIR="${1#*=}"; shift ;;
    --source-check) need "$@"; AUTHORITY="$2"; want_auth=1; shift 2 ;;
    --source-check=*) AUTHORITY="${1#*=}"; want_auth=1; shift ;;
    --no-source-check) want_off=1; shift ;;
    --strict)       STRICT=1; shift ;;
    -h|--help)      sed -n '1,25p' "$0"; exit 0 ;;
    *) echo "provisioning-check: unknown option: $1" >&2; exit 64 ;;
  esac
done

# Naming an authority and refusing to consult one are contradictory
# instructions, and last-one-wins would silently do the opposite of what half
# of a scripted invocation asked for. Refuse rather than pick.
if [ "${want_auth:-0}" = 1 ] && [ "${want_off:-0}" = 1 ]; then
  echo "provisioning-check: --source-check and --no-source-check contradict each other." >&2
  echo "  One names an authority to compare against; the other declines to compare." >&2
  echo "  Pass exactly one." >&2
  exit 64
fi
[ "${want_auth:-0}" = 1 ] && AUTHORITY_MODE=explicit
[ "${want_off:-0}"  = 1 ] && AUTHORITY_MODE=off

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
DECL="${PROJECT_HOOKS_ARTIFACTS:-$ROOT/reference-implementations/project-hooks/ARTIFACTS}"
# ARTIFACT_DECL is the DECLARATION alone, and currency judges nothing else.
#
# NAMES below is the declaration unioned with the manifest and the disk, which
# is right for completeness and integrity. It is wrong for currency: a manifest
# row written by a different installer would make its artifact "declared", and
# the authority was never expected to hold it. An earlier revision of the delta
# made an absent authority file `stale` without this distinction, and running it
# flagged openspec-change-gate, reviewer-cli and run-plan-review — three
# artifacts the manifest check on the very next line reports as out of scope.
declare -a ARTIFACT_DECL=()
if [ -f "$DECL" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && { add_name "$line"; ARTIFACT_DECL+=("$line"); }
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

# Which artifacts drifted, by name. The currency block needs this: `drifted` and
# `stale` together is the one combination where re-running the installer is
# actively harmful, because it overwrites the evidence of the edit.
declare -a DRIFTED=()
mark_drifted() { DRIFTED+=("$1"); }
is_drifted() {
  for e in ${DRIFTED+"${DRIFTED[@]}"}; do [ "$e" = "$1" ] && return 0; done
  return 1
}

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
      drift=$((drift + 1)); findings=$((findings + 1)); mark_drifted "$n"
      continue
    fi

    if [ -z "$rh" ]; then
      # Task 3.2c-i: renamed into place before a crash, with no row yet. This is
      # the inconsistency the publication order deliberately chooses, and it is
      # neither absence nor a clean install.
      echo "MANIFEST  $n  unverifiable — present, but the manifest carries no row for it"
      drift=$((drift + 1)); findings=$((findings + 1)); mark_drifted "$n"
      continue
    fi

    ah="$(sha_of "$art")"
    if [ "$ah" != "$rh" ]; then
      # Covers the hand-edit, the replacement, and the interrupted upgrade —
      # new bytes against an old row. All three are drift. The remedy is to
      # investigate, NOT to re-install: see the currency block, where drifted +
      # stale is the combination in which re-running the installer would
      # overwrite the evidence of the edit.
      echo "MANIFEST  $n  drifted — on disk ${ah:0:12}…, manifest attests ${rh:0:12}… (v$rv)"
      drift=$((drift + 1)); findings=$((findings + 1)); mark_drifted "$n"
    else
      echo "MANIFEST  $n  attested v$rv"
    fi
  done
fi

# ── the write surface ───────────────────────────────────────────────────────
# Stage-2 finding 2. The installer sets ownership and modes; until this loop
# existed, nothing checked them afterwards, so a `chmod g+w` performed a minute
# after a clean install still reported complete + attested.
#
# This is the mitigation the capability trades the concentration point for.
# Every project execs whatever is in this directory, so anyone who can write one
# of these files runs code at the tool boundary in all of them. Ownership and
# the write bits are the cheap part of that bargain, and they are only worth
# anything if something looks.
#
# Reported as its OWN dimension rather than folded into either axis.
# `integrity` is defined as "present artifacts match their rows"; a
# group-writable file whose digest matches is genuinely attested, and
# overloading the word would break a vocabulary the capability spent a review
# round separating. It counts toward --strict, which is where it bites.
#
# NOT a security boundary, and the disclaimer above still stands: a user who can
# write their own files can still change what every project enforces. This
# removes the cases where somebody ELSE can.
me=$(id -u)
write_surface() { # $1 = path, $2 = label
  local f="$1" label="$2" owner mode
  [ -e "$f" ] || return 0
  owner=$(stat -f '%u' "$f" 2>/dev/null || stat -c '%u' "$f" 2>/dev/null) || owner=""
  mode=$(stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f" 2>/dev/null) || mode=""

  if [ -n "$owner" ] && [ "$owner" != "$me" ]; then
    echo "WRITE-SURFACE  $label  owned by uid $owner, not by uid $me who runs the hooks — reported rather than executed silently"
    findings=$((findings + 1))
  fi
  # 022 = group-write | other-write. A group-writable shared directory makes
  # every member of that group an author of every hook in every project.
  if [ -n "$mode" ] && [ $(( 8#$mode & 8#022 )) -ne 0 ]; then
    echo "WRITE-SURFACE  $label  mode $mode is group- or world-writable — anyone who can write it changes what every project enforces"
    findings=$((findings + 1))
  fi
}

write_surface "$DEST_DIR" "$(basename "$DEST_DIR")"
for n in ${NAMES+"${NAMES[@]}"}; do
  write_surface "$DEST_DIR/$n.sh" "$n.sh"
done
# The manifest is covered by the same rules: a digest record an attacker can
# rewrite is the limitation this check already admits, and leaving its mode
# unchecked widens it for no reason.
write_surface "$MANIFEST" "$(basename "$MANIFEST")"

# ── currency: the third axis ────────────────────────────────────────────────
# The manifest check asks "does the executed copy match what was published".
# This asks the stronger question — "is what was published still what the
# authority holds" — and it is the question the manifest structurally cannot
# answer, because a row records a publication that already happened. A machine
# can be perfectly attested against a manifest that published last month's
# implementation.
#
# BYTES DECIDE, MARKERS SPEAK.
#
# The verdict is byte-identity, never the version marker. A file whose bytes
# differ while its marker matches is exactly the case a version-only comparison
# cannot see, and it is the case this fleet already caught once for shims, where
# a marker attested a string about the file rather than the file. The markers
# supply the message: direction, both versions, and the remedy chosen for that
# condition.
#
# THE AUTHORITY IS A CHECKOUT, AND `current` SAYS SO.
#
# This reads files. It cannot know what a branch elsewhere contains, so an
# authority checkout that is itself behind agrees with an equally behind install
# and the pair reports `current` — the check being right about the disk rather
# than wrong about the world. That limit is printed with the verdict rather than
# left for a reader to deduce; an unqualified `current` would recreate, one level
# up, the false green this axis exists to remove. `git show <ref>:<path>` is how
# to ask the branch question, and is what the fleet's contract propagation used.

cur_stale=0
cur_unknown=0

# The version an implementation declares about itself, read from its own first
# lines — the same shape, the same regex AND the same 10-line window the
# installer uses to write the row. The window is shared deliberately: a file
# whose marker sits below line 10 cannot be published at all (the installer
# refuses it as unmarked), so the published side can never have one this misses.
# An AUTHORITY file could, and the message then says the version could not be
# read — which is honest, if not the whole story.
marker_of() { # $1 = file, $2 = artifact name
  head -10 "$1" 2>/dev/null \
    | grep -m1 -oE "^#[[:space:]]*$2-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
}

echo
if [ "$AUTHORITY_MODE" = off ]; then
  cur_unknown=1
  echo "CURRENCY  not asked — --no-source-check was given, so no published copy was"
  echo "          compared against any authority. The question that went unanswered"
  echo "          is whether what is installed is still what the authority holds."
elif [ "${#ARTIFACT_DECL[@]}" -eq 0 ]; then
  cur_unknown=1
  echo "CURRENCY  unknown — no artifact declaration at $DECL, so nothing is declared"
  echo "          and currency has nothing to judge."
elif [ ! -d "$AUTHORITY" ]; then
  cur_unknown=1
  echo "CURRENCY  unknown — no authority checkout at $AUTHORITY"
  if [ "$AUTHORITY_MODE" = default ]; then
    echo "          This tool resolves its authority from its own location, so this"
    echo "          normally means it was copied out of core. Pass --source-check DIR."
  fi
else
  # Is this an authority checkout at all? A directory holding none of the
  # declared artifacts is not one, and reporting every artifact stale against it
  # would be confidently wrong — an unasked question dressed as a finding.
  auth_seen=0
  for n in "${ARTIFACT_DECL[@]}"; do
    [ -f "$AUTHORITY/$n.sh" ] && auth_seen=1
  done
  if [ "$auth_seen" -eq 0 ]; then
    cur_unknown=1
    echo "CURRENCY  unknown — $AUTHORITY holds none of the declared artifacts, so it"
    echo "          is not an authority checkout. Nothing is reported stale against it."
  else
    for n in "${ARTIFACT_DECL[@]}"; do
      art="$DEST_DIR/$n.sh"
      src="$AUTHORITY/$n.sh"
      # An artifact that is not installed is completeness's business, not this
      # axis's. Currency judges what is present.
      [ -f "$art" ] || continue

      if [ ! -f "$src" ]; then
        # A finding, not an inability to check: the authority was reached and
        # holds the others, so "this one is not in it" is something known.
        cur_stale=1
        echo "CURRENCY  $n  stale — this authority checkout holds no file for a declared artifact"
        echo "          Remedy: check out the authority at a commit that has it, or reconcile ARTIFACTS."
        continue
      fi
      if [ ! -r "$src" ] || [ ! -r "$art" ]; then
        # A failed read is not a difference.
        cur_unknown=1
        echo "CURRENCY  $n  unknown — a file could not be read, so no comparison was made"
        echo "          Unreadable: $([ -r "$src" ] || printf '%s ' "$src")$([ -r "$art" ] || printf '%s' "$art")"
        continue
      fi
      # cmp exits 1 for "they differ" and 2 for "I could not compare them".
      # Collapsing the two would report an I/O error as a difference, which is
      # the same mistake one level down as reporting an unasked question as a
      # pass. The -r tests above catch the ordinary case; this catches a read
      # that fails after them.
      cmp -s "$art" "$src"; cmp_rc=$?
      if [ "$cmp_rc" -eq 0 ]; then
        echo "CURRENCY  $n  current — byte-identical to this authority checkout"
        continue
      fi
      if [ "$cmp_rc" -gt 1 ]; then
        cur_unknown=1
        echo "CURRENCY  $n  unknown — the comparison itself failed (cmp exit $cmp_rc), which is"
        echo "          not evidence of a difference. Re-run; if it persists, investigate the filesystem."
        continue
      fi

      cur_stale=1
      pv="$(marker_of "$art" "$n")"
      av="$(marker_of "$src" "$n")"
      remedy="Remedy: re-run install-project-hooks.sh."
      if [ -z "$pv" ] || [ -z "$av" ]; then
        # Say the version could not be read rather than inventing one. The
        # verdict still stands: it was decided on bytes.
        if   [ -z "$pv" ] && [ -z "$av" ]; then side="neither side"
        elif [ -z "$pv" ];                 then side="the published copy"
        else                                    side="this authority checkout"
        fi
        echo "CURRENCY  $n  stale — the bytes differ; the version could not be read on $side"
        remedy="Remedy: investigate — an implementation with no readable marker was not published by this installer."
      else
        case "$(semver_cmp "$pv" "$av")" in
          -1) echo "CURRENCY  $n  stale — published $pv, this authority checkout holds $av (behind)" ;;
           1) echo "CURRENCY  $n  stale — published $pv, this authority checkout holds $av (ahead)"
              remedy="Remedy: NOT the installer — it refuses downgrades. Update this checkout, or investigate a build published from a tree nobody has." ;;
           0) echo "CURRENCY  $n  stale — the versions agree at $pv while the bytes differ"
              remedy="Remedy: investigate — a build error or a hand-edit, not a lag." ;;
        esac
      fi
      # drifted AND stale. The one combination where the installer is actively
      # harmful advice: it overwrites the very bytes that evidence the edit.
      if is_drifted "$n"; then
        remedy="Remedy: drifted AND stale — investigate first. Re-installing overwrites the evidence of the edit."
      fi
      echo "          $remedy"
    done
  fi
fi

# Aggregation. `stale` outranks `unknown` because a known finding outranks an
# unasked question.
if   [ "$cur_stale"   -ne 0 ]; then currency=stale
elif [ "$cur_unknown" -ne 0 ]; then currency=unknown
else                                currency=current
fi

# ── the triple ──────────────────────────────────────────────────────────────
total=$((present + absent))
if   [ "$present" -eq 0 ];      then completeness=none
elif [ "$absent"  -eq 0 ];      then completeness=complete
else                                 completeness=partial
fi
[ "$drift" -eq 0 ] && integrity=attested || integrity=drifted

echo
echo "COMPLETENESS  $completeness   ($present of $total expected artifact(s) present)"
echo "INTEGRITY     $integrity"
case "$currency" in
  current) echo "CURRENCY      current   (matches this authority checkout — not necessarily what core ships)" ;;
  stale)   echo "CURRENCY      stale     (each finding above names the remedy chosen for its condition)" ;;
  unknown) echo "CURRENCY      unknown   (the currency question was not answered)" ;;
esac

# The licence to describe the fleet's protections as running as documented
# requires all three. It previously attached to `attested` alone, and that was
# observed to be false for fifteen hours on this machine.
if [ "$completeness" = complete ] && [ "$integrity" = attested ] && [ "$currency" = current ]; then
  echo "This machine is provisioned against this authority checkout. The shims will"
  echo "resolve, and what they resolve is byte-identical to $AUTHORITY as it"
  echo "stands on disk right now."
elif [ "$completeness" = complete ] && [ "$integrity" = attested ] && [ "$currency" = unknown ]; then
  # Deliberately NOT the provisioned line and deliberately NOT the alarming one.
  # An unchecked claim and a verified one must not read the same, and neither
  # must an unchecked claim and a failed one.
  echo "This machine is complete and attested, and is NOT reported provisioned: the"
  echo "currency question — is what is installed still what the authority holds —"
  echo "went unanswered. An unchecked claim and a verified one must not read alike."
elif [ "$completeness" = complete ] && [ "$integrity" = attested ]; then
  # Stale and nothing else. Saying "shims that cannot resolve" here would be
  # false: they resolve, and what they resolve is an old build. The loss is
  # silent rather than absent, which is the harder failure to notice and the
  # reason this axis exists.
  echo "This machine is NOT reported provisioned. Every shim resolves — and what"
  echo "it resolves is not what this authority checkout holds, so a fix the fleet"
  echo "believes is running may not be. Each finding above names the remedy chosen"
  echo "for its condition; there is no single one that is right for all of them."
else
  echo "This machine is NOT fully provisioned. Shims that cannot resolve will"
  echo "report and ALLOW — they do not block — so the protection is absent"
  echo "rather than the repository being unusable. Each finding above names its"
  echo "own remedy; there is no single one that is right for all of them."
fi

# --strict. Currency counts, including `unknown`: a CI job that cannot see an
# authority has not verified currency, and exiting 0 on that is the failure this
# whole change is about, one level up.
[ "$STRICT" -eq 1 ] && [ "$findings" -gt 0 ] && exit 1
[ "$STRICT" -eq 1 ] && [ "$completeness" != complete ] && exit 1
[ "$STRICT" -eq 1 ] && [ "$currency" != current ] && exit 1
exit 0
