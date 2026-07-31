#!/usr/bin/env bash
# resolve-core-artifact-conformance.sh — score a resolver copy against the
# pin contract. Behaviour without a row here is not certified (ADR-0022).
#
# Usage: resolve-core-artifact-conformance.sh <path-to-resolve-core-artifact.sh>
set -uo pipefail


# ── target screening (capability: conformance-harness-reporting) ─────────────
# SINGLE-TARGET shape: this harness takes exactly one target and ABORTS on one
# it cannot use, rather than counting a failure row and continuing. That is
# conformant — the rule is "never exit 0 having scored nothing", and an abort
# before any row satisfies it. Preserved deliberately; changing it would churn
# a tool that is already correct.
#
# What was missing is the REASON. `[ -f ]` alone reported every unscoreable
# target as "not found", including directories, empty files and unreadable
# ones — so an operator was told the wrong thing about three of the four cases.
harness_screen_target() { # $1 = path; sets REASON, returns 1 if unscoreable
  REASON=""
  if [ -L "$1" ] && [ ! -e "$1" ]; then REASON="not a regular file (dangling symlink)"; return 1; fi
  if [ ! -e "$1" ]; then REASON="not found"; return 1; fi
  if [ ! -f "$1" ]; then REASON="not a regular file"; return 1; fi
  if [ ! -s "$1" ]; then REASON="empty"; return 1; fi
  if [ ! -r "$1" ]; then REASON="unreadable"; return 1; fi
  return 0
}

# A path is attacker-influenceable in the general case; output that can be
# forged with an embedded newline can be made to print a line reading like PASS.
harness_safe_label() { # $1 = path
  printf '%s' "$1" | LC_ALL=C tr -c '[:print:]' '?'
}

RESOLVER="${1:-}"
[ -n "$RESOLVER" ] || { echo "usage: $0 <path-to-resolve-core-artifact.sh>" >&2; exit 2; }
harness_screen_target "$RESOLVER" || {
  echo "  UNSCOREABLE  $(harness_safe_label "$RESOLVER") — $REASON" >&2
  exit 2
}

CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
FX="$(mktemp -d "${TMPDIR:-/tmp}/rca-fx.XXXXXX")"
trap 'rm -rf "$FX"' EXIT

sha_of() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || sha256sum "$1" | awk '{print $1}'; }

SHA="$(git -C "$CORE" rev-parse HEAD)"
GATE_CORE_PATH=reference-implementations/openspec-change-gate/openspec-change-gate.sh
git -C "$CORE" show "${SHA}:${GATE_CORE_PATH}" > "$FX/gate.real"
GATE_SHA="$(sha_of "$FX/gate.real")"

mk_manifest() { # $1=dest $2=commit $3=sha256
  printf 'core_repo=agenticapps-eu/agenticapps-workflow-core\ncore_commit=%s\nfile=bin/openspec-change-gate.sh sha256=%s\n' "$2" "$3" > "$1"
}

# Reporting goes to stdout; the resolved path is left in $ROW_OUT. Returning
# both on stdout conflated the PASS line with the value and made the first
# assertion compare a hash of the wrong thing.
ROW_OUT=""
row() { # $1=desc $2=want-exit $3=manifest $4=logical  [env passed by caller]
  local desc="$1" want="$2" man="$3" log="$4"
  local out rc
  out="$(CORE_CHECKOUT="$CORE" CORE_OFFLINE="${CORE_OFFLINE:-1}" \
        bash "$RESOLVER" "$man" "$log" 2>/dev/null)"; rc=$?
  ROW_OUT="$out"
  if [ "$rc" = "$want" ]; then
    echo "  PASS  $desc (exit $rc)"; pass=$((pass+1))
  else
    echo "  FAIL  $desc — expected $want, got $rc"; fail=$((fail+1))
  fi
}

echo "═══ $RESOLVER"
echo "  ── A. Resolve and verify ──"

mk_manifest "$FX/ok.manifest" "$SHA" "$GATE_SHA"
row "pinned file resolves from a local checkout" 0 "$FX/ok.manifest" bin/openspec-change-gate.sh
got="$ROW_OUT"
if [ -n "$got" ] && [ -f "$got" ] && [ "$(sha_of "$got")" = "$GATE_SHA" ]; then
  echo "  PASS  resolved bytes hash to the pin"; pass=$((pass+1))
else
  echo "  FAIL  resolved bytes do not hash to the pin"; fail=$((fail+1))
fi
rm -f "$got"

echo "  ── B. Fail closed ──"
# The whole trust model. Bytes that do not match the pin must never be emitted,
# whatever produced them.
mk_manifest "$FX/badhash.manifest" "$SHA" "0000000000000000000000000000000000000000000000000000000000000000"
row "hash mismatch -> exit 4, no output" 4 "$FX/badhash.manifest" bin/openspec-change-gate.sh
[ -z "$ROW_OUT" ] && { echo "  PASS  mismatch emitted no path"; pass=$((pass+1)); } || { echo "  FAIL  mismatch still emitted a path"; fail=$((fail+1)); }

# An unpinned file is not resolvable at any price — otherwise a manifest could
# be silently extended by whoever controls the source.
mk_manifest "$FX/ok2.manifest" "$SHA" "$GATE_SHA"
row "file absent from manifest -> exit 2" 2 "$FX/ok2.manifest" bin/not-pinned.sh

# A short sha is ambiguous and can be made to collide far more cheaply than a
# full one; a pin that accepts it is not a pin.
mk_manifest "$FX/short.manifest" "abc1234" "$GATE_SHA"
row "abbreviated core_commit -> exit 2" 2 "$FX/short.manifest" bin/openspec-change-gate.sh

mk_manifest "$FX/nonhex.manifest" "not-a-sha-at-all-------------------------" "$GATE_SHA"
row "non-hex core_commit -> exit 2" 2 "$FX/nonhex.manifest" bin/openspec-change-gate.sh

printf 'core_repo=x/y\n' > "$FX/nocommit.manifest"
row "manifest without core_commit -> exit 2" 2 "$FX/nocommit.manifest" bin/openspec-change-gate.sh

row "missing manifest file -> exit 2" 2 "$FX/does-not-exist.manifest" bin/openspec-change-gate.sh

# Offline with no local source must fail rather than reach the network.
mk_manifest "$FX/unknown.manifest" "0000000000000000000000000000000000000000" "$GATE_SHA"
row "unknown commit, offline -> exit 3" 3 "$FX/unknown.manifest" bin/openspec-change-gate.sh

echo "  ── C. Pin semantics ──"
# A pin names a COMMIT. Reading the checkout's worktree instead would resolve
# whatever the developer has open — the opposite of reproducible.
cp "$CORE/$GATE_CORE_PATH" "$FX/gate.backup"
printf '\n# LOCAL UNCOMMITTED EDIT\n' >> "$CORE/$GATE_CORE_PATH"
mk_manifest "$FX/ok3.manifest" "$SHA" "$GATE_SHA"
row "dirty worktree does not affect the resolve" 0 "$FX/ok3.manifest" bin/openspec-change-gate.sh
got="$ROW_OUT"
if [ -n "$got" ] && ! grep -q 'LOCAL UNCOMMITTED EDIT' "$got" 2>/dev/null; then
  echo "  PASS  resolved the pinned commit, not the working tree"; pass=$((pass+1))
else
  echo "  FAIL  resolved the working tree instead of the pinned commit"; fail=$((fail+1))
fi
cp "$FX/gate.backup" "$CORE/$GATE_CORE_PATH"
rm -f "$got"

echo "  ── D. Version marker ──"
if grep -qE '^# resolve-core-artifact-version: [0-9]+\.[0-9]+\.[0-9]+' "$RESOLVER"; then
  echo "  PASS  carries # resolve-core-artifact-version:"; pass=$((pass+1))
else
  echo "  FAIL  no version marker — installers treat this as 0.0.0"; fail=$((fail+1))
fi

echo ""
echo "═══ TOTAL: $pass passed, $fail failed"
# Backstop, folded into the one place the exit code is computed. This harness
# aborts before any row on an unscoreable target, so it is normally unreachable
# — it exists because every instance of this defect so far arrived by a route
# the previous fix did not anticipate, and a scored total of zero is the
# observable every route shares.
if [ $((pass + fail)) -eq 0 ]; then
  echo "openspec-conformance: certified NOTHING — no row reached a verdict" >&2
  exit 1
fi
[ "$fail" -eq 0 ]
