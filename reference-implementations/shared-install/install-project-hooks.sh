#!/usr/bin/env bash
# install-project-hooks.sh — publish every project-hook implementation in one
# invocation, and attest what was published.
#
# install-project-hooks-version: 1.0.0
#
# WHY THIS EXISTS
#
# install-shared-artifact.sh publishes ONE artifact per call. Project hooks come
# in a set, and "run the installer" has to mean the whole set is provisioned —
# otherwise a machine ends up holding one implementation and shimming two, which
# is the partially-provisioned state nobody set out to create.
#
# It also exists because the shims fail OPEN. Once an unresolvable shim allows
# the tool call, nothing at the tool boundary guarantees the protection is
# present; the guarantee moves here, to a step that verifies before it publishes
# and refuses loudly when it cannot.
#
# USAGE
#   install-project-hooks.sh [--source DIR] [--dest DIR] [--artifacts a,b,...]
#
#     --source     directory holding the implementations
#                  (default: ../project-hooks relative to this script)
#     --dest       shared bin directory (default: $HOME/.agenticapps/bin)
#     --artifacts  comma- or space-separated hook names to publish
#                  (default: every *.sh in --source except shim-template.sh)
#
# EXIT
#   0  every named artifact is published and attested
#   1  a source is missing or not executable, a lock timed out, or a write failed
#  64  bad usage
#
# THE ALGORITHM, ONCE PER RUN (design Decision 12, task 3.2e)
#
#   lock -> read manifest -> rename EVERY artifact into place
#        -> rewrite the manifest IN FULL, once -> unlock
#
# A manifest written once per run and a row published per artifact cannot both
# hold; this is the former. Multi-file atomicity is not on offer — two rename(2)
# calls are two operations and do not compose into a transaction (task 3.2b) —
# so the achievable guarantee is implemented instead and the reachable
# inconsistency is CHOSEN:
#
#   Artifacts are renamed into place BEFORE the manifest row naming them. So a
#   crash leaves "present but unattested", never "attested but absent". That
#   direction is deliberate: an unverifiable-but-working hook degrades to a
#   warning, whereas a row pointing at nothing reports a failure the operator
#   cannot act on.
#
# WHAT THE MANIFEST IS, AND IS NOT (task 3.2a-iii)
#
# It is DRIFT DETECTION, not tamper-proofing. It is unsigned and it sits beside
# the artifacts under the same ownership, so anyone who can alter an
# implementation can alter its row. It catches the hand-edit, the half-finished
# upgrade and the stale copy. It does not catch an adversary, and nothing here
# should be described as though it does.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/../project-hooks" 2>/dev/null && pwd || printf '%s' "$SCRIPT_DIR/../project-hooks")"
DEST_DIR="$HOME/.agenticapps/bin"
ARTIFACTS=""

# TEST ONLY. Deterministic interruption points, so the crash cases can be
# exercised rather than hoped for. Same precedent as
# install-shared-artifact.sh's SHARED_INSTALL_TEST_DELAY. Must never be set in
# production; a correct implementation's INVARIANTS hold at either point, which
# is exactly what the suite asserts.
TEST_ABORT_AFTER="${INSTALL_PROJECT_HOOKS_TEST_ABORT_AFTER:-0}"
TEST_ABORT_BEFORE_MANIFEST="${INSTALL_PROJECT_HOOKS_TEST_ABORT_BEFORE_MANIFEST:-0}"

while [ $# -gt 0 ]; do
  case "$1" in
    --source)    [ $# -ge 2 ] || { echo "install-project-hooks: --source needs a value" >&2; exit 64; }; SOURCE_DIR="$2"; shift 2 ;;
    --source=*)  SOURCE_DIR="${1#*=}"; shift ;;
    --dest)      [ $# -ge 2 ] || { echo "install-project-hooks: --dest needs a value" >&2; exit 64; }; DEST_DIR="$2"; shift 2 ;;
    --dest=*)    DEST_DIR="${1#*=}"; shift ;;
    --artifacts) [ $# -ge 2 ] || { echo "install-project-hooks: --artifacts needs a value" >&2; exit 64; }; ARTIFACTS="$2"; shift 2 ;;
    --artifacts=*) ARTIFACTS="${1#*=}"; shift ;;
    -h|--help)   sed -n '1,40p' "$0"; exit 0 ;;
    *) echo "install-project-hooks: unknown option: $1" >&2; exit 64 ;;
  esac
done

MANIFEST="$(dirname "$DEST_DIR")/manifest.tsv"
LOCKDIR="$(dirname "$DEST_DIR")/manifest.lock"
LOCK_TIMEOUT="${INSTALL_PROJECT_HOOKS_LOCK_TIMEOUT:-30}"

die()  { printf 'install-project-hooks: %s\n' "$*" >&2; exit 1; }
note() { printf 'install-project-hooks: %s\n' "$*" >&2; }

# ── discover what to publish ────────────────────────────────────────────────
[ -d "$SOURCE_DIR" ] || die "source directory not found: $SOURCE_DIR"

if [ -z "$ARTIFACTS" ]; then
  # DECLARED, never discovered. Globbing *.sh here made the expected set a
  # function of what was present, so a missing implementation published a
  # smaller set and exited 0 — the failure this step exists to catch, made
  # undetectable by the way the set was computed. See ARTIFACTS' own header.
  decl="$SOURCE_DIR/ARTIFACTS"
  [ -f "$decl" ] || die "no artifact declaration at $decl — refusing to guess the expected set from what happens to be present"
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && ARTIFACTS="$ARTIFACTS $line"
  done < "$decl"
else
  ARTIFACTS="$(printf '%s' "$ARTIFACTS" | tr ',' ' ')"
fi
ARTIFACTS="$(printf '%s' "$ARTIFACTS" | tr -s ' ')"
[ -n "${ARTIFACTS// /}" ] || die "no artifacts to publish in $SOURCE_DIR"

# ── verify BEFORE publishing anything ───────────────────────────────────────
# The whole set is checked first. Publishing half a set and then reporting the
# failure would leave the machine in the partially-provisioned state this step
# exists to prevent, and would do it while reporting an error — the worst
# combination.
#
# This is where the guarantee lives now that the shims fail open (task 3.2).
errors=0
for a in $ARTIFACTS; do
  src="$SOURCE_DIR/$a.sh"
  if [ ! -f "$src" ]; then
    note "MISSING  $a — no implementation at $src"
    errors=$((errors + 1)); continue
  fi
  if [ ! -x "$src" ]; then
    note "NOT EXECUTABLE  $a — $src is present but not executable"
    errors=$((errors + 1)); continue
  fi
  v="$(head -10 "$src" | grep -m1 -oE "^#[[:space:]]*$a-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  if [ -z "$v" ]; then
    note "NO VERSION MARKER  $a — expected '# $a-version: X.Y.Z' in the first 10 lines of $src"
    errors=$((errors + 1)); continue
  fi
done
[ "$errors" -eq 0 ] || die "$errors implementation(s) unfit to publish — nothing was written"

# ── the lock ────────────────────────────────────────────────────────────────
# One lock for the whole run, held across read-manifest -> publish -> rewrite.
# The critical section is a read-modify-write of a single shared file, so two
# concurrent runs would otherwise LOSE ROWS — a lost-update defect, which
# atomicity does not address.
#
# DEVIATION FROM TASK 3.2b-ii, RECORDED RATHER THAN TAKEN SILENTLY.
# That task names `flock` on a lockfile and forbids "create-and-check" by name,
# because a create-and-check lock outlives the process that made it and an
# installer killed mid-run would wedge every later run. flock(1) DOES NOT EXIST
# on macOS, which is this fleet's platform, so the named primitive is
# unavailable; install-shared-artifact.sh already records the same finding.
#
# The property the task is protecting is "a lock that does not outlive its
# holder", and that is what is implemented: an atomic mkdir plus the owning pid,
# and any lock whose owner is gone is broken rather than waited on. The failure
# mode the task excludes by name is excluded by behaviour instead, and the
# suite tests the behaviour, not the primitive.
LOCK_HELD=0
release_lock() { [ "$LOCK_HELD" -eq 1 ] && rm -rf "$LOCKDIR"; }
trap release_lock EXIT INT TERM

mkdir -p "$(dirname "$DEST_DIR")" 2>/dev/null || die "cannot create $(dirname "$DEST_DIR")"

waited=0
while ! mkdir "$LOCKDIR" 2>/dev/null; do
  lpid="$(cat "$LOCKDIR/pid" 2>/dev/null || true)"
  if [ -n "$lpid" ] && ! kill -0 "$lpid" 2>/dev/null; then
    note "breaking stale lock from dead pid $lpid"
    rm -rf "$LOCKDIR"
    continue
  fi
  waited=$((waited + 1))
  [ "$waited" -ge "$LOCK_TIMEOUT" ] && die "timed out after ${LOCK_TIMEOUT}s waiting for $LOCKDIR"
  sleep 1
done
LOCK_HELD=1
printf '%s' "$$" > "$LOCKDIR/pid" 2>/dev/null || true

# ── read the manifest ───────────────────────────────────────────────────────
# Rows for artifacts this run does not touch are carried through. Dropping them
# would make every partial run look like a fresh install of a smaller set.
declare -a KEEP=()
if [ -f "$MANIFEST" ]; then
  while IFS=$'\t' read -r p v h; do
    [ -n "${p:-}" ] || continue
    case " $ARTIFACTS " in *" $(basename "$p" .sh) "*) continue ;; esac
    KEEP+=("$p	$v	$h")
  done < "$MANIFEST"
fi

# ── publish ─────────────────────────────────────────────────────────────────
# 0700 on the directory, 0755 on the artifacts, and neither group- nor
# world-writable. This directory is an arbitrary-code-execution concentration
# point: seven projects exec whatever is in it, so anyone who can write here
# changes what all seven enforce (task 3.2a-v).
mkdir -p "$DEST_DIR" 2>/dev/null || die "cannot create $DEST_DIR"
chmod go-w "$DEST_DIR" 2>/dev/null || true

sha_of() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' | tr 'A-F' 'a-f'; }

declare -a ROWS=()
published=0
for a in $ARTIFACTS; do
  src="$SOURCE_DIR/$a.sh"
  dst="$DEST_DIR/$a.sh"
  v="$(head -10 "$src" | grep -m1 -oE "^#[[:space:]]*$a-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"

  # A symlink at the destination would make this write land wherever it points
  # — outside the directory whose permissions were just tightened, defeating
  # them entirely. rename(2) replaces the link itself rather than following it,
  # but only once nothing else has opened the path, so the link is removed
  # first and explicitly.
  [ -L "$dst" ] && rm -f "$dst"

  # Temp file in the SAME directory, then rename: rename(2) is atomic within a
  # filesystem, so a hook firing mid-install sees the old file or the new one,
  # never a truncated script. A temp file in /tmp would make this a cross-device
  # copy and lose the atomicity.
  tmp="$dst.tmp.$$"
  cp "$src" "$tmp"    || die "copy failed: $src -> $tmp"
  chmod 0755 "$tmp"   || die "chmod failed: $tmp"
  chmod go-w "$tmp"   2>/dev/null || true
  mv -f "$tmp" "$dst" || { rm -f "$tmp"; die "atomic rename failed: $tmp -> $dst"; }

  ROWS+=("$dst	$v	$(sha_of "$dst")")
  published=$((published + 1))
  note "published $a $v"

  # TEST ONLY — see the note at the top.
  if [ "$TEST_ABORT_AFTER" != "0" ] && [ "$published" -ge "$TEST_ABORT_AFTER" ]; then
    note "TEST ABORT after $published artifact(s), before the manifest rewrite"
    exit 1
  fi
done

# TEST ONLY. The interrupted-upgrade case: new bytes are in place, the manifest
# still holds the old rows.
if [ "$TEST_ABORT_BEFORE_MANIFEST" != "0" ]; then
  note "TEST ABORT before the manifest rewrite"
  exit 1
fi

# ── rewrite the manifest, in full, once ─────────────────────────────────────
# Never edited row-wise. Row-wise editing has its own torn-write window, and
# whole-file replacement makes the manifest's own update atomic even though it
# cannot be joined to the artifacts' (task 3.2b-i).
mtmp="$MANIFEST.tmp.$$"
: > "$mtmp" || die "cannot write $mtmp"
for r in ${KEEP+"${KEEP[@]}"};  do printf '%s\n' "$r" >> "$mtmp"; done
for r in ${ROWS+"${ROWS[@]}"};  do printf '%s\n' "$r" >> "$mtmp"; done
chmod 0644 "$mtmp" 2>/dev/null || true
chmod go-w "$mtmp" 2>/dev/null || true
mv -f "$mtmp" "$MANIFEST" || { rm -f "$mtmp"; die "atomic rename failed: $mtmp -> $MANIFEST"; }

note "published $published artifact(s) to $DEST_DIR; manifest at $MANIFEST"
exit 0
