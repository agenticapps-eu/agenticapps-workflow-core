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

  # Core's checkout is a real repository, because the binder repairs the one
  # repository it is by construction running from — SELF_DIR is
  # <core>/reference-implementations/global-floor — and a local git config
  # write needs somewhere to land. Before task 10.2 the fixture was a bare
  # directory and no case could tell the repair from its absence.
  git -C "$CORE" init -q .
  git -C "$CORE" config user.email t@t
  git -C "$CORE" config user.name t
  CORE_HOOKS="$CORE/.git/hooks"

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

# stdin is /dev/null so the run is the same whether the suite was started from
# a terminal or from CI. The binder prompts per unrecognised entry when stdin is
# a tty, and a suite that inherited one would hang on the case that plants one.
run_binder() { run_binder_in "$REPO"; }

# The directory the binder is RUN from is a parameter, not a constant, because
# one case below turns on it: an unquoted acceptance list globs against the
# working directory, so proving that it does not needs a cwd whose contents
# would match.
run_binder_in() {
  assert_isolated
  ( cd "$1" && "$CORE/$BINDER_REL" >"$CASE/out" 2>&1 </dev/null ); RC=$?
  OUT="$(cat "$CASE/out")"
}

bound()   { git config --global --get --type=path core.hooksPath 2>/dev/null; }
said()    { grep -qF "$1" "$CASE/out" 2>/dev/null; }
calls()   { cat "$CALL_LOG" 2>/dev/null; }

# Core's own local binding and the declaration that exempts it from the sweep.
core_bound()    { git -C "$CORE" config --local --get --type=path core.hooksPath 2>/dev/null; }
core_declared() { git -C "$CORE" config --local --get agenticapps.hooksbinding 2>/dev/null; }

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
echo "floor binder — core's own binding (task 10.2)"

# WHY THE BINDER OWNS THIS
#
# Setting the global binding IS the moment core's own hook stops being
# preferred: with core.hooksPath set globally, .git/hooks/ is not consulted at
# all. Four candidate owners were searched for and every one excludes this in
# its own text, so the binder takes it — it is the only artifact that knows
# both facts at once, and it runs from inside core's checkout by construction.
# The displacement and the repair are one act, for the same reason publish and
# bind are one act.

setup_case
run_binder
if [ "$(core_bound)" = "$CORE_HOOKS" ]; then
  ok "core's local core.hooksPath is set to its own default hooks directory"
else
  bad "core's local core.hooksPath is set to its own default hooks directory" \
      "got '$(core_bound)', wanted '$CORE_HOOKS'" "rc=$RC" "$OUT"
fi

# Without the declaration the sweep cannot tell core's deliberate binding from
# the five redundant ones it exists to unset — both name the default directory
# and both look identical by value. The sweep would then undo the repair on the
# next installer run.
if [ "$(core_declared)" = "declared" ]; then
  ok "the binding carries agenticapps.hooksbinding=declared"
else
  bad "the binding carries agenticapps.hooksbinding=declared" \
      "got '$(core_declared)'" "$OUT"
fi

# The end state above is not the point on its own — this is. A local binding
# that git does not prefer would satisfy both assertions and still leave core
# gated by the floor dispatcher, which exits 0 in silence for a repository the
# floor does not govern. So commit under the finished binding and assert that
# core's OWN hook is what ran.
setup_case
mkdir -p "$CORE_HOOKS"
cat > "$CORE_HOOKS/pre-commit" <<HOOK
#!/usr/bin/env bash
: > "$CASE/core-gate-ran"
HOOK
chmod +x "$CORE_HOOKS/pre-commit"
run_binder
( cd "$CORE" && git add -A >/dev/null 2>&1 && git commit -qm probe >/dev/null 2>&1 )
# The global binding is asserted alongside the marker, and it is not decoration.
# With nothing bound at all, `.git/hooks/pre-commit` runs by default — so the
# marker alone is satisfied by a binder that did nothing, and was: this case
# passed under GLOBAL_FLOOR_BIND_BIN=/usr/bin/true until the second clause.
if [ -f "$CASE/core-gate-ran" ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "a commit in core after the bind still runs core's working-tree gate"
else
  bad "a commit in core after the bind still runs core's working-tree gate" \
      "core's hook did not run; the global binding displaced it" \
      "core.hooksPath local='$(core_bound)' global='$(bound)'" "$OUT"
fi

# The ordering requirement, and the reason it is asserted rather than inferred:
# a global binding written before core's repair leaves core ungated for as long
# as the repair takes to fail. .git is made unwritable so the config lock cannot
# be taken, which is how a local write fails without the test reaching into the
# binder.
setup_case
chmod 555 "$CORE/.git"
run_binder
chmod 755 "$CORE/.git"
if ran && [ -z "$(bound)" ] && [ "$RC" -ne 0 ]; then
  ok "core's binding fails: the global binding is not set and the run exits non-zero"
else
  bad "core's binding fails: the global binding is not set and the run exits non-zero" \
      "rc=$RC, global binding='$(bound)'" \
      "a global binding without core's repair silently ungates core itself" \
      "${OUT:-<no output>}"
fi

# Matched on "core's local", not on "core" — every line this binder prints
# contains the string core.hooksPath, so the looser match passed before the
# implementation existed.
if said "core's local"; then
  ok "the failure report names core's binding as what failed"
else
  bad "the failure report names core's binding as what failed" "${OUT:-<no output>}"
fi

# Re-running the installer is routine, so the repair has to be idempotent and
# has to SAY it was already there. "Bound" on every run is how a no-op comes to
# look like work.
setup_case
run_binder
run_binder
if [ "$RC" -eq 0 ] && [ "$(core_bound)" = "$CORE_HOOKS" ] && [ "$(core_declared)" = "declared" ]; then
  ok "a second run leaves core's binding and declaration in place and exits 0"
else
  bad "a second run leaves core's binding and declaration in place and exits 0" \
      "rc=$RC, local='$(core_bound)', declared='$(core_declared)'" "$OUT"
fi

if said "satisfied — core's local"; then
  ok "the second run reports core's binding as satisfied rather than freshly set"
else
  bad "the second run reports core's binding as satisfied rather than freshly set" "$OUT"
fi

# A binding that names the right directory but carries no declaration is the
# interrupted repair — and it is exactly what the sweep unsets. Completing it is
# a repair; there is no operator decision here to retake.
setup_case
git -C "$CORE" config --local core.hooksPath "$CORE_HOOKS"
run_binder
if [ "$RC" -eq 0 ] && [ "$(core_declared)" = "declared" ]; then
  ok "an undeclared binding on the right directory gains the declaration"
else
  bad "an undeclared binding on the right directory gains the declaration" \
      "rc=$RC, declared='$(core_declared)'" "$OUT"
fi

# The same posture the binder already takes toward a foreign GLOBAL binding,
# one level down. A local core.hooksPath pointing elsewhere is a decision
# somebody made — husky sets exactly this — and silently retaking it at commit
# time is the thing this whole change refuses to do.
setup_case
ELSEWHERE="$CASE/core-elsewhere-hooks"
mkdir -p "$ELSEWHERE"
git -C "$CORE" config --local core.hooksPath "$ELSEWHERE"
run_binder
if ran && [ "$(core_bound)" = "$ELSEWHERE" ] && [ "$RC" -ne 0 ] && [ -z "$(bound)" ]; then
  ok "a foreign local binding in core is reported, never overwritten, and nothing is bound"
else
  bad "a foreign local binding in core is reported, never overwritten, and nothing is bound" \
      "rc=$RC, local='$(core_bound)', global='$(bound)'" "${OUT:-<no output>}"
fi

# The refusal above happens before the global write, so it must not leave the
# declaration behind either — a declared binding pointing at a foreign
# directory would tell the sweep to protect somebody else's hooks.
if ran && [ -z "$(core_declared)" ]; then
  ok "the refused case leaves no declaration behind"
else
  bad "the refused case leaves no declaration behind" "declared='$(core_declared)'" \
      "${OUT:-<no output>}"
fi

# A foreign GLOBAL binding is refused, and the binder is then not about to set
# the global one at all — so there is no displacement of core's hook to repair.
# Writing into core anyway would be a change to a repository with no cause,
# which is the shape Decision 4 removed.
setup_case
FOREIGN="$CASE/somewhere-else/hooks"
mkdir -p "$FOREIGN"
git config --global core.hooksPath "$FOREIGN"
run_binder
if ran && [ -z "$(core_bound)" ] && [ -z "$(core_declared)" ]; then
  ok "a foreign global binding is refused without writing into core"
else
  bad "a foreign global binding is refused without writing into core" \
      "local='$(core_bound)', declared='$(core_declared)'" "${OUT:-<no output>}"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — the directory is inventoried before it is bound (task 10.1)"

# WHY AN INVENTORY AND NOT ANOTHER PERMISSION CHECK
#
# The installer publishes one FILE and binds a DIRECTORY. Git runs whatever it
# finds there by name, so binding activates every entry — pre-push, commit-msg,
# any of them — machine-wide, in every repository the floor governs. The two
# guards above cannot close that: they prove no OTHER account could have written
# the directory, never that the operator meant its contents to run on every
# commit. An entry the operator dropped there themselves passes both.
#
# Measured 2026-08-08, and this is why the requirement exists: the directory on
# this machine held one file, a 46-line pre-commit vendored from an archived
# host repository, unmarked, exporting OPENSPEC_GATE_SELF=opencode and
# describing a rule retired at gate 2.0.0. At `pre-commit` it self-heals,
# because publishing replaces it. Named `pre-push` it would have become the
# machine's commit-time gate, unchallenged.

# A clean inventory is REPORTED, not merely silent. Silence and "nothing was
# looked at" read identically, and the whole point of this task is that nobody
# looked.
setup_case
run_binder
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ] && said "inventor"; then
  ok "a directory holding only what we publish binds, and the inventory is reported"
else
  bad "a directory holding only what we publish binds, and the inventory is reported" \
      "rc=$RC, binding='$(bound)'" "$OUT"
fi

# The entry, its size and its date — because "an unexpected file is present" is
# not enough to decide with, and deciding is what the operator is being asked
# to do.
setup_case
mkdir -p "$HOOKDIR"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/pre-push"
chmod +x "$HOOKDIR/pre-push"
touch -t 202507250000 "$HOOKDIR/pre-push"
PUSH_SIZE="$(wc -c < "$HOOKDIR/pre-push" | tr -d ' ')"
run_binder
if ran && [ "$RC" -ne 0 ] && [ -z "$(bound)" ]; then
  ok "an entry we did not publish refuses the bind and leaves the binding unset"
else
  bad "an entry we did not publish refuses the bind and leaves the binding unset" \
      "rc=$RC, binding='$(bound)'" "${OUT:-<no output>}"
fi

if said "pre-push" && said "$PUSH_SIZE" && said "2025-07-25"; then
  ok "the refusal names the entry, its size and its modification date"
else
  bad "the refusal names the entry, its size and its modification date" \
      "wanted the name, $PUSH_SIZE and 2025-07-25" "$OUT"
fi

# Refused before anything is published, so the worst state a refusal can leave
# is the state it found.
if ran && [ ! -e "$HOOKDIR/pre-commit" ]; then
  ok "a refused inventory publishes nothing either"
else
  bad "a refused inventory publishes nothing either" "$HOOKDIR/pre-commit exists"
fi

# Acceptance is BY NAME. The refusal has to say the words that grant it, or the
# operator's only route out is to delete a file they were asked to judge.
if said "GLOBAL_FLOOR_ACCEPT"; then
  ok "the refusal names the acceptance mechanism"
else
  bad "the refusal names the acceptance mechanism" "$OUT"
fi

setup_case
mkdir -p "$HOOKDIR"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/pre-push"
GLOBAL_FLOOR_ACCEPT=pre-push run_binder
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "accepting the entry by name binds"
else
  bad "accepting the entry by name binds" "rc=$RC, binding='$(bound)'" "$OUT"
fi

# The distinction the requirement turns on. "The directory contains unexpected
# files, proceed?" is the prompt everyone accepts, and it grants the same thing
# whether the entry is a stale copy of our own hook or a pre-push nobody
# remembers. So an acceptance naming one entry must not cover another.
setup_case
mkdir -p "$HOOKDIR"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/pre-push"
GLOBAL_FLOOR_ACCEPT=commit-msg run_binder
if ran && [ "$RC" -ne 0 ] && [ -z "$(bound)" ] && said "pre-push"; then
  ok "accepting a different entry does not accept this one"
else
  bad "accepting a different entry does not accept this one" \
      "rc=$RC, binding='$(bound)'" "${OUT:-<no output>}"
fi

# Every unrecognised entry, not the first one found. A report that stops at one
# makes the second acceptance a surprise on the next run.
setup_case
mkdir -p "$HOOKDIR"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/pre-push"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/commit-msg"
run_binder
if ran && said "pre-push" && said "commit-msg"; then
  ok "every unrecognised entry is named, not just the first"
else
  bad "every unrecognised entry is named, not just the first" "${OUT:-<no output>}"
fi

if [ "$RC" -ne 0 ] && [ -z "$(bound)" ]; then
  ok "and accepting neither of them still refuses"
else
  bad "and accepting neither of them still refuses" "rc=$RC, binding='$(bound)'"
fi

setup_case
mkdir -p "$HOOKDIR"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/pre-push"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/commit-msg"
GLOBAL_FLOOR_ACCEPT="pre-push commit-msg" run_binder
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "accepting both by name binds"
else
  bad "accepting both by name binds" "rc=$RC, binding='$(bound)'" "$OUT"
fi

# hooks.d is where the published dispatcher sends operator-owned hooks, so it is
# part of the design rather than a finding. Flagging it would make the refusal
# fire on every correctly composed machine, which is how a guard gets disabled.
setup_case
mkdir -p "$HOOKDIR/hooks.d"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/hooks.d/my-check"
chmod +x "$HOOKDIR/hooks.d/my-check"
run_binder
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "hooks.d and its contents are not findings"
else
  bad "hooks.d and its contents are not findings" "rc=$RC, binding='$(bound)'" "$OUT"
fi

# The one entry that does not block, and the reason is that it does not survive
# the run: an unmarked file reads as 0.0.0, so publishing replaces it before
# anything is bound. It is still REPORTED — a hook replaced silently is
# indistinguishable from a hook that was never there, which is exactly how the
# vendored one sat unnoticed for two weeks.
setup_case
mkdir -p "$HOOKDIR"
printf '#!/bin/sh\n# vendored from somewhere else\nexit 0\n' > "$HOOKDIR/pre-commit"
chmod +x "$HOOKDIR/pre-commit"
run_binder
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "an unmarked pre-commit does not block: publishing replaces it"
else
  bad "an unmarked pre-commit does not block: publishing replaces it" \
      "rc=$RC, binding='$(bound)'" "$OUT"
fi

if cmp -s "$ROOT/reference-implementations/global-floor/pre-commit" "$HOOKDIR/pre-commit"; then
  ok "and it is replaced by the checkout's dispatcher"
else
  bad "and it is replaced by the checkout's dispatcher" "the unmarked file survived"
fi

# Reported means the inventory was taken BEFORE the publish. Afterwards there is
# nothing left to report — our own bytes are sitting where the finding was.
if said "pre-commit" && said "unrecognised"; then
  ok "the replaced entry is still reported, so the inventory ran before the publish"
else
  bad "the replaced entry is still reported, so the inventory ran before the publish" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — what the security pass found in the consent gate"

# FINDING 1 — the acceptance list globbed.
#
# `for a in $ACCEPT` is unquoted for word splitting, and unquoted expansion in
# the shell also does PATHNAME expansion. So GLOBAL_FLOOR_ACCEPT='*' — which is
# what an operator types when they mean "accept whatever is there" — expanded
# against the working directory the binder happened to be run from. Reproduced:
# with a file named `pre-push` in that directory, `*` matched the entry and the
# machine bound.
#
# That is the blanket acceptance the requirement forbids in as many words,
# arriving through the shell rather than through the design, and it is
# NON-DETERMINISTIC: the same command accepts different entries depending on
# where it was run.
setup_case
mkdir -p "$HOOKDIR"
printf '#!/bin/sh\nexit 0\n' > "$HOOKDIR/pre-push"
mkdir -p "$REPO/decoy" && : > "$REPO/decoy/pre-push"
GLOBAL_FLOOR_ACCEPT='*' run_binder_in "$REPO/decoy"
if ran && [ "$RC" -ne 0 ] && [ -z "$(bound)" ]; then
  ok "a wildcard does not accept an entry by globbing the working directory"
else
  bad "a wildcard does not accept an entry by globbing the working directory" \
      "rc=$RC, binding='$(bound)'" \
      "GLOBAL_FLOOR_ACCEPT='*' matched a file in the cwd and granted consent" \
      "${OUT:-<no output>}"
fi

# FINDING 2 — a marked pre-commit this run did not publish was bound, under an
# inventory line that said the opposite.
#
# The inventory exempted `pre-commit` whenever it carried a version marker, and
# the marker is just a comment: any file in that directory can carry one. When
# the marked version is NEWER than the checkout's, arbitration correctly
# declines to publish — so the file survives, and the binder then binds the
# directory it sits in. Reproduced: the run printed "holds nothing this
# installer did not publish" and bound a pre-commit that this installer did not
# publish and did not replace.
#
# The carve-out was justified by "publishing replaces it". Where the publish
# does NOT replace it, the justification is gone with it. The recognition test
# is therefore the PUBLISHER'S OWN VERDICT rather than the presence of a
# comment — exit 3 means the file in place is not ours.
setup_case
mkdir -p "$HOOKDIR"
cat > "$HOOKDIR/pre-commit" <<'HOOK'
#!/usr/bin/env bash
# global-floor-version: 9.9.9
exit 0
HOOK
chmod +x "$HOOKDIR/pre-commit"
touch -t 202507250000 "$HOOKDIR/pre-commit"
FOREIGN_SIZE="$(wc -c < "$HOOKDIR/pre-commit" | tr -d ' ')"
run_binder
if ran && [ "$RC" -ne 0 ] && [ -z "$(bound)" ]; then
  ok "a marked pre-commit the publish will not replace refuses the bind"
else
  bad "a marked pre-commit the publish will not replace refuses the bind" \
      "rc=$RC, binding='$(bound)'" \
      "the directory was bound with a gate this run neither published nor replaced" \
      "${OUT:-<no output>}"
fi

if said "pre-commit" && said "$FOREIGN_SIZE" && said "2025-07-25"; then
  ok "and it is named with its size and date, like any other finding"
else
  bad "and it is named with its size and date, like any other finding" "$OUT"
fi

# The false claim is the finding. "Holds nothing this installer did not publish"
# is the line the requirement asked for so that a clean result is evidence
# rather than silence — evidence that is sometimes false is worse than the
# silence it replaced.
if ran && ! said "holds nothing this installer did not publish"; then
  ok "and the clean-inventory line is not printed when the inventory is not clean"
else
  bad "and the clean-inventory line is not printed when the inventory is not clean" \
      "the run claimed a clean directory while binding a foreign gate" "$OUT"
fi

# Still acceptable by name, because a machine genuinely more current than the
# checkout is correct state rather than an attack, and refusing it forever
# would be the "correct state reported as broken" failure the publish step
# already avoids.
setup_case
mkdir -p "$HOOKDIR"
cat > "$HOOKDIR/pre-commit" <<'HOOK'
#!/usr/bin/env bash
# global-floor-version: 9.9.9
exit 0
HOOK
chmod +x "$HOOKDIR/pre-commit"
GLOBAL_FLOOR_ACCEPT=pre-commit run_binder
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "accepting the newer pre-commit by name binds, and leaves it in place"
else
  bad "accepting the newer pre-commit by name binds, and leaves it in place" \
      "rc=$RC, binding='$(bound)'" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "----------------------------------------------------------------"
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
