#!/usr/bin/env bash
# global-floor-bind.test.sh — the floor binder's contract.
#
# Covers change one-enforcement-floor tasks 2.1, 2.2, 2.3 and 2.4, plus the
# ordering requirement "The hook is published before the binding is set, and a
# failed bind unwinds". Written and observed RED before
# reference-implementations/global-floor/bind-global-floor.sh existed.
#
# WHY THE ORDER IS ASSERTED AND NOT JUST THE END STATE
#
# Binding first and failing before the hook lands leaves core.hooksPath pointing
# at a directory with no pre-commit — and a commit under that binding SUCCEEDS
# SILENTLY, verified on git 2.50.1. The machine is then globally unbound in
# effect while every surface reports it as bound. Publishing first means the
# worst partial state is a published hook nothing has bound yet, which is the
# floor as it exists today. The two orders are not symmetric, so the suite
# asserts which one ran rather than only what survived.
#
# ISOLATION
#
# This is the first suite in the repository whose subject writes GLOBAL git
# configuration. A case that leaked would rebind the operator's real machine —
# every repository on it, at commit time. So each case gets its own HOME *and*
# its own GIT_CONFIG_GLOBAL, GIT_CONFIG_SYSTEM is sent to /dev/null, and the
# guard below refuses to run if either escaped the sandbox.
#
# HOME alone is not enough to rely on: `git config --global` picks
# $XDG_CONFIG_HOME/git/config over $HOME/.gitconfig when that file exists, and
# XDG_CONFIG_HOME is inherited from the operator's environment.
#
# Usage: tools/global-floor-bind.test.sh
#   GLOBAL_FLOOR_BIND_BIN=/usr/bin/true tools/global-floor-bind.test.sh
#     (/usr/bin/true, not /bin/true — the latter does not exist on macOS)
#     Points the suite at a deliberately wrong implementation. Assertions below
#     MUST fail under it — that is how this file proves it has teeth.
#
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINDER_REL="reference-implementations/global-floor/bind-global-floor.sh"
BINDER="${GLOBAL_FLOOR_BIND_BIN:-$ROOT/$BINDER_REL}"

# Normative and spelled out here rather than read from the implementation: a
# test that sourced these from the thing under test would agree with it
# whatever it said. Both are pinned by the spec delta, not chosen here.
HOOKS_REL='.agenticapps/git-hooks'
MARKER_KEY='global-floor-version'

pass=0
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; fail=$((fail + 1)); }

# Most assertions here are about a binder that declines to act — "the global
# configuration is unchanged", "core.hooksPath SHALL NOT be set". Every one of
# them is satisfied vacuously by a script that does not exist, because a missing
# command writes nothing. Without this guard the suite reports a clean run
# against an empty repository, which is worse than a missing suite because it
# is counted.
if [ ! -x "$BINDER" ]; then
  echo "  FAIL  precondition: binder not executable at $BINDER"
  echo "        Refusing to run: the decline assertions would pass vacuously."
  echo "        This is the expected RED while the implementation does not exist."
  exit 1
fi

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
# Each case gets its own copy of the two reference-implementation directories
# the binder resolves from its own location. A copy is what lets a case replace
# install-shared-artifact.sh with a recorder WITHOUT the binder carrying a
# test-only seam — a production script with a seam that exists only for its
# tests has a seam that can be wrong in production.

CASE_N=0
setup_case() {
  CASE_N=$((CASE_N + 1))
  CASE="$TMP/case$CASE_N"
  export HOME="$CASE/home"
  export GIT_CONFIG_GLOBAL="$CASE/home/.gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
  export CALL_LOG="$CASE/calls.log"
  HOOKDIR="$HOME/$HOOKS_REL"
  CORE="$CASE/core"
  mkdir -p "$HOME" "$CORE/reference-implementations"
  : > "$GIT_CONFIG_GLOBAL"
  : > "$CALL_LOG"

  cp -R "$ROOT/reference-implementations/global-floor"   "$CORE/reference-implementations/"
  cp -R "$ROOT/reference-implementations/shared-install" "$CORE/reference-implementations/"
  # When the suite is pointed at a deliberately wrong implementation the copy
  # must be that one too, or the teeth check would exercise the real binder.
  cp "$BINDER" "$CORE/$BINDER_REL"
  chmod +x "$CORE/$BINDER_REL"

  # A repository to run from. The binder writes GLOBAL configuration, so where
  # it is run from must not matter — and one case below asserts exactly that.
  REPO="$CASE/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q .
  git -C "$REPO" config user.email t@t
  git -C "$REPO" config user.name t
}

# Guard: never let a case touch the operator's real configuration. Checked per
# case rather than once, because a case that sets its own variables wrongly is
# exactly the case that would escape.
assert_isolated() {
  case "$GIT_CONFIG_GLOBAL" in
    "$TMP"/*) ;;
    *) echo "  FAIL  isolation: GIT_CONFIG_GLOBAL escaped the sandbox"; exit 1 ;;
  esac
  case "$HOME" in
    "$TMP"/*) ;;
    *) echo "  FAIL  isolation: HOME escaped the sandbox"; exit 1 ;;
  esac
}

# Replace the arbitrating publisher with a recorder that exits with a chosen
# status. One line per call: `SHARED <src> <dst> <marker-key>`.
stub_shared() {
  local rc="${1:-0}"
  cat > "$CORE/reference-implementations/shared-install/install-shared-artifact.sh" <<STUB
#!/usr/bin/env bash
printf 'SHARED' >> "\$CALL_LOG"
for a in "\$@"; do printf ' %s' "\$a" >> "\$CALL_LOG"; done
printf '\n' >> "\$CALL_LOG"
exit $rc
STUB
  chmod +x "$CORE/reference-implementations/shared-install/install-shared-artifact.sh"
}

run_binder() {
  assert_isolated
  ( cd "$REPO" && "$CORE/$BINDER_REL" >"$CASE/out" 2>&1 ); RC=$?
  OUT="$(cat "$CASE/out")"
}

bound()   { git config --global --get --type=path core.hooksPath 2>/dev/null; }
said()    { grep -qF "$1" "$CASE/out" 2>/dev/null; }
calls()   { cat "$CALL_LOG" 2>/dev/null; }

# The second vacuous-pass guard, and it is a different one from the
# precondition above. That guard proves the FILE exists; this proves the run
# DID something. Assertions of the form "the configuration is unchanged" are
# satisfied by a binder that returns immediately, and under
# GLOBAL_FLOOR_BIND_BIN=/usr/bin/true four of them passed for exactly that
# reason before this existed. Every case whose assertion is a negative opens
# with it.
ran() { [ -s "$CASE/out" ]; }

# ---------------------------------------------------------------------------
echo
echo "floor binder — publish (task 2.1)"

setup_case
run_binder
if [ -f "$HOOKDIR/pre-commit" ]; then
  ok "the dispatcher is published to ~/$HOOKS_REL/pre-commit"
else
  bad "the dispatcher is published to ~/$HOOKS_REL/pre-commit" \
      "no file at $HOOKDIR/pre-commit" "rc=$RC" "$OUT"
fi

# Content and the execute bit are separate assertions because git does not run
# a non-executable hook, so correct bytes without the bit is a silent floor.
if [ -x "$HOOKDIR/pre-commit" ]; then
  ok "the published hook is executable"
else
  bad "the published hook is executable" "not executable at $HOOKDIR/pre-commit"
fi

if cmp -s "$ROOT/reference-implementations/global-floor/pre-commit" "$HOOKDIR/pre-commit"; then
  ok "the published hook is the checkout's dispatcher, byte for byte"
else
  bad "the published hook is the checkout's dispatcher, byte for byte" \
      "published file differs from reference-implementations/global-floor/pre-commit"
fi

if ran && [ "$RC" -eq 0 ]; then
  ok "a fresh publish-and-bind exits 0 and reports what it did"
else
  bad "a fresh publish-and-bind exits 0 and reports what it did" "rc=$RC" "${OUT:-<no output>}"
fi

# Delegation is a claim about which code ran, and no assertion about the
# destination file can distinguish a correct delegation from a `cp` that
# produced the same bytes. The other three executables go through this helper
# for version arbitration, downgrade refusal and cross-installer locking; a
# binder that copied instead would silently overwrite a newer published hook.
setup_case
stub_shared 0
run_binder
if calls | grep -q "^SHARED .*global-floor/pre-commit .*$HOOKS_REL/pre-commit $MARKER_KEY$"; then
  ok "publishing is delegated to install-shared-artifact.sh with the $MARKER_KEY key"
else
  bad "publishing is delegated to install-shared-artifact.sh with the $MARKER_KEY key" \
      "calls: $(calls | tr '\n' ';')"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — bind (task 2.2)"

setup_case
run_binder
if [ "$(bound)" = "$HOOKDIR" ]; then
  ok "core.hooksPath is set globally to the published directory"
else
  bad "core.hooksPath is set globally to the published directory" \
      "got '$(bound)', wanted '$HOOKDIR'" "rc=$RC" "$OUT"
fi

# The binder runs from wherever the operator's shell happens to be. Writing a
# LOCAL binding instead of a global one is the category error Decision 4 names:
# it would make the machine-level installer act on whichever repository the
# shell was sitting in, which is not a property of the machine.
if ran && [ -z "$(git -C "$REPO" config --local --get core.hooksPath 2>/dev/null)" ]; then
  ok "the repository the binder ran from is left unconfigured"
else
  bad "the repository the binder ran from is left unconfigured" \
      "local core.hooksPath = $(git -C "$REPO" config --local --get core.hooksPath)"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — a foreign binding is reported, never overwritten (task 2.3)"

setup_case
FOREIGN="$CASE/somewhere-else/hooks"
mkdir -p "$FOREIGN"
git config --global core.hooksPath "$FOREIGN"
run_binder
if ran && [ "$(bound)" = "$FOREIGN" ]; then
  ok "a foreign global core.hooksPath is left unchanged"
else
  bad "a foreign global core.hooksPath is left unchanged" \
      "was '$FOREIGN', now '$(bound)'" "output: ${OUT:-<none>}"
fi

if said "$FOREIGN" && said "$HOOKDIR"; then
  ok "the report names the existing value and the value it would have set"
else
  bad "the report names the existing value and the value it would have set" "$OUT"
fi

# Reported as skipped, so the run exits non-zero — an operator who has bound a
# hooks directory deliberately must not have that decision retaken silently,
# and a zero exit here would let install.sh report a bound machine that is not.
if [ "$RC" -ne 0 ]; then
  ok "a foreign binding exits non-zero"
else
  bad "a foreign binding exits non-zero" "rc=0" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — an existing binding that is ours is satisfied (task 2.4)"

setup_case
run_binder                       # first run binds
run_binder                       # second run finds its own binding
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "a second run over our own binding exits 0 and leaves it in place"
else
  bad "a second run over our own binding exits 0 and leaves it in place" \
      "rc=$RC, binding='$(bound)'" "$OUT"
fi

# "Satisfied", not "bound": the difference is what an operator reads when they
# re-run the installer, and reporting a fresh install every time is how a
# no-op comes to look like work.
if said "satisfied"; then
  ok "the second run reports the binding as satisfied rather than as freshly set"
else
  bad "the second run reports the binding as satisfied rather than as freshly set" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — publish before bind, and a failed publish does not bind"

setup_case
stub_shared 1                    # publishing fails
run_binder
if ran && [ -z "$(bound)" ]; then
  ok "publishing fails: core.hooksPath is not set"
else
  bad "publishing fails: core.hooksPath is not set" \
      "binding was written anyway: '$(bound)'" \
      "a binding pointing at a directory with no pre-commit commits SILENTLY"
fi

if [ "$RC" -ne 0 ] && said "publish"; then
  ok "publishing fails: the run exits non-zero naming the publish failure"
else
  bad "publishing fails: the run exits non-zero naming the publish failure" "rc=$RC" "$OUT"
fi

# Exit 3 from the arbitrating helper is its documented SUCCESS: the destination
# already holds a strictly newer version, so "at least as new as the source"
# holds either way. Treating it as a failure would refuse to bind a machine
# that is more current than the checkout — correct state, reported as broken.
setup_case
stub_shared 3
run_binder
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "a destination already newer (helper exit 3) still binds and exits 0"
else
  bad "a destination already newer (helper exit 3) still binds and exits 0" \
      "rc=$RC, binding='$(bound)'" "$OUT"
fi

# The interrupted run. Publishing landed, the binding did not — which is the
# floor exactly as it exists on this machine today, so re-running must complete
# it rather than start over or refuse.
setup_case
mkdir -p "$HOOKDIR"
cp "$ROOT/reference-implementations/global-floor/pre-commit" "$HOOKDIR/pre-commit"
chmod +x "$HOOKDIR/pre-commit"
run_binder
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "a run interrupted between publish and bind completes the binding on re-run"
else
  bad "a run interrupted between publish and bind completes the binding on re-run" \
      "rc=$RC, binding='$(bound)'" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — the published directory is guarded like hooks.d"

# The dispatcher refuses a symlinked or group/world-writable hooks.d, because
# either lets another local account supply code that runs on every commit. It
# cannot make that check about the directory it LIVES in: by the time the
# dispatcher runs, an attacker who could write there has already replaced it.
# So the same guard has to be applied one level up, before anything is
# published — and `mkdir -p` over an existing symlink succeeds silently.
setup_case
mkdir -p "$CASE/elsewhere"
mkdir -p "$(dirname "$HOOKDIR")"
ln -s "$CASE/elsewhere" "$HOOKDIR"
run_binder
if ran && [ "$RC" -ne 0 ] && [ ! -e "$CASE/elsewhere/pre-commit" ] && [ -z "$(bound)" ]; then
  ok "a symlinked published directory is refused, and nothing is published or bound"
else
  bad "a symlinked published directory is refused, and nothing is published or bound" \
      "rc=$RC, binding='$(bound)', published=$([ -e "$CASE/elsewhere/pre-commit" ] && echo yes || echo no)" \
      "${OUT:-<no output>}"
fi

# The mode comes from the operator's umask, which is 022 on a stock macOS and
# is not guaranteed to be. A world-writable published directory means any local
# account can replace the hook that runs on every commit the operator makes.
setup_case
mkdir -p "$HOOKDIR"
chmod 777 "$HOOKDIR"
run_binder
if ran && [ "$RC" -ne 0 ] && [ ! -e "$HOOKDIR/pre-commit" ] && [ -z "$(bound)" ]; then
  ok "a world-writable published directory is refused, and nothing is published or bound"
else
  bad "a world-writable published directory is refused, and nothing is published or bound" \
      "rc=$RC, binding='$(bound)'" "${OUT:-<no output>}"
fi

# ---------------------------------------------------------------------------
echo
echo "----------------------------------------------------------------"
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
