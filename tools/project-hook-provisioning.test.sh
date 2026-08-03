#!/usr/bin/env bash
# project-hook-provisioning.test.sh — multi-artifact publication and the
# per-machine provisioning check.
#
# Covers shim-project-hooks tasks 3.2, 3.2a, 3.2a-v, 3.2b-ii, 3.2c, 3.2c-i,
# 3.2d-ii, 3.2e-i, 3.6, and check-implementation-currency tasks 1.1–1.6 — all
# tdd="true".
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
sha_sum() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }
# The version an implementation declares, read from the implementation. A
# literal here would assert a fact about a release rather than about the
# mechanism, and would go red the next time an implementation is legitimately
# bumped — which has already happened once in this suite.
verof() { grep -m1 -oE "^#[[:space:]]*$2-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+" "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'; }

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
# None of the three axes is overloaded. `integrity` is defined by the delta as
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
echo "=== 3.2a-ii  the manifest check and the currency check are reported apart ==="
H=$(mkhome sourcecheck); inst "$H" >/dev/null
printf '\n# local edit\n' >> "$H/$BIN/database-sentinel.sh"
OUT=$(check "$H" --source-check "$SRCDIR")
has "$OUT" "MANIFEST" "the manifest check (executed vs published) is labelled"
has "$OUT" "CURRENCY" "the currency check (executed vs the authority) is labelled separately"

# ─────────────────────────────────────────────────────────────────────────────
# check-implementation-currency
#
# The comparison these cases exercise ALREADY EXISTED as --source-check. What
# did not exist was a verdict: the comparison reported DIFFERS into its own
# block, the summary was computed without it, and the tool printed "This machine
# is provisioned" anyway. Every assertion below is about the summary being
# obliged to agree with the comparison, not about the comparison itself.
# ─────────────────────────────────────────────────────────────────────────────

# An authority tree is a directory holding declared implementations. mkauth
# copies the real ones and applies whatever the case needs.
# $1 = case name -> echoes the path.
#
# CASE NAMES ARE DELIBERATELY NOT THE WORDS THE ASSERTIONS LOOK FOR — no
# "behind", "ahead", "stale", "current", "unknown". They were, and the direction
# assertions passed against the UNFIXED tool: the old --source-check line ends
# with the authority path, so `has "$OUT" "behind"` matched ".../auth-behind".
# This is the override-dir fixture lesson, repeated four months later on the
# same suite. Directions are also asserted against the artifact's own CURRENCY
# line rather than the whole report, so a stray path cannot satisfy them again.
mkauth() {
  local a="$TMP/fixture-$1"
  mkdir -p "$a"
  cp "$SRCDIR"/*.sh "$SRCDIR/ARTIFACTS" "$a/"
  chmod +x "$a"/*.sh
  printf '%s' "$a"
}
# The CURRENCY report for one artifact: its verdict line plus its remedy line.
curline() { printf '%s' "$1" | grep -A1 "CURRENCY  $2  "; }
# Rewrite an artifact's version marker in place, and change its bytes with it.
setver() { # $1 = file, $2 = artifact name, $3 = version
  sed -i.bak "s/^# $2-version: .*/# $2-version: $3/" "$1"
  rm -f "$1.bak"
}

echo
echo "=== 1.1  a machine attested against a stale authority is NOT provisioned ==="
# Against the REAL history, not a fixture: an authority tree built from the
# commit before the fixes, installed from, then checked against today's tree.
# This is the exact condition observed on 2026-08-03 — complete + attested while
# running builds three landed fixes behind.
OLD="$TMP/old-authority"
mkdir -p "$OLD"
if git -C "$ROOT" archive f6e4b64~1 reference-implementations/project-hooks 2>/dev/null \
     | tar -x -C "$OLD" --strip-components=2 2>/dev/null && [ -f "$OLD/database-sentinel.sh" ]; then
  chmod +x "$OLD"/*.sh
  H=$(mkhome stale-real)
  env HOME="$H" "$INSTALL" --source "$OLD" >/dev/null 2>&1
  OUT=$(check "$H")
  has   "$OUT" "complete"  "a stale install is still reported complete — currency is a separate axis"
  has   "$OUT" "attested"  "…and still attested; it matches the row it was published from"
  has   "$OUT" "stale"     "…and reported STALE against the authority"
  hasnt "$OUT" "This machine is provisioned" \
        "the summary no longer claims provisioned while the comparison says otherwise"
  # --strict is what CI runs, and this is a real behaviour change.
  check "$H" --strict >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] && ok "--strict fails on a stale machine" \
                  || bad "--strict fails on a stale machine" "got exit 0"
else
  bad "1.1 fixture: an authority tree could be built from f6e4b64~1" \
      "git archive failed — this case asserts against real history and cannot be skipped silently"
fi

echo
echo "=== 1.2  the question is asked by default, and its absence is disclosed ==="
# Before this change a default run read identically to a run where the stronger
# question was asked and passed. Both halves are asserted: that the default now
# asks, and that a run which cannot ask says so instead of reading clean.
H=$(mkhome default-asks); inst "$H" >/dev/null
OUT=$(check "$H")
has "$OUT" "CURRENCY" "a default run asks the currency question without being told to"
has "$OUT" "current"  "…and a machine installed from the authority reports current"

H=$(mkhome opted-out); inst "$H" >/dev/null
OUT=$(check "$H" --no-source-check)
# Matched on the axis line, not the bare word: against the unfixed tool
# --no-source-check is an unknown OPTION, and "unknown" alone passed on the
# usage error it printed while exiting 64.
has   "$OUT" "CURRENCY      unknown" "--no-source-check reports currency unknown"
hasnt "$OUT" "This machine is provisioned" \
      "…and withholds the provisioned summary — an unasked question is not a clean bill"
has   "$OUT" "not asked" "…naming the question that went unanswered"

echo
echo "=== 1.3  the four stale sub-cases, asserted on the MESSAGE ==="
# A single "differs" assertion would pass on all four. The messages are where
# the remedy lives, and Decision 5 makes three of the four remedies differ.

# (a) published BEHIND the authority — the ordinary lag, and the one case where
#     re-running the installer is the right advice.
A=$(mkauth a); setver "$A/database-sentinel.sh" database-sentinel 9.9.9
H=$(mkhome case-a); inst "$H" >/dev/null
L=$(curline "$(check "$H" --source-check "$A")" database-sentinel)
PUBV=$(verof "$SRCDIR/database-sentinel.sh" database-sentinel)
has "$L" "stale"               "behind: reported stale"
has "$L" "$PUBV"               "behind: names the published version ($PUBV)"
has "$L" "9.9.9"               "behind: names the authority's version"
has "$L" "(behind)"            "behind: names the direction"
has "$L" "install-project-hooks.sh" "behind: the remedy is the installer"

# (b) published AHEAD of the authority — the installer refuses downgrades, so
#     naming it here would be advice that cannot work.
A=$(mkauth b)
V="$TMP/v-b"; mkdir -p "$V"; cp "$SRCDIR"/*.sh "$SRCDIR/ARTIFACTS" "$V/"
setver "$V/database-sentinel.sh" database-sentinel 9.9.9; chmod +x "$V"/*.sh
H=$(mkhome case-b); env HOME="$H" "$INSTALL" --source "$V" >/dev/null 2>&1
L=$(curline "$(check "$H" --source-check "$A")" database-sentinel)
has "$L" "stale"   "ahead: reported stale"
has "$L" "(ahead)" "ahead: names the direction — not passed as newer-and-fine"
# The precise thing the review objected to: one universal remedy.
hasnt "$L" "Re-run install-project-hooks.sh" \
      "ahead: the remedy is NOT the installer, which refuses downgrades"

# (c) versions equal, bytes differ — a build error or a hand-edit, not a lag.
A=$(mkauth c); printf '\n# authority-side edit\n' >> "$A/database-sentinel.sh"
H=$(mkhome case-c); inst "$H" >/dev/null
L=$(curline "$(check "$H" --source-check "$A")" database-sentinel)
has "$L" "stale"          "versions-equal-bytes-differ: reported stale"
has "$L" "versions agree" "…and the message says the versions agree while the bytes do not"
hasnt "$L" "Re-run install-project-hooks.sh" \
      "…and the remedy is to investigate, not to re-install over a build error"

# (d) the authority holds no file for a DECLARED artifact. The authority still
#     holds the other one, so it IS a checkout — this is a finding, not unknown.
A=$(mkauth d); rm -f "$A/normalize-claude-md.sh"
H=$(mkhome case-d); inst "$H" >/dev/null
OUT=$(check "$H" --source-check "$A")
L=$(curline "$OUT" normalize-claude-md)
has   "$L" "stale"                   "no-authority-file: reported stale, not skipped"
has   "$L" "holds no file"           "no-authority-file: the message says the authority lacks it"
has   "$L" "ARTIFACTS"               "no-authority-file: the remedy names the declaration to reconcile"
hasnt "$OUT" "CURRENCY      unknown" "no-authority-file: not unknown — the authority was reached"

echo
echo "=== 1.4  the unknown sub-cases, and none of them reads as current ==="
# Asserting only the absence of `stale` passes on a silent green, so every case
# below asserts positively that the machine is not reported current.
H=$(mkhome unk-absent); inst "$H" >/dev/null
OUT=$(check "$H" --source-check "$TMP/no-such-authority")
has   "$OUT" "unknown" "authority path absent: unknown"
has   "$OUT" "no-such-authority" "…and the report names the path it looked for"
hasnt "$OUT" "CURRENCY      current" "…and does not read as current"
hasnt "$OUT" "This machine is provisioned" "…and withholds the provisioned summary"

# A directory that exists but is not an authority checkout. Reporting every
# declared artifact stale against it would be confidently wrong.
A="$TMP/auth-empty"; mkdir -p "$A"; : > "$A/reviewer-cli.sh"
H=$(mkhome unk-notcheckout); inst "$H" >/dev/null
OUT=$(check "$H" --source-check "$A")
has   "$OUT" "unknown" "a directory holding no declared artifact: unknown"
hasnt "$OUT" "CURRENCY      stale"   "…not stale — it is not an authority checkout"
hasnt "$OUT" "CURRENCY      current" "…and not current"

# A file that exists but cannot be read. A failed read is not a difference.
A=$(mkauth g); chmod 000 "$A/database-sentinel.sh"
H=$(mkhome case-g); inst "$H" >/dev/null
OUT=$(check "$H" --source-check "$A")
if [ -r "$A/database-sentinel.sh" ]; then
  echo "  SKIP  unreadable authority file — running as a user who can read 000 (root?)"
else
  has   "$OUT" "unknown" "an unreadable authority file: unknown for that artifact"
  hasnt "$OUT" "CURRENCY      current" "…and the machine is not reported current"
fi
chmod 644 "$A/database-sentinel.sh" 2>/dev/null

echo
echo "=== 1.5  artifacts published by another installer are not judged ==="
# A regression fence. An earlier revision of the delta made an absent authority
# file stale WITHOUT scoping it to the declared set, and running it flagged
# exactly these three — each of which the manifest check already reports as
# "not covered — published by another installer".
H=$(mkhome outofscope); inst "$H" >/dev/null
for foreign in openspec-change-gate reviewer-cli run-plan-review; do
  cp "$SRCDIR/database-sentinel.sh" "$H/$BIN/$foreign.sh"
done
OUT=$(check "$H")
for foreign in openspec-change-gate reviewer-cli run-plan-review; do
  hasnt "$OUT" "CURRENCY  $foreign" "$foreign is not judged for currency"
done
has "$OUT" "CURRENCY      current" "…and the declared artifacts still report current"

echo
echo "=== 1.6  version ordering is component-wise numeric, never lexical ==="
# A lexical compare places 1.10.0 below 1.9.0, inverting the direction and
# pointing the operator at the opposite remedy.
A=$(mkauth e);   setver "$A/database-sentinel.sh" database-sentinel 1.9.0
V="$TMP/v-e"; mkdir -p "$V"; cp "$SRCDIR"/*.sh "$SRCDIR/ARTIFACTS" "$V/"
setver "$V/database-sentinel.sh" database-sentinel 1.10.0; chmod +x "$V"/*.sh
H=$(mkhome case-e); env HOME="$H" "$INSTALL" --source "$V" >/dev/null 2>&1
L=$(curline "$(check "$H" --source-check "$A")" database-sentinel)
has   "$L" "(ahead)"  "1.10.0 against 1.9.0 is reported AHEAD"
hasnt "$L" "(behind)" "…and not behind, which is what a lexical compare would say"

echo
echo "=== Decision 5  drifted AND stale is investigate-first, not re-install ==="
# Re-installing over a hand-edited file overwrites the evidence of the edit.
A=$(mkauth f); setver "$A/database-sentinel.sh" database-sentinel 9.9.9
H=$(mkhome case-f); inst "$H" >/dev/null
printf '\n# tampered\n' >> "$H/$BIN/database-sentinel.sh"
OUT=$(check "$H" --source-check "$A")
L=$(curline "$OUT" database-sentinel)
has   "$OUT" "drifted"      "drifted+stale: integrity still reports drifted"
has   "$L" "investigate"    "drifted+stale: the remedy is to investigate first"
hasnt "$L" "Re-run install-project-hooks.sh" \
      "drifted+stale: the installer is NOT named — it would overwrite the evidence"

echo
echo "=== 2.5  current is qualified as matching THIS checkout ==="
# An equally stale checkout and install agree and report current. The verdict is
# right about the disk; the qualification is what stops it recreating the false
# green one level up.
H=$(mkhome qualified); inst "$H" >/dev/null
OUT=$(check "$H")
has "$OUT" "this authority checkout" "current is qualified as matching this authority checkout"

echo
echo "=== 2.8  the check installs nothing ==="
A=$(mkauth h); setver "$A/database-sentinel.sh" database-sentinel 9.9.9
H=$(mkhome case-h); inst "$H" >/dev/null
BEFORE=$(sha_sum "$H/$BIN/database-sentinel.sh")
check "$H" --source-check "$A" >/dev/null 2>&1
AFTER=$(sha_sum "$H/$BIN/database-sentinel.sh")
[ "$BEFORE" = "$AFTER" ] && ok "a stale artifact is reported, never repaired" \
                         || bad "a stale artifact is reported, never repaired" "the check rewrote the shared bin"

echo
echo "=== post-implementation review round 2 ==="
# Four behaviours the second plan review found unspecified. All four were
# reproduced against the implementation before being fixed, so none of these is
# a hypothetical.

# codex: naming an authority and declining to consult one are contradictory, and
# last-one-wins silently did the opposite of what half the invocation asked.
H=$(mkhome conflict); inst "$H" >/dev/null
OUT=$(check "$H" --source-check "$SRCDIR" --no-source-check); rc=$?
[ "$rc" -eq 64 ] && ok "--source-check with --no-source-check is a usage error (64)" \
                 || bad "--source-check with --no-source-check is a usage error (64)" "got exit $rc"
has "$OUT" "contradict" "…and says why, rather than silently picking one"
OUT=$(check "$H" --no-source-check --source-check "$SRCDIR"); rc=$?
[ "$rc" -eq 64 ] && ok "…in either order — order does not decide it" \
                 || bad "…in either order — order does not decide it" "got exit $rc"

# opencode: `unknown` fails --strict, so opting out and demanding a strict pass
# is a contradiction that always exits 1. Asserted so the contradiction is a
# property of the tool rather than an accident of the aggregation.
H=$(mkhome optout-strict); inst "$H" >/dev/null
check "$H" --no-source-check --strict >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "--no-source-check with --strict always fails — an opt-out is not a pass" \
                || bad "--no-source-check with --strict always fails" "got exit $rc"
# …and the same machine passes --strict when the question IS asked.
check "$H" --strict >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "…while the same machine passes --strict when currency is checked" \
                || bad "…while the same machine passes --strict when currency is checked" "got exit $rc"

# opencode: a declared artifact absent on the machine AND absent from the
# authority is not judged at all. Completeness already reports it; currency
# reporting it too would double-count one fact on two axes.
A=$(mkauth i); rm -f "$A/normalize-claude-md.sh"
H=$(mkhome case-i); inst "$H" >/dev/null
rm -f "$H/$BIN/normalize-claude-md.sh"
grep -v 'normalize-claude-md' "$H/$MAN" > "$H/$MAN.new" && mv "$H/$MAN.new" "$H/$MAN"
OUT=$(check "$H" --source-check "$A")
has   "$OUT" "partial" "absent-on-both: completeness reports it"
hasnt "$OUT" "CURRENCY  normalize-claude-md" "absent-on-both: currency does not judge it"
hasnt "$OUT" "CURRENCY      stale" "absent-on-both: the machine is not reported stale for it"

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
