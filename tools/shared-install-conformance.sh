#!/usr/bin/env bash
# shared-install-conformance.sh — scores an installer's shared-path arbitration.
#
# The contract, from reference-implementations/shared-install/README.md:
#
#   An install into ~/.agenticapps/bin/ MUST be MONOTONIC — after any set of
#   concurrent installs, the shared path holds the NEWEST version any of them
#   offered. Refusing to downgrade is necessary and NOT sufficient: the
#   read-compare-write must be serialised, or two correct decisions taken
#   against the same observed state let the later writer win regardless of
#   version.
#
# Usage: tools/shared-install-conformance.sh <path-to-install-shared-artifact>
#
# Exit 0 = conformant, 1 = at least one row failed.
# Every write lands in a mktemp dir removed on exit.

set -uo pipefail

pass=0
fail=0
WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

INSTALLER="${1:-}"
[ -n "$INSTALLER" ] || { echo "usage: $0 <path-to-install-shared-artifact>" >&2; exit 2; }
[ -f "$INSTALLER" ] || { echo "not found: $INSTALLER" >&2; exit 2; }

KEY="demo-version"

# Build an artifact carrying $1 as its version marker.
artifact() { # $1=version $2=dest
  printf '#!/usr/bin/env bash\n# %s: %s\necho payload-%s\n' "$KEY" "$1" "$1" > "$2"
  chmod +x "$2"
}

installed_version() { # $1=path
  [ -f "$1" ] || { printf 'ABSENT'; return; }
  head -n 40 "$1" | grep -m1 -oE "^#[[:space:]]*${KEY}:[[:space:]]*[0-9.]+" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || printf 'UNMARKED'
}

ok()   { echo "  PASS  $1"; pass=$((pass + 1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail + 1)); }

W="$(mktemp -d)"; WORK="$W"
echo "═══ $INSTALLER"

# ── A. Arbitration ───────────────────────────────────────────────────────────
echo "  ── A. Arbitration ──"

dst="$W/a1/artifact.sh"; artifact 1.0.0 "$W/src-100.sh"
bash "$INSTALLER" "$W/src-100.sh" "$dst" "$KEY" >/dev/null 2>&1
[ "$(installed_version "$dst")" = "1.0.0" ] \
  && ok "installs when destination is absent" \
  || bad "installs when destination is absent — got $(installed_version "$dst")"

artifact 1.1.0 "$W/src-110.sh"
bash "$INSTALLER" "$W/src-110.sh" "$dst" "$KEY" >/dev/null 2>&1
[ "$(installed_version "$dst")" = "1.1.0" ] \
  && ok "installs a newer version over an older" \
  || bad "installs a newer version over an older — got $(installed_version "$dst")"

artifact 1.0.5 "$W/src-105.sh"
bash "$INSTALLER" "$W/src-105.sh" "$dst" "$KEY" >/dev/null 2>&1; rc=$?
if [ "$(installed_version "$dst")" = "1.1.0" ] && [ "$rc" -eq 3 ]; then
  ok "refuses a downgrade (exit 3, file untouched)"
else
  bad "refuses a downgrade — version=$(installed_version "$dst") exit=$rc"
fi

# An unmarked file is 0.0.0, so anything marked wins over it. Treating it as
# "unknown, leave alone" would freeze every machine still holding a pre-marker
# copy — which was the entire fleet before core#41.
dst2="$W/a2/artifact.sh"; mkdir -p "$W/a2"
printf '#!/usr/bin/env bash\necho legacy\n' > "$dst2"; chmod +x "$dst2"
bash "$INSTALLER" "$W/src-100.sh" "$dst2" "$KEY" >/dev/null 2>&1
[ "$(installed_version "$dst2")" = "1.0.0" ] \
  && ok "treats an unmarked destination as 0.0.0" \
  || bad "treats an unmarked destination as 0.0.0 — got $(installed_version "$dst2")"

# A source with no marker is an authoring error, not a version of 0.0.0 to be
# installed. Refuse it rather than publish an unarbitratable file.
printf '#!/usr/bin/env bash\necho nomarker\n' > "$W/src-bad.sh"
bash "$INSTALLER" "$W/src-bad.sh" "$W/a3/artifact.sh" "$KEY" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "refuses an unmarked SOURCE (exit 1)" \
                || bad "refuses an unmarked SOURCE — exit $rc"

# ── B. Monotonicity under concurrency ────────────────────────────────────────
# The row this whole file exists for. SHARED_INSTALL_TEST_DELAY forces the
# interleave that an unlocked implementation loses to, instead of hoping to hit
# it by timing luck: the older installer reads, sleeps inside its
# compare-to-write window, and writes last. Serialised, the delay is irrelevant
# because the lock is held across it — which is exactly what distinguishes a
# conformant implementation from one that merely "refuses to downgrade".
echo "  ── B. Monotonicity under concurrency ──"

dst3="$W/b1/artifact.sh"; mkdir -p "$W/b1"
artifact 2.0.0 "$W/src-200.sh"
artifact 1.0.0 "$W/src-100b.sh"

# Older starts first and dawdles; newer runs while it sleeps.
SHARED_INSTALL_TEST_DELAY=3 bash "$INSTALLER" "$W/src-100b.sh" "$dst3" "$KEY" >/dev/null 2>&1 &
older=$!
sleep 1
bash "$INSTALLER" "$W/src-200.sh" "$dst3" "$KEY" >/dev/null 2>&1
wait "$older" 2>/dev/null
got="$(installed_version "$dst3")"
[ "$got" = "2.0.0" ] \
  && ok "older installer cannot clobber a newer one (interleaved)" \
  || bad "older installer clobbered a newer one — shared path left at $got, expected 2.0.0"

# Same again with the roles reversed: the NEWER one dawdles. Monotonicity must
# hold in both orderings, not just the convenient one.
dst4="$W/b2/artifact.sh"; mkdir -p "$W/b2"
SHARED_INSTALL_TEST_DELAY=3 bash "$INSTALLER" "$W/src-200.sh" "$dst4" "$KEY" >/dev/null 2>&1 &
newer=$!
sleep 1
bash "$INSTALLER" "$W/src-100b.sh" "$dst4" "$KEY" >/dev/null 2>&1
wait "$newer" 2>/dev/null
got="$(installed_version "$dst4")"
[ "$got" = "2.0.0" ] \
  && ok "newest wins when the newer installer is the slow one" \
  || bad "newest wins when the newer installer is the slow one — got $got"

# A burst: many installers, mixed versions, all at once. The final state must be
# the maximum offered, every time.
dst5="$W/b3/artifact.sh"; mkdir -p "$W/b3"
for v in 1.0.0 3.1.0 2.0.0 1.5.0 3.0.9; do
  artifact "$v" "$W/burst-$v.sh"
  bash "$INSTALLER" "$W/burst-$v.sh" "$dst5" "$KEY" >/dev/null 2>&1 &
done
wait
got="$(installed_version "$dst5")"
[ "$got" = "3.1.0" ] \
  && ok "5 concurrent installers converge on the maximum (3.1.0)" \
  || bad "5 concurrent installers converged on $got, expected 3.1.0"

# ── C. Liveness ──────────────────────────────────────────────────────────────
# A lock that never breaks is worse than the race it prevents: permanent and
# silent. One killed installer must not wedge the machine forever.
echo "  ── C. Liveness ──"

dst6="$W/c1/artifact.sh"; mkdir -p "$W/c1"
mkdir -p "$dst6.lock"
# A pid that cannot be running. 4194304 is above Linux's default pid_max and
# macOS's ceiling, so `kill -0` on it fails for "no such process", not EPERM.
printf '4194304' > "$dst6.lock/pid"
SHARED_INSTALL_LOCK_TIMEOUT=5 bash "$INSTALLER" "$W/src-100.sh" "$dst6" "$KEY" >/dev/null 2>&1
[ "$(installed_version "$dst6")" = "1.0.0" ] \
  && ok "breaks a stale lock held by a dead pid" \
  || bad "breaks a stale lock held by a dead pid — got $(installed_version "$dst6")"

# A LIVE holder must be waited for, then time out with an error — never a
# silent skip, which would look like a successful install that did nothing.
dst7="$W/c2/artifact.sh"; mkdir -p "$W/c2"
mkdir -p "$dst7.lock"; printf '%s' "$$" > "$dst7.lock/pid"   # this harness is alive
SHARED_INSTALL_LOCK_TIMEOUT=2 bash "$INSTALLER" "$W/src-100.sh" "$dst7" "$KEY" >/dev/null 2>&1; rc=$?
rm -rf "$dst7.lock"
[ "$rc" -eq 1 ] && ok "times out with an error on a live lock holder" \
               || bad "times out with an error on a live lock holder — exit $rc"

# ── D. Reader integrity ──────────────────────────────────────────────────────
# The destination must never be observable as a partial file: an agent's
# PreToolUse hook can fire mid-install. Rename-into-place gives that; a
# truncate-and-write does not. Approximated by asserting no temp litter survives
# and the result is complete and executable.
echo "  ── D. Reader integrity ──"
leftovers="$(find "$(dirname "$dst")" -name '*.tmp.*' 2>/dev/null | wc -l | tr -d ' ')"
[ "$leftovers" = "0" ] && ok "leaves no temp files behind" \
                       || bad "left $leftovers temp file(s) in the destination directory"
[ -x "$dst" ] && [ "$(bash "$dst" 2>/dev/null)" = "payload-1.1.0" ] \
  && ok "installed file is complete and executable" \
  || bad "installed file is not complete/executable"

# ── E. Opt-in downgrade ──────────────────────────────────────────────────────
# The arbiter refusing downgrades is correct and makes every rollback row in a
# migration plan unexecutable. The escape is deliberate, scoped, and logged —
# and the log write must PRECEDE the replacement, or the audit record is lost
# in exactly the case it exists for.
echo "  ── E. Opt-in downgrade ──"
E="$W/dg"; mkdir -p "$E"
LOG="$E/install.log"
artifact 1.2.0 "$E/new.sh"; artifact 1.1.0 "$E/old.sh"

run_dg() { # remaining args appended to the invocation
  AGENTICAPPS_INSTALL_LOG="$LOG" bash "$INSTALLER" "$@" 2>&1
}

# baseline: 1.2.0 installed
bash "$INSTALLER" "$E/new.sh" "$E/dst.sh" "$KEY" >/dev/null 2>&1

run_dg "$E/old.sh" "$E/dst.sh" "$KEY" >/dev/null 2>&1
[ "$(installed_version "$E/dst.sh")" = "1.2.0" ]   && ok "without the flag, a downgrade is still refused"   || bad "downgrade happened without the flag"

out="$(run_dg "$E/old.sh" "$E/dst.sh" "$KEY" --allow-downgrade dst.sh)"
[ "$(installed_version "$E/dst.sh")" = "1.2.0" ]   && ok "the flag alone, without a reason, is refused"   || bad "downgraded with no reason given"

out="$(run_dg "$E/old.sh" "$E/dst.sh" "$KEY" --allow-downgrade wrong.sh --reason "rollback")"
[ "$(installed_version "$E/dst.sh")" = "1.2.0" ]   && ok "naming a different artifact does not authorise this one"   || bad "an unrelated artifact name authorised the downgrade"

out="$(run_dg "$E/old.sh" "$E/dst.sh" "$KEY" --allow-downgrade dst.sh --reason "$(printf 'a\nfake\trecord')")"
[ "$(installed_version "$E/dst.sh")" = "1.2.0" ]   && ok "a reason containing control characters is refused outright"   || bad "a control-character reason was accepted"

out="$(run_dg "$E/old.sh" "$E/dst.sh" "$KEY" --allow-downgrade dst.sh --reason "gate 1.5.0 rollback per migration plan")"
[ "$(installed_version "$E/dst.sh")" = "1.1.0" ]   && ok "an authorised, reasoned downgrade proceeds"   || bad "authorised downgrade did not happen (got $(installed_version "$E/dst.sh"))"

grep -q 'downgrade' "$LOG" 2>/dev/null   && ok "the downgrade is recorded in the install log"   || bad "no log record was written"

[ "$(awk -F'\t' '/downgrade/{print NF}' "$LOG" | head -1)" = "7" ]   && ok "the record carries all seven tab-separated fields"   || bad "log record field count is $(awk -F'\t' '/downgrade/{print NF}' "$LOG" | head -1), expected 7"

# The log write gates the replacement: an unwritable log must abort BEFORE the
# artifact is replaced, or a silently downgraded binary outlives its record.
artifact 1.2.0 "$E/dst2.sh"
mkdir -p "$E/nowhere" && chmod 500 "$E/nowhere"
AGENTICAPPS_INSTALL_LOG="$E/nowhere/x.log" bash "$INSTALLER" "$E/old.sh" "$E/dst2.sh" "$KEY" \
  --allow-downgrade dst2.sh --reason "log should fail" >/dev/null 2>&1
[ "$(installed_version "$E/dst2.sh")" = "1.2.0" ] \
  && ok "an unwritable log aborts before the artifact is replaced" \
  || bad "artifact was downgraded despite the audit record failing"
chmod 700 "$E/nowhere" 2>/dev/null

echo
echo "═══ TOTAL: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
