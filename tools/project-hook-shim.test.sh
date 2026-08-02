#!/usr/bin/env bash
# project-hook-shim.test.sh — the shim contract, test-first.
#
# Covers change tasks 2.2, 2.3, 2.4, 2.5, 2.6, 2.8, 2.11c — all marked
# tdd="true". Written and observed RED before shim-template.sh existed.
#
# The shim is driven through its public interface: a tool payload on stdin, an
# override variable in the environment, and an exit code out. Nothing here
# reaches into its internals.
#
# Usage: tools/project-hook-shim.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$ROOT/reference-implementations/project-hooks/shim-template.sh"

pass=0
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()   { echo "  PASS  $1"; pass=$((pass + 1)); }
bad()  { echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; fail=$((fail + 1)); }

# Several assertions below are satisfied trivially when there is no template —
# "does not block" and "does not fall through" both hold of a file that cannot
# execute. Without this guard the suite would go green the day someone deletes
# the template. Fail loudly instead of vacuously.
if [ ! -f "$TEMPLATE" ]; then
  echo "  FAIL  precondition: shim template not found at $TEMPLATE"
  echo "        Every assertion below would pass vacuously. Refusing to run."
  exit 1
fi

# Materialise a shim for hook $1 into $TMP/shim-$1.sh by instantiating the
# template exactly as the rollout does: substitute the hook name, nothing else.
# A shim that needs more than a name substitution is not a template.
make_shim() {
  # Two statements: bash expands every word of a `local` before assigning any of
  # them, so `local hook="$1" out="...$hook..."` reads $hook while still unset.
  local hook="$1"
  local out="$TMP/shim-$hook.sh"
  sed "s/@@HOOK@@/$hook/g" "$TEMPLATE" > "$out"
  chmod +x "$out"
  printf '%s' "$out"
}

# Run a shim with a controlled environment. All state the shim may touch is
# redirected into $TMP so the suite never reads or writes the real machine.
# The shared install is reached through $HOME rather than a dedicated variable:
# adding one purely for the tests would add a second kill switch to the very
# surface the README documents as the hooks' weakest point.
#   $1 = shim path, $2 = stdin payload, rest = VAR=VAL assignments
run_shim() {
  local shim="$1" payload="$2"; shift 2
  env -i PATH="$PATH" HOME="$TMP/home" \
      XDG_STATE_HOME="$TMP/state" \
      "$@" \
      "$shim" <<<"$payload" 2>"$TMP/err"
}

PAYLOAD='{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'

mkdir -p "$TMP/home/.agenticapps/bin" "$TMP/state"
BIN="$TMP/home/.agenticapps/bin"

# A stand-in implementation that proves it received the payload intact and that
# its own exit code is what the caller sees.
cat > "$TMP/impl-echo.sh" <<'EOF'
#!/usr/bin/env bash
cat > "$IMPL_SAW"
exit "${IMPL_EXIT:-0}"
EOF
chmod +x "$TMP/impl-echo.sh"

echo "=== 2.2 / 2.3  unresolvable shim reports and allows ==="

SHIM=$(make_shim database-sentinel)

rm -f "$BIN/database-sentinel.sh"
rm -rf "$TMP/state"; mkdir -p "$TMP/state"
run_shim "$SHIM" "$PAYLOAD"; rc=$?
if [ "$rc" -eq 1 ]; then
  ok "unresolvable shim exits 1 (non-blocking error), not 0"
else
  bad "unresolvable shim exits 1 (non-blocking error), not 0" "got exit $rc"
fi
if grep -qi 'database-sentinel' "$TMP/err" && grep -qiE 'not (installed|found)|unresolv|install' "$TMP/err"; then
  ok "unresolvable shim names the hook and the remedy on stderr"
else
  bad "unresolvable shim names the hook and the remedy on stderr" "stderr: $(head -2 "$TMP/err")"
fi

echo
echo "=== 2.4  an unresolvable database-sentinel blocks nothing ==="
# The regression the withdrawn fail-closed design would have caused: the hook is
# registered on Bash|Edit|Write|MultiEdit, so blocking on unresolvable blocks
# every command and every edit in the repo.
for p in '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' \
         '{"tool_name":"Edit","tool_input":{"file_path":"src/index.ts"}}' \
         '{"tool_name":"Write","tool_input":{"file_path":"README.md"}}'; do
  rm -rf "$TMP/state"; mkdir -p "$TMP/state"
  run_shim "$SHIM" "$p"; rc=$?
  tool=$(printf '%s' "$p" | sed 's/.*"tool_name":"\([A-Za-z]*\)".*/\1/')
  if [ "$rc" -ne 2 ]; then
    ok "unresolvable shim does not block $tool (exit $rc, not 2)"
  else
    bad "unresolvable shim does not block $tool" "got exit 2 — this is the fail-closed regression"
  fi
done

echo
echo "=== 2.5  an explicit override wins over the shared install ==="
cat > "$BIN/database-sentinel.sh" <<'EOF'
#!/usr/bin/env bash
echo SHARED > "$IMPL_SAW"; exit 0
EOF
chmod +x "$BIN/database-sentinel.sh"
cat > "$TMP/override-ok.sh" <<'EOF'
#!/usr/bin/env bash
echo OVERRIDE > "$IMPL_SAW"; exit 0
EOF
chmod +x "$TMP/override-ok.sh"

run_shim "$SHIM" "$PAYLOAD" IMPL_SAW="$TMP/saw" \
  DATABASE_SENTINEL_OVERRIDE="$TMP/override-ok.sh"
if [ "$(cat "$TMP/saw" 2>/dev/null)" = "OVERRIDE" ]; then
  ok "override is preferred over the shared install"
else
  bad "override is preferred over the shared install" "implementation reached: $(cat "$TMP/saw" 2>/dev/null)"
fi

# And with no override the shared install is what runs.
rm -f "$TMP/saw"
run_shim "$SHIM" "$PAYLOAD" IMPL_SAW="$TMP/saw"
if [ "$(cat "$TMP/saw" 2>/dev/null)" = "SHARED" ]; then
  ok "with no override, the shared install runs"
else
  bad "with no override, the shared install runs" "implementation reached: $(cat "$TMP/saw" 2>/dev/null)"
fi

echo
echo "=== 2.6  an unusable override reports specifically, allows, and does NOT fall through ==="
# The shared install is present and working throughout this block. A shim that
# falls through would run it and the test could not tell the two paths apart.
for case in missing nonexec; do
  case "$case" in
    missing) OV="$TMP/does-not-exist.sh" ;;
    nonexec) OV="$TMP/not-executable.sh"; echo '#!/bin/sh' > "$OV"; chmod 644 "$OV" ;;
  esac
  rm -f "$TMP/saw"; rm -rf "$TMP/state"; mkdir -p "$TMP/state"
  run_shim "$SHIM" "$PAYLOAD" IMPL_SAW="$TMP/saw" DATABASE_SENTINEL_OVERRIDE="$OV"; rc=$?

  [ "$rc" -eq 1 ] && ok "override $case: exits 1" \
                  || bad "override $case: exits 1" "got exit $rc"
  [ "$rc" -ne 2 ] && ok "override $case: does not block" \
                  || bad "override $case: does not block" "got exit 2"
  if [ ! -f "$TMP/saw" ]; then
    ok "override $case: does not fall through to the shared install"
  else
    bad "override $case: does not fall through to the shared install" \
        "the shared install ran anyway ($(cat "$TMP/saw"))"
  fi
  if grep -qi 'override' "$TMP/err" && grep -qF "$OV" "$TMP/err"; then
    ok "override $case: reports the override specifically, naming the path"
  else
    bad "override $case: reports the override specifically, naming the path" \
        "stderr: $(head -2 "$TMP/err")"
  fi
done

echo
echo "=== 2.11c  the invalid-override report is NOT rate limited; the unresolvable one is ==="
# One repetition policy governing both would let a rate limit adopted to quiet
# the benign condition silence the kill switch — the only signal that a hook is
# switched off on an otherwise healthy machine.
rm -rf "$TMP/state"; mkdir -p "$TMP/state"
n=0
for i in 1 2 3; do
  run_shim "$SHIM" "$PAYLOAD" DATABASE_SENTINEL_OVERRIDE="$TMP/does-not-exist.sh" || true
  grep -qi 'override' "$TMP/err" && n=$((n + 1))
done
[ "$n" -eq 3 ] && ok "invalid-override reports on every invocation (3/3)" \
              || bad "invalid-override reports on every invocation" "reported $n/3"

rm -f "$BIN/database-sentinel.sh"
rm -rf "$TMP/state"; mkdir -p "$TMP/state"
n=0
for i in 1 2 3; do
  run_shim "$SHIM" "$PAYLOAD" || true
  [ -s "$TMP/err" ] && n=$((n + 1))
done
[ "$n" -eq 1 ] && ok "unresolvable-implementation report is rate limited (1/3)" \
              || bad "unresolvable-implementation report is rate limited (1/3)" "reported $n/3"

echo
echo "=== 2.8  behaviour-free: stdin reaches the implementation untouched ==="
cp "$TMP/impl-echo.sh" "$BIN/database-sentinel.sh"
rm -f "$TMP/saw"
BIG='{"session_id":"s9","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"/x","tool_use_id":"toolu_1"}'
run_shim "$SHIM" "$BIG" IMPL_SAW="$TMP/saw"
if [ "$(cat "$TMP/saw" 2>/dev/null)" = "$BIG" ]; then
  ok "the implementation receives the payload byte-for-byte"
else
  bad "the implementation receives the payload byte-for-byte" \
      "sent: $BIG" "saw:  $(cat "$TMP/saw" 2>/dev/null)"
fi

# The shim must not decide anything from the payload — same shim, a payload the
# implementation would block, and the shim still just hands over.
IMPL_EXIT_TEST=$(run_shim "$SHIM" "$BIG" IMPL_SAW="$TMP/saw" IMPL_EXIT=2; echo $?)
[ "$IMPL_EXIT_TEST" -eq 2 ] && ok "the implementation's exit code is passed through unchanged" \
                            || bad "the implementation's exit code is passed through unchanged" "got $IMPL_EXIT_TEST"

if grep -qE 'tool_name|tool_input|file_path|jq[[:space:]]|\.command' "$TEMPLATE"; then
  bad "the shim inspects no tool payload" "template references payload fields:" \
      "$(grep -nE 'tool_name|tool_input|file_path|jq[[:space:]]|\.command' "$TEMPLATE" | head -3)"
else
  ok "the shim inspects no tool payload"
fi

echo
echo "=== 2.9  the shim carries a contract version marker ==="
if head -10 "$TEMPLATE" | grep -qE '^# shim-contract: [0-9]+\.[0-9]+\.[0-9]+$'; then
  ok "template carries '# shim-contract: <semver>' within the first 10 lines"
else
  bad "template carries '# shim-contract: <semver>' within the first 10 lines" \
      "head -10: $(head -10 "$TEMPLATE" | grep -c .) lines, no match"
fi

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
