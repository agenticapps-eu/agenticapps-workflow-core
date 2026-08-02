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
for case in missing nonexec directory; do
  case "$case" in
    missing) OV="$TMP/does-not-exist.sh" ;;
    nonexec) OV="$TMP/not-executable.sh"; echo '#!/bin/sh' > "$OV"; chmod 644 "$OV" ;;
    # STAGE-2 FINDING 6. `-x` on a directory tests the SEARCH bit, and every
    # ordinary directory has it — so a gate written `[ -x "$OVERRIDE" ]` calls a
    # directory executable and `exec`s it. bash then exits 126 with its own "is a
    # directory" message, the invalid-override report never fires, and the exit
    # code is not the 1 this contract states. The contract has always said
    # executable regular FILE; the test that would have caught the gap is this
    # one, and it did not exist.
    #
    # The fixture is NOT named `override-dir`. It was, and the "reports the
    # override, naming the path" assertion below then passed while the shim was
    # still broken: bash's own `.../override-dir: is a directory` message
    # contains both the word and the path, so the grep matched the failure it
    # was supposed to catch. A neutral name is what makes that assertion mean
    # anything.
    directory) OV="$TMP/plain-subdir"; mkdir -p "$OV" ;;
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
echo "=== 2.6a  an override set to the EMPTY STRING is treated as unset ==="
# RECORDED DECISION, not an oversight (Stage-2 finding 6, second half). The
# contract says an override that is "set" but unusable must not fall through, and
# `FOO=` is set as far as the shell is concerned. It still falls through here,
# because `FOO=` is the conventional way to neutralise a variable — it is how an
# operator says "no override", not how they name a broken one. Reporting it as an
# invalid override would make the ordinary way of clearing the kill switch print
# an error on every matched call.
#
# The reading of the requirement is therefore: "set" means set to a NON-EMPTY
# value. It was a decision either way, and the finding's real complaint was that
# nothing wrote it down. This assertion is where it is written down — behaviour
# nothing asserts is behaviour nobody chose.
cat > "$BIN/database-sentinel.sh" <<'EOF'
#!/usr/bin/env bash
echo SHARED > "$IMPL_SAW"; exit 0
EOF
chmod +x "$BIN/database-sentinel.sh"
rm -f "$TMP/saw"; rm -rf "$TMP/state"; mkdir -p "$TMP/state"
run_shim "$SHIM" "$PAYLOAD" IMPL_SAW="$TMP/saw" DATABASE_SENTINEL_OVERRIDE=; rc=$?
if [ "$(cat "$TMP/saw" 2>/dev/null)" = "SHARED" ] && [ "$rc" -eq 0 ]; then
  ok "an empty override falls through to the shared install, silently"
else
  bad "an empty override falls through to the shared install, silently" \
      "exit $rc, implementation reached: $(cat "$TMP/saw" 2>/dev/null)"
fi
if grep -qi 'override' "$TMP/err"; then
  bad "an empty override reports nothing" "stderr: $(head -2 "$TMP/err")"
else
  ok "an empty override reports nothing"
fi

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
h0=$(( $(date +%s) / 3600 ))
n=0
for i in 1 2 3; do
  run_shim "$SHIM" "$PAYLOAD" || true
  [ -s "$TMP/err" ] && n=$((n + 1))
done
h1=$(( $(date +%s) / 3600 ))
if [ "$h0" -ne "$h1" ]; then
  # The policy is once per hour; a run straddling the boundary legitimately
  # reports twice. Say so rather than failing or silently accepting 2.
  echo "  SKIP  unresolvable-implementation report is rate limited — run crossed an hour boundary"
elif [ "$n" -eq 1 ]; then
  ok "unresolvable-implementation report is rate limited (1/3)"
else
  bad "unresolvable-implementation report is rate limited (1/3)" "reported $n/3"
fi

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

# REGRESSION. normalize-claude-md is registered as
#   .../normalize-claude-md.sh "$CLAUDE_PROJECT_DIR/CLAUDE.md"
# so the hook is invoked WITH an argument, and the implementation falls back to
# ./CLAUDE.md relative to CWD when it does not get one — reporting "input not
# found" and doing nothing. A shim that execs without "$@" therefore turns the
# hook into a silent no-op in every repo that binds it.
#
# This is the same defect as PR #59, where the change-gate wrapper discarded its
# arguments and made --ci a silent green. Caught here by the rollout, not by the
# suite, which is why it is now in the suite.
cat > "$BIN/database-sentinel.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s' "$*" > "$IMPL_SAW"
EOF
chmod +x "$BIN/database-sentinel.sh"
rm -f "$TMP/saw"
run_shim "$SHIM" "$PAYLOAD" IMPL_SAW="$TMP/saw" -- /project/CLAUDE.md >/dev/null 2>&1 || true
env -i PATH="$PATH" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" IMPL_SAW="$TMP/saw" \
    "$SHIM" /project/CLAUDE.md <<<"$PAYLOAD" >/dev/null 2>&1 || true
if [ "$(cat "$TMP/saw" 2>/dev/null)" = "/project/CLAUDE.md" ]; then
  ok "the shim forwards its arguments to the implementation"
else
  bad "the shim forwards its arguments to the implementation" \
      "the implementation saw: '$(cat "$TMP/saw" 2>/dev/null)'" \
      "a dropped argv makes normalize-claude-md a silent no-op (cf. PR #59)"
fi
cp "$TMP/impl-echo.sh" "$BIN/database-sentinel.sh"

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
echo "=== 4b  the gate shim is a sibling of the template, not a render of it ==="
# It is hand-maintained — the two must be edited together — and until now nothing
# drove it at all. Every assertion above was made of the template only, so the
# file carrying the §18 gate's one blocking condition had no coverage of the
# resolution order it implements. Finding 6 landed in both files for exactly that
# reason: the template's assertions could not reach the sibling.
GATE_SHIM="$TMP/openspec-change-gate.sh"
cp "$ROOT/reference-implementations/project-hooks/openspec-change-gate.shim.sh" "$GATE_SHIM"
chmod +x "$GATE_SHIM"

cat > "$BIN/openspec-change-gate.sh" <<'EOF'
#!/usr/bin/env bash
echo SHARED > "$IMPL_SAW"; exit 0
EOF
chmod +x "$BIN/openspec-change-gate.sh"

for case in missing nonexec directory; do
  case "$case" in
    missing)   OV="$TMP/no-such-gate.sh" ;;
    nonexec)   OV="$TMP/gate-not-executable.sh"; echo '#!/bin/sh' > "$OV"; chmod 644 "$OV" ;;
    directory) OV="$TMP/gate-plain-subdir"; mkdir -p "$OV" ;;   # neutral name — see above
  esac
  rm -f "$TMP/saw"; rm -rf "$TMP/state"; mkdir -p "$TMP/state"
  run_shim "$GATE_SHIM" "$PAYLOAD" IMPL_SAW="$TMP/saw" OPENSPEC_GATE="$OV"; rc=$?

  [ "$rc" -eq 1 ] && ok "gate shim, override $case: exits 1" \
                  || bad "gate shim, override $case: exits 1" "got exit $rc"
  [ "$rc" -ne 2 ] && ok "gate shim, override $case: does not block" \
                  || bad "gate shim, override $case: does not block" "got exit 2"
  if [ ! -f "$TMP/saw" ]; then
    ok "gate shim, override $case: does not fall through to the shared install"
  else
    bad "gate shim, override $case: does not fall through to the shared install" \
        "the shared install ran anyway ($(cat "$TMP/saw"))"
  fi
  if grep -qi 'OPENSPEC_GATE' "$TMP/err" && grep -qF "$OV" "$TMP/err"; then
    ok "gate shim, override $case: reports the override specifically, naming the path"
  else
    bad "gate shim, override $case: reports the override specifically, naming the path" \
        "stderr: $(head -2 "$TMP/err")"
  fi
done

# And the two candidates it does resolve, in order.
rm -f "$TMP/saw"
cat > "$TMP/gate-override-ok.sh" <<'EOF'
#!/usr/bin/env bash
echo OVERRIDE > "$IMPL_SAW"; exit 0
EOF
chmod +x "$TMP/gate-override-ok.sh"
run_shim "$GATE_SHIM" "$PAYLOAD" IMPL_SAW="$TMP/saw" OPENSPEC_GATE="$TMP/gate-override-ok.sh"
[ "$(cat "$TMP/saw" 2>/dev/null)" = "OVERRIDE" ] \
  && ok "gate shim: a usable override is preferred over the shared install" \
  || bad "gate shim: a usable override is preferred over the shared install" \
         "implementation reached: $(cat "$TMP/saw" 2>/dev/null)"

rm -f "$TMP/saw"
run_shim "$GATE_SHIM" "$PAYLOAD" IMPL_SAW="$TMP/saw"
[ "$(cat "$TMP/saw" 2>/dev/null)" = "SHARED" ] \
  && ok "gate shim: with no override, the shared install runs" \
  || bad "gate shim: with no override, the shared install runs" \
         "implementation reached: $(cat "$TMP/saw" 2>/dev/null)"

# The two files carry the same contract and must be bumped together. A sibling
# left behind is the drift the marker exists to surface, and it would surface it
# in the fleet rather than here.
TPL_V=$(head -10 "$TEMPLATE" | grep -m1 '^# shim-contract:' | awk '{print $3}')
GATE_V=$(head -10 "$ROOT/reference-implementations/project-hooks/openspec-change-gate.shim.sh" \
         | grep -m1 '^# shim-contract:' | awk '{print $3}')
CORE_V=$(head -10 "$ROOT/.claude/hooks/openspec-change-gate.sh" \
         | grep -m1 '^# shim-contract:' | awk '{print $3}')
if [ -n "$TPL_V" ] && [ "$TPL_V" = "$GATE_V" ] && [ "$TPL_V" = "$CORE_V" ]; then
  ok "template, gate shim and core's self-hosting binder all carry $TPL_V"
else
  bad "template, gate shim and core's self-hosting binder all carry one contract version" \
      "template=$TPL_V  gate-shim=$GATE_V  core-binder=$CORE_V"
fi

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
