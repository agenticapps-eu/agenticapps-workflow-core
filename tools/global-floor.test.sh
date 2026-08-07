#!/usr/bin/env bash
# global-floor.test.sh — the machine-level pre-commit dispatcher's contract.
#
# Covers change one-enforcement-floor tasks 2.5, 2.6, 2.7, 2.8a, 6.9, 6.9a and
# 6.10. Written and observed RED before
# reference-implementations/global-floor/pre-commit existed.
#
# WHY A NEW ARTIFACT RATHER THAN THE EXISTING pre-commit
#
# reference-implementations/openspec-change-gate/pre-commit resolves its gate as
#
#   [ -x "$GATE" ] || GATE="$(git rev-parse --show-toplevel)/bin/openspec-change-gate.sh"
#
# which is a fallback into the repository being committed to. That is correct
# for a hook a repository installs for itself and forbidden for one bound
# machine-wide: it would make every clone on the machine able to supply the
# executable that runs at commit time. Task 2.7 states the prohibition; the
# `does not exec repository-controlled code` case below is its negative test.
#
# ISOLATION
#
# Task 6.8 requires a per-case HOME *and* a per-case git config. Both are set
# for every case. A case that leaked would rebind the operator's real machine,
# so the guard below refuses to run if GIT_CONFIG_GLOBAL is not isolated.
#
# The gate is DOUBLED, never the real one. These cases are about the
# dispatcher's behaviour — what it runs, in what order, and which exit status it
# propagates. Shelling out to the real gate would assert on that tool instead.
#
# Usage: tools/global-floor.test.sh
#   GLOBAL_FLOOR_BIN=/usr/bin/true tools/global-floor.test.sh
#     (/usr/bin/true, not /bin/true — the latter does not exist on macOS)
#     Points the suite at a deliberately wrong implementation. Assertions below
#     MUST fail under it — that is how this file proves it has teeth.
#
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="${GLOBAL_FLOOR_BIN:-$ROOT/reference-implementations/global-floor/pre-commit}"

# Normative and spelled out here rather than read from the implementation: a
# test that sourced this from the thing under test would agree with it whatever
# it said.
ENROL_KEY='agenticapps.workflow.enrolled'

pass=0
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; fail=$((fail + 1)); }

# Most assertions here are about a hook that declines to act — "exits 0",
# "does not invoke the gate", "runs nothing". Every one is satisfied vacuously
# by a script that does not exist, because a missing command exits 127 and runs
# nothing. Without this guard the suite reports a clean run against an empty
# repository.
if [ ! -x "$HOOK" ]; then
  echo "  FAIL  precondition: dispatcher not executable at $HOOK"
  echo "        Refusing to run: the decline assertions would pass vacuously."
  echo "        This is the expected RED while the implementation does not exist."
  exit 1
fi

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
# Each case gets its own HOME, its own git config, its own repository and its
# own published hooks directory. `dirname "$0"` is how the dispatcher finds its
# own hooks.d, so the published directory must be real per case.

CASE_N=0
setup_case() {
  CASE_N=$((CASE_N + 1))
  CASE="$TMP/case$CASE_N"
  export HOME="$CASE/home"
  export GIT_CONFIG_GLOBAL="$CASE/home/.gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
  HOOKDIR="$CASE/home/.agenticapps/git-hooks"
  REPO="$CASE/repo"
  TRACE="$CASE/trace"
  mkdir -p "$HOME" "$HOOKDIR" "$REPO"
  : > "$GIT_CONFIG_GLOBAL"
  : > "$TRACE"

  cp "$HOOK" "$HOOKDIR/pre-commit"
  chmod +x "$HOOKDIR/pre-commit"

  # The doubled gate. Records that it ran, then exits with whatever
  # $CASE/gate-rc says, so a case can choose the gate's verdict.
  mkdir -p "$HOME/.agenticapps/bin"
  cat > "$HOME/.agenticapps/bin/openspec-change-gate.sh" <<EOF
#!/usr/bin/env bash
echo "gate ran" >> "$TRACE"
exit \$(cat "$CASE/gate-rc" 2>/dev/null || echo 0)
EOF
  chmod +x "$HOME/.agenticapps/bin/openspec-change-gate.sh"
  echo 0 > "$CASE/gate-rc"

  git -C "$REPO" init -q .
  git -C "$REPO" config user.email t@t
  git -C "$REPO" config user.name t
}

# Guard: never let a case touch the operator's real configuration.
assert_isolated() {
  case "$GIT_CONFIG_GLOBAL" in
    "$TMP"/*) ;;
    *) echo "  FAIL  isolation: GIT_CONFIG_GLOBAL escaped the sandbox"; exit 1 ;;
  esac
}

enrol()      { git -C "$REPO" config "$ENROL_KEY" true; }
stage_code() { echo "function f(){}" > "$REPO/app.js"; git -C "$REPO" add -A; }

# Run the dispatcher the way git runs it: cwd inside the repo, hook invoked by
# its published path.
run_hook() {
  ( cd "$REPO" && "$HOOKDIR/pre-commit" >"$CASE/out" 2>&1 ); echo $?
}

traced()     { grep -qF "$1" "$TRACE" 2>/dev/null; }

echo
echo "global-floor dispatcher — enrolment predicate (task 2.8a)"

# --- an unenrolled repository is left alone --------------------------------
setup_case; assert_isolated
stage_code
rc=$(run_hook)
if [ "$rc" != 0 ]; then
  bad "an unenrolled repository exits 0" "exit was $rc"
elif traced "gate ran"; then
  bad "an unenrolled repository does not invoke the gate" "the gate ran anyway"
elif [ -s "$CASE/out" ]; then
  bad "an unenrolled repository produces no output" "output: $(cat "$CASE/out")"
else
  ok "an unenrolled repository exits 0, silently, without invoking the gate"
fi

# --- the marker is what decides, not the presence of openspec/ -------------
setup_case; assert_isolated
mkdir -p "$REPO/openspec/changes/bogus"
echo 'not a valid delta' > "$REPO/openspec/changes/bogus/proposal.md"
echo 1 > "$CASE/gate-rc"   # the gate would block if it were consulted
stage_code
rc=$(run_hook)
if [ "$rc" != 0 ]; then
  bad "an unenrolled repository carrying openspec/ still exits 0" "exit was $rc"
elif traced "gate ran"; then
  bad "an unenrolled repository carrying openspec/ does not invoke the gate" \
      "the gate ran — the predicate is keying off openspec/ rather than the marker"
else
  ok "an unenrolled repository carrying a malformed openspec/ tree commits"
fi

# --- an enrolled repository is gated ---------------------------------------
setup_case; assert_isolated
enrol; echo 1 > "$CASE/gate-rc"; stage_code
rc=$(run_hook)
if [ "$rc" = 0 ]; then
  bad "an enrolled repository is gated" "the hook exited 0 while the gate failed"
elif ! traced "gate ran"; then
  bad "an enrolled repository invokes the gate" "the gate never ran"
else
  ok "an enrolled repository is gated and the failure propagates"
fi

echo
echo "global-floor dispatcher — gate dispatch (tasks 2.5)"

# --- exit status is propagated, not collapsed ------------------------------
setup_case; assert_isolated
enrol; echo 3 > "$CASE/gate-rc"; stage_code
rc=$(run_hook)
if [ "$rc" != 3 ]; then
  bad "the gate's exit status is propagated verbatim" \
      "gate exited 3, dispatcher exited $rc" \
      "collapsing every failure to 1 loses the gate's own distinctions"
else
  ok "the gate's exit status is propagated verbatim"
fi

# --- a green gate lets the commit through ----------------------------------
setup_case; assert_isolated
enrol; stage_code
rc=$(run_hook)
if [ "$rc" != 0 ]; then
  bad "a green gate exits 0" "exit was $rc: $(cat "$CASE/out")"
else
  ok "a green gate exits 0"
fi

echo
echo "global-floor dispatcher — repository-controlled code (tasks 2.7, 6.10)"

# --- the repository's own hook is never executed ---------------------------
setup_case; assert_isolated
enrol
mkdir -p "$REPO/.git/hooks"
cat > "$REPO/.git/hooks/pre-commit" <<EOF
#!/usr/bin/env bash
echo "repo hook ran" >> "$TRACE"
exit 0
EOF
chmod +x "$REPO/.git/hooks/pre-commit"
stage_code
run_hook >/dev/null
if traced "repo hook ran"; then
  bad "the dispatcher does not exec the repository's .git/hooks/pre-commit" \
      "it ran — a global hook that falls back to repository-controlled code" \
      "makes every clone on the machine executable at commit time"
else
  ok "the repository's own .git/hooks/pre-commit is not executed"
fi

# --- a repository-supplied gate is never resolved --------------------------
setup_case; assert_isolated
enrol
mkdir -p "$REPO/bin"
cat > "$REPO/bin/openspec-change-gate.sh" <<EOF
#!/usr/bin/env bash
echo "repo gate ran" >> "$TRACE"
exit 0
EOF
chmod +x "$REPO/bin/openspec-change-gate.sh"
rm -f "$HOME/.agenticapps/bin/openspec-change-gate.sh"   # force the fallback
stage_code
run_hook >/dev/null
if traced "repo gate ran"; then
  bad "the dispatcher does not fall back to a repository-supplied gate" \
      "it ran <repo>/bin/openspec-change-gate.sh — this is the fallback the" \
      "per-repository hook has and the machine-level one must not"
else
  ok "an absent machine gate does not fall back into the repository"
fi

echo
echo "global-floor dispatcher — hooks.d composition (tasks 2.6, 6.9)"

# --- entries run, in order -------------------------------------------------
setup_case; assert_isolated
enrol; mkdir -p "$HOOKDIR/hooks.d"
for n in 10-first 20-second; do
  printf '#!/usr/bin/env bash\necho "%s ran" >> "%s"\nexit 0\n' "$n" "$TRACE" \
    > "$HOOKDIR/hooks.d/$n"
  chmod +x "$HOOKDIR/hooks.d/$n"
done
stage_code
rc=$(run_hook)
if [ "$rc" != 0 ]; then
  bad "hooks.d entries run and a clean run exits 0" "exit was $rc"
elif ! traced "10-first ran" || ! traced "20-second ran"; then
  bad "every hooks.d entry runs" "trace: $(tr '\n' ' ' < "$TRACE")"
# Compare the two entries' positions directly. An earlier revision grepped for
# 'ran' and indexed into the result, which also matched the gate's own trace
# line and asserted against the wrong one.
elif [ "$(grep -n '^10-first ran$'  "$TRACE" | cut -d: -f1)" -gt \
        "$(grep -n '^20-second ran$' "$TRACE" | cut -d: -f1)" ]; then
  bad "hooks.d entries run in lexical order" "trace: $(tr '\n' ' ' < "$TRACE")"
else
  ok "hooks.d entries run in lexical order and a clean run exits 0"
fi

# --- the first non-zero entry fails the commit, and stops the rest ---------
setup_case; assert_isolated
enrol; mkdir -p "$HOOKDIR/hooks.d"
printf '#!/usr/bin/env bash\necho "10-fails ran" >> "%s"\nexit 7\n' "$TRACE" \
  > "$HOOKDIR/hooks.d/10-fails"
printf '#!/usr/bin/env bash\necho "20-after ran" >> "%s"\nexit 0\n' "$TRACE" \
  > "$HOOKDIR/hooks.d/20-after"
chmod +x "$HOOKDIR/hooks.d/10-fails" "$HOOKDIR/hooks.d/20-after"
stage_code
rc=$(run_hook)
if [ "$rc" = 0 ]; then
  bad "a failing hooks.d entry fails the commit" "the dispatcher exited 0"
elif traced "20-after ran"; then
  bad "a failing hooks.d entry stops the remaining entries" \
      "20-after ran after 10-fails exited 7"
else
  ok "the first non-zero hooks.d entry fails the commit and stops the rest"
fi

# --- debris and non-executable entries are skipped, not run ----------------
setup_case; assert_isolated
enrol; mkdir -p "$HOOKDIR/hooks.d"
printf '#!/usr/bin/env bash\necho "notexec ran" >> "%s"\nexit 9\n' "$TRACE" \
  > "$HOOKDIR/hooks.d/10-notexec"
chmod 644 "$HOOKDIR/hooks.d/10-notexec"
echo "a README, not a hook" > "$HOOKDIR/hooks.d/README.md"
stage_code
rc=$(run_hook)
if [ "$rc" != 0 ]; then
  bad "non-executable debris in hooks.d is skipped" "exit was $rc: $(cat "$CASE/out")"
elif traced "notexec ran"; then
  bad "a non-executable hooks.d entry is not run" "it ran"
else
  ok "non-executable entries and debris in hooks.d are skipped"
fi

# --- an absent hooks.d is not an error -------------------------------------
setup_case; assert_isolated
enrol; stage_code
rc=$(run_hook)
if [ "$rc" != 0 ]; then
  bad "an absent hooks.d is not an error" "exit was $rc: $(cat "$CASE/out")"
else
  ok "an absent hooks.d is not an error"
fi

echo
echo "global-floor dispatcher — hooks.d ownership (task 6.9a)"

# --- hooks.d itself being a symlink is refused -----------------------------
# Checking only the ENTRIES does not make the directory operator-owned:
# repointing hooks.d redirects every entry at once.
setup_case; assert_isolated
enrol
mkdir -p "$CASE/elsewhere"
printf '#!/usr/bin/env bash\necho "planted ran" >> "%s"\nexit 0\n' "$TRACE" \
  > "$CASE/elsewhere/10-planted"
chmod +x "$CASE/elsewhere/10-planted"
ln -s "$CASE/elsewhere" "$HOOKDIR/hooks.d"
stage_code
rc=$(run_hook)
if traced "planted ran"; then
  bad "a symlinked hooks.d is refused" \
      "its entries ran — repointing the directory redirects every entry at once"
elif [ "$rc" = 0 ]; then
  bad "a symlinked hooks.d is reported" "exit was 0 and nothing was said"
else
  ok "a symlinked hooks.d is refused rather than followed"
fi

# --- a group- or world-writable hooks.d is refused -------------------------
setup_case; assert_isolated
enrol; mkdir -p "$HOOKDIR/hooks.d"
printf '#!/usr/bin/env bash\necho "ww ran" >> "%s"\nexit 0\n' "$TRACE" \
  > "$HOOKDIR/hooks.d/10-ww"
chmod +x "$HOOKDIR/hooks.d/10-ww"
chmod 777 "$HOOKDIR/hooks.d"
stage_code
rc=$(run_hook)
if traced "ww ran"; then
  bad "a world-writable hooks.d is refused" \
      "its entries ran — another local user could install code that runs on" \
      "every commit"
elif [ "$rc" = 0 ]; then
  bad "a world-writable hooks.d is reported" "exit was 0 and nothing was said"
else
  ok "a world-writable hooks.d is refused rather than trusted"
fi

echo
echo "----------------------------------------------------------------"
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
