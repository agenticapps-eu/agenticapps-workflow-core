#!/usr/bin/env bash
# project-hook-provisioning.test.sh — multi-artifact publication and the
# per-machine provisioning check.
#
# Covers change tasks 3.2, 3.2a, 3.2a-v, 3.2b-ii, 3.2c, 3.2c-i, 3.2d-ii,
# 3.2e-i, 3.6 — all tdd="true".
#
# Everything runs against a temp HOME. The suite never reads or writes the real
# ~/.agenticapps.
#
# Usage: tools/project-hook-provisioning.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL="$ROOT/reference-implementations/shared-install/install-project-hooks.sh"
CHECK="$SCRIPT_DIR/provisioning-check.sh"
SRCDIR="$ROOT/reference-implementations/project-hooks"

pass=0
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; fail=$((fail + 1)); }
has()   { printf '%s' "$1" | grep -qiF -- "$2" && ok "$3" || bad "$3" "expected output to contain: $2" "got: $(printf '%s' "$1" | head -4)"; }
hasnt() { printf '%s' "$1" | grep -qiF -- "$2" && bad "$3" "expected output NOT to contain: $2" || ok "$3"; }

for t in "$INSTALL" "$CHECK"; do
  if [ ! -x "$t" ]; then
    echo "  FAIL  precondition: $t not found or not executable"
    echo "        Assertions below would pass vacuously. Refusing to run."
    exit 1
  fi
done

# A fresh, isolated machine. $1 = case name. Echoes the HOME.
mkhome() {
  local h="$TMP/$1"
  mkdir -p "$h/.agenticapps"
  printf '%s' "$h"
}
inst()  { local h="$1"; shift; env HOME="$h" "$INSTALL" --source "$SRCDIR" "$@" 2>&1; }
check() { local h="$1"; shift; env HOME="$h" "$CHECK" "$@" 2>&1; }

BIN=".agenticapps/bin"
MAN=".agenticapps/manifest.tsv"

echo "=== 3.2  the installer refuses a source that is absent or not executable ==="
# This verification is where the guarantee lives now that shims fail open.
H=$(mkhome missing-src)
mkdir -p "$TMP/badsrc"
cp "$SRCDIR/database-sentinel.sh" "$TMP/badsrc/"      # normalize-claude-md absent
cp "$SRCDIR/ARTIFACTS" "$TMP/badsrc/"                # …but still declared
OUT=$(env HOME="$H" "$INSTALL" --source "$TMP/badsrc" 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "absent implementation: installer exits non-zero" \
                || bad "absent implementation: installer exits non-zero" "got exit 0"
has "$OUT" "normalize-claude-md" "absent implementation: the report names the missing artifact"

H=$(mkhome nonexec-src)
mkdir -p "$TMP/nonexecsrc"
cp "$SRCDIR"/*.sh "$SRCDIR/ARTIFACTS" "$TMP/nonexecsrc/"
chmod 644 "$TMP/nonexecsrc/database-sentinel.sh"
OUT=$(env HOME="$H" "$INSTALL" --source "$TMP/nonexecsrc" 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "non-executable implementation: installer exits non-zero" \
                || bad "non-executable implementation: installer exits non-zero" "got exit 0"
has "$OUT" "database-sentinel" "non-executable implementation: the report names it"

echo
echo "=== 3.1 / 3.2a  one invocation provisions both, and writes a manifest ==="
H=$(mkhome happy)
OUT=$(inst "$H"); rc=$?
[ "$rc" -eq 0 ] && ok "a clean install exits 0" || bad "a clean install exits 0" "got $rc: $OUT"
for a in database-sentinel normalize-claude-md; do
  [ -x "$H/$BIN/$a.sh" ] && ok "one invocation published $a (present and executable)" \
                         || bad "one invocation published $a (present and executable)"
done
if [ -f "$H/$MAN" ]; then
  ok "a manifest was written beside the shared install directory"
  rows=$(grep -c $'\t' "$H/$MAN")
  [ "$rows" -eq 2 ] && ok "the manifest carries one row per artifact (2)" \
                    || bad "the manifest carries one row per artifact (2)" "got $rows"
  # path, version marker, sha256 lowercase hex
  if awk -F'\t' 'NF>=3 && $3 ~ /^[0-9a-f]{64}$/ {n++} END{exit !(n==2)}' "$H/$MAN"; then
    ok "each row carries path, version and a lowercase-hex sha256"
  else
    bad "each row carries path, version and a lowercase-hex sha256" "$(cat "$H/$MAN")"
  fi
  # Read the expected version from the implementation rather than hardcoding it.
  # A literal here asserts "the manifest says 1.0.0", which is a fact about a
  # release, not about the mechanism — it went red the first time an
  # implementation was legitimately bumped.
  want=$(grep -m1 -oE '^#[[:space:]]*database-sentinel-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' \
           "$SRCDIR/database-sentinel.sh" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  if [ -n "$want" ] && awk -F'\t' -v w="$want" '$1 ~ /database-sentinel\.sh$/ && $2 == w {n++} END{exit !(n==1)}' "$H/$MAN"; then
    ok "the row's version comes from the implementation's own marker ($want)"
  else
    bad "the row's version comes from the implementation's own marker" "wanted $want" "$(cat "$H/$MAN")"
  fi
else
  bad "a manifest was written beside the shared install directory"
fi

echo
echo "=== 3.6 / 3.2d  the per-machine check, computed observationally ==="
OUT=$(check "$H")
has "$OUT" "complete"  "a fully published machine reports completeness complete"
has "$OUT" "attested"  "a fully published machine reports integrity attested"

H2=$(mkhome nothing)
OUT=$(check "$H2")
has "$OUT" "none" "a machine with nothing installed reports completeness none"

# Partial: publish both, then delete one artifact AND its row, so the machine
# genuinely holds less rather than holding a lie.
H3=$(mkhome partial); inst "$H3" >/dev/null
rm -f "$H3/$BIN/normalize-claude-md.sh"
grep -v 'normalize-claude-md' "$H3/$MAN" > "$H3/$MAN.new" && mv "$H3/$MAN.new" "$H3/$MAN"
OUT=$(check "$H3")
has "$OUT" "partial" "one of two published reports completeness partial"

echo
echo "=== 3.2d-i / 3.2d-ii  drift is observed, never inferred from history ==="
# A completed install that was then hand-edited is the exact condition the
# manifest exists to detect, and the history-based definition called it
# 'provisioned'.
H=$(mkhome handedited); inst "$H" >/dev/null
printf '\n# tampered\n' >> "$H/$BIN/database-sentinel.sh"
OUT=$(check "$H")
has  "$OUT" "drifted"      "a hand-edited install reports integrity drifted"
hasnt "$OUT" "unprovision" "a hand-edited install is not reported unprovisioned"
has  "$OUT" "database-sentinel" "the drift report names the artifact"

# Everything deleted while the manifest still claims otherwise: none + drifted.
# This is the pair the flat four-state list could not express.
H=$(mkhome deleted); inst "$H" >/dev/null
rm -f "$H/$BIN"/*.sh
OUT=$(check "$H")
has "$OUT" "none"    "all-deleted-but-attested reports completeness none"
has "$OUT" "drifted" "all-deleted-but-attested reports integrity drifted"

echo
echo "=== 3.2c-i  an artifact with no row is unverifiable, not absent and not clean ==="
H=$(mkhome unattested); inst "$H" >/dev/null
grep -v 'database-sentinel' "$H/$MAN" > "$H/$MAN.new" && mv "$H/$MAN.new" "$H/$MAN"
OUT=$(check "$H")
has  "$OUT" "unverifiable" "present-but-unattested reports unverifiable"
hasnt "$OUT" "attested — " "present-but-unattested is not reported as a clean install"

echo
echo "=== 3.2e-i  an interrupted UPGRADE leaves new bytes against an old row ==="
# The crash the previous revision never covered. It is a STALE row, not a
# missing one, and reports drifted — 'present but unattested' and 'clean' are
# both wrong.
H=$(mkhome upgrade); inst "$H" >/dev/null
mkdir -p "$TMP/v2"
cp "$SRCDIR"/*.sh "$SRCDIR/ARTIFACTS" "$TMP/v2/"
sed -i.bak 's/^# database-sentinel-version: .*/# database-sentinel-version: 2.0.0/' "$TMP/v2/database-sentinel.sh"
rm -f "$TMP/v2"/*.bak; chmod +x "$TMP/v2"/*.sh
env HOME="$H" INSTALL_PROJECT_HOOKS_TEST_ABORT_BEFORE_MANIFEST=1 \
    "$INSTALL" --source "$TMP/v2" >/dev/null 2>&1
OUT=$(check "$H")
has "$OUT" "drifted" "interrupted upgrade reports drifted"
hasnt "$OUT" "unverifiable" "interrupted upgrade is a stale row, not a missing one"

echo
echo "=== 3.2c  an interrupted run leaves complete files and an untorn manifest ==="
H=$(mkhome aborted)
env HOME="$H" INSTALL_PROJECT_HOOKS_TEST_ABORT_AFTER=1 \
    "$INSTALL" --source "$SRCDIR" >/dev/null 2>&1
torn=0
for f in "$H/$BIN"/*.sh; do
  [ -e "$f" ] || continue
  # A published artifact is either absent or byte-complete — never truncated.
  base=$(basename "$f")
  cmp -s "$f" "$SRCDIR/$base" || torn=1
done
[ "$torn" -eq 0 ] && ok "every published artifact is byte-complete, never truncated" \
                  || bad "every published artifact is byte-complete, never truncated"
if [ -f "$H/$MAN" ]; then
  if awk -F'\t' 'NF>=3 && $3 ~ /^[0-9a-f]{64}$/ {good++} NF>0 && !(NF>=3 && $3 ~ /^[0-9a-f]{64}$/) {bad++} END{exit !(bad==0)}' "$H/$MAN"; then
    ok "the manifest is the pre-run or post-run version, never a torn mixture"
  else
    bad "the manifest is the pre-run or post-run version, never a torn mixture" "$(cat "$H/$MAN")"
  fi
else
  ok "the manifest is the pre-run version (absent), never a torn mixture"
fi
OUT=$(check "$H")
has "$OUT" "partial" "an interrupted run leaves the machine partially provisioned — a legitimate state, reported"

echo
echo "=== 3.2d  an artifact published by another installer is scoped out, not called drift ==="
# The shared bin directory is shared. install-shared-artifact.sh publishes
# openspec-change-gate, reviewer-cli and run-plan-review into the same place and
# writes no row in this manifest. Found against the real machine: sweeping them
# in reported a healthy install as drifted.
H=$(mkhome foreign); inst "$H" >/dev/null
cp "$SRCDIR/database-sentinel.sh" "$H/$BIN/reviewer-cli.sh"
OUT=$(check "$H")
has  "$OUT" "reviewer-cli"  "an undeclared artifact is named in the report"
has  "$OUT" "not covered"   "…and scoped out rather than judged"
has  "$OUT" "attested"      "the declared artifacts are still attested"
hasnt "$OUT" "INTEGRITY     drifted" "an undeclared artifact does not make the machine drifted"

echo
echo "=== 3.2b-ii  concurrent publishing runs do not lose each other's rows ==="
# A lost-update defect, which atomicity alone does not address.
#
# STAGE-2 FINDING 3. This case used to background two runs and immediately wait.
# Each finished in milliseconds, so the two critical sections never overlapped
# and the assertion held whether or not a lock existed — verified: with the
# mkdir lock loop removed outright it passed 15 of 15 runs. It asserted nothing.
#
# The first run now HOLDS the lock across the read-modify-write window
# (INSTALL_PROJECT_HOOKS_TEST_HOLD_LOCK), so the second provably contends. Two
# things are asserted, and the pair is what pins the mechanism:
#
#   rows      — all three survive. Unlocked, the second run reads the manifest
#               before the first writes it and the later writer discards the
#               earlier's rows.
#   waiting   — the second run's elapsed time covers the hold. Unlocked it
#               returns immediately, so this is what distinguishes "serialized"
#               from "happened not to collide".
HOLD=3
H=$(mkhome concurrent)
mkdir -p "$TMP/other"
cp "$SRCDIR/database-sentinel.sh" "$TMP/other/"
sed 's/^# database-sentinel-version: .*/# other-hook-version: 1.0.0/' \
    "$SRCDIR/database-sentinel.sh" > "$TMP/other/other-hook.sh"
cp "$SRCDIR/ARTIFACTS" "$TMP/other/"
chmod +x "$TMP/other"/*.sh

env HOME="$H" INSTALL_PROJECT_HOOKS_TEST_HOLD_LOCK="$HOLD" \
    "$INSTALL" --source "$SRCDIR" >/dev/null 2>&1 &
p1=$!
sleep 1                      # let the first run take the lock and read
t0=$(date +%s)
env HOME="$H" "$INSTALL" --source "$TMP/other" --artifacts other-hook >/dev/null 2>&1
t1=$(date +%s)
wait $p1

n=$(grep -c $'\t' "$H/$MAN" 2>/dev/null || echo 0)
if [ "$n" -eq 3 ]; then
  ok "both concurrent runs' rows survive (3 rows)"
else
  bad "both concurrent runs' rows survive (3 rows)" "got $n:" "$(cat "$H/$MAN" 2>/dev/null)"
fi

waited=$(( t1 - t0 ))
if [ "$waited" -ge $(( HOLD - 1 )) ]; then
  ok "the second run BLOCKED on the lock rather than interleaving (waited ${waited}s)"
else
  bad "the second run BLOCKED on the lock rather than interleaving" \
      "it returned after ${waited}s while the first held the lock for ${HOLD}s —" \
      "it did not contend, so this case cannot speak to mutual exclusion"
fi

echo
echo "=== 3.2b-ii  the lock does not outlive the process that took it ==="
# The requirement behind the named primitive. flock(1) does not exist on this
# platform; what matters is that a killed installer does not wedge the machine.
H=$(mkhome stalelock)
mkdir -p "$H/.agenticapps/manifest.lock"
printf '999999' > "$H/.agenticapps/manifest.lock/pid"    # a pid that cannot be alive
OUT=$(inst "$H"); rc=$?
[ "$rc" -eq 0 ] && ok "a lock left by a dead process is broken, not waited on forever" \
               || bad "a lock left by a dead process is broken, not waited on forever" "exit $rc: $(printf '%s' "$OUT" | head -2)"

echo
echo "=== 3.2a-v  the shared directory's write surface ==="
H=$(mkhome writesurface); inst "$H" >/dev/null
me=$(id -u)
for f in "$H/$BIN" "$H/$BIN/database-sentinel.sh" "$H/$BIN/normalize-claude-md.sh" "$H/$MAN"; do
  n=$(basename "$f")
  owner=$(stat -f '%u' "$f" 2>/dev/null || stat -c '%u' "$f" 2>/dev/null)
  [ "$owner" = "$me" ] && ok "owned by the executing user: $n" \
                       || bad "owned by the executing user: $n" "owner uid $owner, running as $me"
  mode=$(stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f" 2>/dev/null)
  if [ $(( 8#$mode & 8#022 )) -eq 0 ]; then
    ok "not group- or world-writable: $n ($mode)"
  else
    bad "not group- or world-writable: $n ($mode)"
  fi
done

echo
echo "=== 3.2a-v  publication does not follow a symlink at the destination ==="
H=$(mkhome symlink)
mkdir -p "$H/$BIN"
: > "$TMP/symlink-victim"
ln -s "$TMP/symlink-victim" "$H/$BIN/database-sentinel.sh"
inst "$H" >/dev/null 2>&1
if [ -s "$TMP/symlink-victim" ]; then
  bad "publication does not write through a symlink at the destination" \
      "the victim outside the destination directory was overwritten"
else
  ok "publication does not write through a symlink at the destination"
fi
if [ -L "$H/$BIN/database-sentinel.sh" ]; then
  bad "the symlink is replaced by a regular file" "destination is still a symlink"
else
  ok "the symlink is replaced by a regular file"
fi

echo
echo "=== Stage-2 finding 2  the write surface is CHECKED, not merely established ==="
# The block above proves the INSTALLER sets the mode on a tree it just created.
# It cannot observe the machine anyone is actually running on. The delta requires
# an artifact owned by another user to be "reported, not executed silently" and
# forbids group- or world-writable artifacts, the directory and the manifest —
# and calls all of it checkable by the conformance tool. Nothing checked it.
#
# Degradation AFTER a clean install is the case that matters: the installer has
# already run and exited 0, and every digest still matches.
#
# Assertions match the WRITE-SURFACE label, not a bare substring: "manifest"
# and "database-sentinel" appear in this tool's normal output, so a substring
# match would pass against the unfixed tool for the wrong reason.
#
# The two axes are NOT overloaded. `integrity` is defined by the delta as
# whether present artifacts match their rows; a group-writable file whose
# digest still matches is `attested` and saying otherwise would corrupt a
# vocabulary the delta spent a review round pinning down. The write surface is
# reported as its own dimension and counts toward --strict.
H=$(mkhome perms-artifact); inst "$H" >/dev/null
chmod g+w "$H/$BIN/database-sentinel.sh"
OUT=$(check "$H")
has "$OUT" "WRITE-SURFACE" "a group-writable artifact is reported as a write-surface finding"
has "$OUT" "database-sentinel.sh" "…and the finding names the artifact"

H=$(mkhome perms-dir); inst "$H" >/dev/null
chmod go+w "$H/$BIN"
OUT=$(check "$H")
has "$OUT" "WRITE-SURFACE" "a world-writable shared directory is reported"

H=$(mkhome perms-manifest); inst "$H" >/dev/null
chmod g+w "$H/.agenticapps/manifest.tsv"
OUT=$(check "$H")
has "$OUT" "WRITE-SURFACE" "a group-writable manifest is reported — the digest record is covered by the same rules"
has "$OUT" "manifest.tsv" "…and the finding names the manifest"

# --strict is what CI would run. A write surface anyone can author must fail it.
H=$(mkhome perms-strict); inst "$H" >/dev/null
chmod g+w "$H/$BIN/database-sentinel.sh"
check "$H" --strict >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "--strict fails on a group-writable artifact" \
                || bad "--strict fails on a group-writable artifact" "got exit 0"

# And the healthy machine stays quiet: a check that cries wolf is one nobody runs.
H=$(mkhome perms-clean); inst "$H" >/dev/null
OUT=$(check "$H")
hasnt "$OUT" "WRITE-SURFACE" "a freshly installed machine reports no write-surface finding"
check "$H" --strict >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "--strict passes on a freshly installed machine" \
                || bad "--strict passes on a freshly installed machine" "got exit $rc"

echo
echo "=== Stage-2 finding 8  a missing option value is a usage error, not a crash ==="
# The sibling installer guards every option and exits 64. This one dereferenced
# $2 under `set -u` and died with 'unbound variable'.
OUT=$(env HOME="$TMP" "$CHECK" --dest 2>&1); rc=$?
[ "$rc" -eq 64 ] && ok "--dest with no value exits 64" \
                 || bad "--dest with no value exits 64" "got exit $rc: $(printf '%s' "$OUT" | head -1)"
hasnt "$OUT" "unbound variable" "…and does not report a shell error to the operator"

echo
echo "=== 3.2a-ii  the manifest check and the source check are reported apart ==="
H=$(mkhome sourcecheck); inst "$H" >/dev/null
printf '\n# local edit\n' >> "$H/$BIN/database-sentinel.sh"
OUT=$(check "$H" --source-check "$SRCDIR")
has "$OUT" "MANIFEST" "the manifest check (executed vs published) is labelled"
has "$OUT" "SOURCE"   "the source check (executed vs core) is labelled separately"

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
