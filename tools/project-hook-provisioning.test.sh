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
OUT=$(env HOME="$H" "$INSTALL" --source "$TMP/badsrc" 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "absent implementation: installer exits non-zero" \
                || bad "absent implementation: installer exits non-zero" "got exit 0"
has "$OUT" "normalize-claude-md" "absent implementation: the report names the missing artifact"

H=$(mkhome nonexec-src)
mkdir -p "$TMP/nonexecsrc"
cp "$SRCDIR"/*.sh "$TMP/nonexecsrc/"
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
  if grep -q '1\.0\.0' "$H/$MAN"; then
    ok "the row's version comes from the implementation's own marker"
  else
    bad "the row's version comes from the implementation's own marker" "$(cat "$H/$MAN")"
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
cp "$SRCDIR"/*.sh "$TMP/v2/"
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
echo "=== 3.2b-ii  concurrent publishing runs do not lose each other's rows ==="
# A lost-update defect, which atomicity alone does not address.
H=$(mkhome concurrent)
mkdir -p "$TMP/other"
cp "$SRCDIR/database-sentinel.sh" "$TMP/other/"
sed 's/^# database-sentinel-version: .*/# other-hook-version: 1.0.0/' \
    "$SRCDIR/database-sentinel.sh" > "$TMP/other/other-hook.sh"
chmod +x "$TMP/other"/*.sh
env HOME="$H" "$INSTALL" --source "$SRCDIR" >/dev/null 2>&1 &
p1=$!
env HOME="$H" "$INSTALL" --source "$TMP/other" --artifacts other-hook >/dev/null 2>&1 &
p2=$!
wait $p1; wait $p2
n=$(grep -c $'\t' "$H/$MAN" 2>/dev/null || echo 0)
if [ "$n" -eq 3 ]; then
  ok "both concurrent runs' rows survive (3 rows)"
else
  bad "both concurrent runs' rows survive (3 rows)" "got $n:" "$(cat "$H/$MAN" 2>/dev/null)"
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
echo "=== 3.2a-ii  the manifest check and the source check are reported apart ==="
H=$(mkhome sourcecheck); inst "$H" >/dev/null
printf '\n# local edit\n' >> "$H/$BIN/database-sentinel.sh"
OUT=$(check "$H" --source-check "$SRCDIR")
has "$OUT" "MANIFEST" "the manifest check (executed vs published) is labelled"
has "$OUT" "SOURCE"   "the source check (executed vs core) is labelled separately"

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
