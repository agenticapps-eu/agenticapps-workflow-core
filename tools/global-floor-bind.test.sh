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
# THE MIGRATION (tasks 9.4a–9.4h)
#
# The binder writes git configuration into, and deletes files from, repositories
# OTHER than the one it runs in. Every case below exists because that is a
# different kind of act from binding a machine, and the delta spends a
# requirement and a half saying what may authorise it.
#
# The order is enrol → sweep → verify → remove and it is asserted as an ORDER,
# not as an end state, for the same reason publish-then-bind is: the two wrong
# orders produce the same final disk and a different set of survivable
# interruptions. A suite that only checks the end state passes under both.
# ---------------------------------------------------------------------------

# Spelled out rather than read from tools/install-core-git-hooks.sh, for the
# reason HOOKS_REL and MARKER_KEY are: a test that sourced the marker from the
# thing that writes it would agree with whatever it said. This is the WHOLE
# line, because a hook that merely mentions the marker has not claimed it.
GATE_MARKER='# managed-by: agenticapps-workflow-core tools/install-core-git-hooks.sh'

# The floor dispatcher FAILS OPEN when the gate is missing (§18), so a commit in
# an enrolled repository with no gate on the machine succeeds — which reads
# exactly like an ungated one. Every case that asks "is this repository still
# gated" plants a refusing gate first, or it would be asserting the fail-open
# path and calling it enforcement.
plant_gate() {
  mkdir -p "$HOME/.agenticapps/bin"
  printf '#!/bin/sh\nexit 1\n' > "$HOME/.agenticapps/bin/openspec-change-gate.sh"
  chmod +x "$HOME/.agenticapps/bin/openspec-change-gate.sh"
  # The dispatcher prefers these two over the planted path, and they are read
  # from the operator's environment. A suite that inherited one would assert
  # against whatever gate that machine happens to have.
  unset OPENSPEC_GATE OPENSPEC_CHANGE_GATE
}

# A repository in the state the migration set is actually in: a gate pre-commit
# in its own hooks directory, and — for two of the three measured — a local
# core.hooksPath naming that same directory.
#
#   $1 name   $2 binding: none|redundant|real|declared   $3 hook: ours|foreign|absent
gated_repo() {
  local d="$CASE/$1"
  mkdir -p "$d"
  git -C "$d" init -q .
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  case "${3:-ours}" in
    ours)    printf '#!/bin/sh\n%s\nexit 1\n' "$GATE_MARKER" > "$d/.git/hooks/pre-commit"
             chmod +x "$d/.git/hooks/pre-commit" ;;
    foreign) printf '#!/bin/sh\n# somebody else wrote this\nexit 1\n' > "$d/.git/hooks/pre-commit"
             chmod +x "$d/.git/hooks/pre-commit" ;;
    absent)  ;;
  esac
  case "${2:-none}" in
    redundant) git -C "$d" config --local core.hooksPath "$d/.git/hooks" ;;
    real)      mkdir -p "$CASE/elsewhere"
               git -C "$d" config --local core.hooksPath "$CASE/elsewhere" ;;
    declared)  git -C "$d" config --local core.hooksPath "$d/.git/hooks"
               git -C "$d" config --local agenticapps.hooksbinding declared ;;
  esac
  printf '%s' "$d"
}

enrolled()   { git -C "$1" config --local --type=bool --get agenticapps.workflow.enrolled 2>/dev/null; }
local_hp()   { git -C "$1" config --local --get --type=path core.hooksPath 2>/dev/null; }
has_hook()   { [ -f "$1/.git/hooks/pre-commit" ]; }

# The only question that matters about a repository mid-migration, and it is
# asked of git rather than of the configuration: make a commit and see whether
# anything refused it. Both surfaces in play refuse — the repository's own hook
# and the planted gate behind the floor — so a commit that SUCCEEDS means no
# surface ran, which is the state the delta forbids at every interruption point.
COMMIT_N=0
commit_refused() {
  COMMIT_N=$((COMMIT_N + 1))
  : > "$1/f$COMMIT_N"
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" commit -q -m "c$COMMIT_N" >/dev/null 2>&1 && return 1
  return 0
}

# Named repositories are positional arguments. install.sh calls the binder with
# none, which is what makes "acts only on repositories the operator names" true
# of the unattended path by construction rather than by a flag defaulting right.
run_binder_with() {
  assert_isolated
  ( cd "$REPO" && "$CORE/$BINDER_REL" "$@" >"$CASE/out" 2>&1 </dev/null ); RC=$?
  OUT="$(cat "$CASE/out")"
}

# INTERRUPTION, FOR REAL. The delta requires that no cut inside a repository's
# sequence leaves it unenforced, and the only honest way to assert that is to
# stop the process at the cut rather than to reason about it.
#
# A test-only seam in the binder was rejected: a production script carrying a
# branch that exists only for its tests has a branch that can be wrong in
# production. So the interruption comes from outside — a `git` earlier on PATH
# that passes the call through and then kills the process group. That couples
# these cases to the exact git invocation each step makes, which is a real cost
# and the smaller one: the alternative couples the binder to the test.
#
# The kill is by PROCESS GROUP, not by $PPID. Bash may or may not fork an
# intermediate subshell for `x="$(git ...)"` depending on the optimisation it
# picks, so $PPID is the binder in some steps and a short-lived subshell in
# others — and killing the subshell lets the binder sail on with an empty
# value, which would pass this suite while proving nothing. `set -m` puts the
# run in its own group so the group is exactly the binder and its children.
#
# AND THE CUT ITSELF IS ASSERTED. Coupling to an exact invocation means the
# pattern can stop matching — a reworded git call, a step moved — and nothing
# would say so: the shim never fires, the binder runs to completion, and a
# COMPLETED run satisfies all three cut assertions (enrolled, swept, gated by
# the floor). The cases would report ok while proving nothing about
# interruption at all. So the shim records that it fired and the helper refuses
# to return without it.
run_binder_cut() {
  local pat="$1"; shift
  local realgit; realgit="$(command -v git)"
  mkdir -p "$CASE/bin"
  rm -f "$CASE/cut-fired"
  cat > "$CASE/bin/git" <<WRAP
#!/usr/bin/env bash
case "\$*" in
  $pat)
    "$realgit" "\$@"; rc=\$?
    : > "$CASE/cut-fired"
    kill -9 -"\$(ps -o pgid= -p \$\$ | tr -d ' ')" 2>/dev/null
    exit \$rc ;;
esac
exec "$realgit" "\$@"
WRAP
  chmod +x "$CASE/bin/git"
  assert_isolated
  set -m
  ( cd "$REPO" && PATH="$CASE/bin:$PATH" "$CORE/$BINDER_REL" "$@" >"$CASE/out" 2>&1 </dev/null ) &
  wait $!; RC=$?
  set +m
  OUT="$(cat "$CASE/out")"
  [ -f "$CASE/cut-fired" ] || {
    echo "  FAIL  run_binder_cut: '$pat' never matched, so the run was never cut."
    echo "        Every assertion after this would describe a completed migration."
    exit 1
  }
}

# The same injection, answering a matching call instead of killing on it. Used
# for the one condition no fixture can produce honestly: a repository that
# resolves to something other than the floor AFTER its redundant binding has
# been swept. On a correctly bound machine that cannot happen, which is why the
# restore path would otherwise go untested until the day it mattered.
run_binder_answering() {
  local pat="$1" answer="$2"; shift 2
  local realgit; realgit="$(command -v git)"
  mkdir -p "$CASE/bin"
  rm -f "$CASE/cut-fired"
  cat > "$CASE/bin/git" <<WRAP
#!/usr/bin/env bash
case "\$*" in
  $pat) : > "$CASE/cut-fired"; printf '%s\n' "$answer"; exit 0 ;;
esac
exec "$realgit" "\$@"
WRAP
  chmod +x "$CASE/bin/git"
  assert_isolated
  ( cd "$REPO" && PATH="$CASE/bin:$PATH" "$CORE/$BINDER_REL" "$@" >"$CASE/out" 2>&1 </dev/null ); RC=$?
  OUT="$(cat "$CASE/out")"
  # An unmatched pattern here fails loudly rather than silently — a completed
  # migration contradicts the assertions this helper exists for. Guarded anyway,
  # so the message names the cause instead of leaving it to be worked out.
  [ -f "$CASE/cut-fired" ] || {
    echo "  FAIL  run_binder_answering: '$pat' never matched, so nothing was answered."
    exit 1
  }
}

# ---------------------------------------------------------------------------
echo
echo "floor binder — the migration acts only on repositories the operator names (9.4a)"

# The unattended path first, because install.sh takes it on every run and a
# preflight that fired with nothing named would block every install.
setup_case
run_binder_with
if [ "$RC" -eq 0 ] && [ "$(bound)" = "$HOOKDIR" ] && ! said "preflight"; then
  ok "no names means no migration, no preflight and no prompt"
else
  bad "no names means no migration, no preflight and no prompt" \
      "rc=$RC, binding='$(bound)'" "$OUT"
fi

# A repository on the machine that nobody named. The delta's words are "left
# entirely alone" — not enrolled, not swept, hook not removed — and the reason
# the case exists is that a migration which discovered its own set would find
# this one and act on it.
setup_case
plant_gate
UNNAMED="$(gated_repo unnamed redundant ours)"
NAMED="$(gated_repo named redundant ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$NAMED"
# `said "$NAMED"` is the vacuity guard, and it is not decoration: every clause
# after it is a negative, and a binder that ignored its arguments entirely would
# satisfy all three by doing nothing at all.
if said "$NAMED" && [ -z "$(enrolled "$UNNAMED")" ] && [ -n "$(local_hp "$UNNAMED")" ] && has_hook "$UNNAMED"; then
  ok "a repository that was not named is not enrolled, swept or stripped"
else
  bad "a repository that was not named is not enrolled, swept or stripped" \
      "enrolled='$(enrolled "$UNNAMED")' hooksPath='$(local_hp "$UNNAMED")' hook=$(has_hook "$UNNAMED" && echo present || echo GONE)" \
      "$OUT"
fi

if [ "$(enrolled "$NAMED")" = true ] && [ -z "$(local_hp "$NAMED")" ] && ! has_hook "$NAMED"; then
  ok "a named repository is enrolled, swept and its hook removed"
else
  bad "a named repository is enrolled, swept and its hook removed" \
      "rc=$RC enrolled='$(enrolled "$NAMED")' hooksPath='$(local_hp "$NAMED")' hook=$(has_hook "$NAMED" && echo PRESENT || echo gone)" \
      "$OUT"
fi

# `! has_hook` belongs in this assertion rather than only in the one above it:
# with the hook still in place a refused commit proves the OLD surface works,
# which is what the migration is replacing.
if [ "$RC" -eq 0 ] && ! has_hook "$NAMED" && commit_refused "$NAMED"; then
  ok "and the floor gates it afterwards, with its own hook gone"
else
  bad "and the floor gates it afterwards, with its own hook gone" \
      "rc=$RC hook=$(has_hook "$NAMED" && echo PRESENT || echo gone) — the commit was not refused" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — one report, one acceptance (9.4a)"

setup_case
plant_gate
R="$(gated_repo r1 redundant ours)"
run_binder_with "$R"
if ran && [ "$RC" -ne 0 ] && [ -z "$(bound)" ] && [ ! -f "$HOOKDIR/pre-commit" ]; then
  ok "an unaccepted preflight publishes nothing and binds nothing"
else
  bad "an unaccepted preflight publishes nothing and binds nothing" \
      "rc=$RC binding='$(bound)' published=$([ -f "$HOOKDIR/pre-commit" ] && echo yes || echo no)" "$OUT"
fi

if said DECLINED && [ -z "$(enrolled "$R")" ] && [ -n "$(local_hp "$R")" ] && has_hook "$R"; then
  ok "and no named repository is enrolled, swept or stripped"
else
  bad "and no named repository is enrolled, swept or stripped" \
      "enrolled='$(enrolled "$R")' hooksPath='$(local_hp "$R")'" "$OUT"
fi

# The report is the dry-run, so it owes the three things the acceptance covers:
# what will be published, what will be newly enrolled, and what will be done to
# each repository. Three separate prompts is how an operator learns to answer
# without reading, which is the failure the per-entry inventory above exists to
# prevent — reintroducing it one level up would undo it.
if said "preflight" && said "$R" && said "$HOOKDIR"; then
  ok "the preflight names the repository and the directory before asking"
else
  bad "the preflight names the repository and the directory before asking" "$OUT"
fi

# The mutation set is not the impact set. A repository enrolled earlier by
# init-project.sh becomes governed the moment the binding lands, without being
# named and without appearing here — so a preflight claiming to enumerate what
# the binding governs would be making a promise the binder cannot keep.
if said "enrolled earlier"; then
  ok "and it says what it does not enumerate, rather than overclaiming"
else
  bad "and it says what it does not enumerate, rather than overclaiming" \
      "no line distinguishing this run's mutation set from the binding's impact set" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — the order is enrol → sweep → verify → remove (9.4c, 9.4d)"

# THE CASE THAT MATTERS. Cut the run immediately after the sweep and the
# repository must still be gated. Under the rejected sweep-first order it is
# not: the sweep hands it to the global dispatcher, whose first act is to exit 0
# because the enrolment marker is not there yet. The commit then succeeds, and
# an interruption in that window leaves the repository permanently ungated with
# nothing reporting it. That is what makes this a regression guard and not a
# description of the code.
setup_case
plant_gate
R="$(gated_repo r1 redundant ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_cut '*--unset*core.hooksPath*' "$R"
if [ "$(enrolled "$R")" = true ]; then
  ok "interrupted at the sweep, the repository is already enrolled"
else
  bad "interrupted at the sweep, the repository is already enrolled" \
      "enrolled='$(enrolled "$R")' — the sweep ran before the enrolment" "$OUT"
fi

# The binding must actually be gone at this cut, or the commit was refused by
# the repository's own hook and the case proved nothing about the floor.
if [ -z "$(local_hp "$R")" ] && commit_refused "$R"; then
  ok "and a commit in it is still gated, which sweep-first would not be"
else
  bad "and a commit in it is still gated, which sweep-first would not be" \
      "hooksPath='$(local_hp "$R")' — swept, unenrolled, and gated by nothing" "$OUT"
fi

# The other two cuts inside the sequence. Between repositories is the easy
# boundary; both plan reviewers located the hazard inside one.
setup_case
plant_gate
R="$(gated_repo r1 redundant ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_cut '*agenticapps.workflow.enrolled*' "$R"
if [ "$(enrolled "$R")" = true ] && [ -n "$(local_hp "$R")" ] && has_hook "$R" && commit_refused "$R"; then
  ok "interrupted at the enrolment, its own hook still gates it"
else
  bad "interrupted at the enrolment, its own hook still gates it" \
      "enrolled='$(enrolled "$R")' hooksPath='$(local_hp "$R")' hook=$(has_hook "$R" && echo present || echo GONE)" "$OUT"
fi

setup_case
plant_gate
R="$(gated_repo r1 redundant ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_cut '*--git-path*hooks*' "$R"
if [ "$(enrolled "$R")" = true ] && [ -z "$(local_hp "$R")" ] && commit_refused "$R"; then
  ok "interrupted at the verification, the floor already gates it"
else
  bad "interrupted at the verification, the floor already gates it" \
      "enrolled='$(enrolled "$R")' hooksPath='$(local_hp "$R")'" "$OUT"
fi

# THE REPOSITORY WITH NO LOCAL BINDING, which is the shape
# tools/install-core-git-hooks.sh actually leaves behind — it writes into the
# directory git already resolves and sets nothing — and the shape one of the
# three measured repositories is in. Every cut above is taken against a
# repository whose local core.hooksPath is what displaces its hook, so all three
# of them are blind to the displacement that needs no sweep at all: setting
# core.hooksPath GLOBALLY stops `.git/hooks/` being consulted everywhere at
# once. Reproduced against the enrol-inside-the-loop order — the commit below
# succeeded, in a repository whose hook file was still sitting on disk.
setup_case
plant_gate
R="$(gated_repo r1 none ours)"
# `?` and not a space, because a case pattern is one WORD: a pattern written
# with spaces in it is a syntax error inside the injected shim, which then fails
# every git call and takes the run down somewhere unrelated. And `--global?core`
# rather than `*--global*core.hooksPath*` because the loose form also matches the
# READ of the current value — `--global --get --type=path core.hooksPath` — which
# happens long before the enrolment and would cut the run before the instant
# this case is about.
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_cut '*--global?core.hooksPath?*' "$R"
if [ "$(enrolled "$R")" = true ] && [ "$(bound)" = "$HOOKDIR" ] && has_hook "$R" && commit_refused "$R"; then
  ok "interrupted at the global binding, a repository with no local binding is gated"
else
  bad "interrupted at the global binding, a repository with no local binding is gated" \
      "enrolled='$(enrolled "$R")' binding='$(bound)' hook=$(has_hook "$R" && echo present || echo GONE)" \
      "— bound, unenrolled, and its own hook no longer consulted by anything" "$OUT"
fi

# The other side of that instant. Enrolling before the binding is only free if
# nothing reads the marker yet, so the cut here must find a machine with no
# floor on it — otherwise this case would pass for the wrong reason.
setup_case
plant_gate
R="$(gated_repo r1 none ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_cut '*agenticapps.workflow.enrolled*' "$R"
if [ "$(enrolled "$R")" = true ] && [ -z "$(bound)" ] && has_hook "$R" && commit_refused "$R"; then
  ok "interrupted at the enrolment, the binding has not landed and its own hook still gates it"
else
  bad "interrupted at the enrolment, the binding has not landed and its own hook still gates it" \
      "enrolled='$(enrolled "$R")' binding='$(bound)'" "$OUT"
fi

# And the completed run for the same shape, which no case covered either: the
# whole migration for a repository that has nothing to sweep.
setup_case
plant_gate
R="$(gated_repo r1 none ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R"
if [ "$RC" -eq 0 ] && [ "$(enrolled "$R")" = true ] && ! has_hook "$R" && commit_refused "$R"; then
  ok "a repository with nothing to sweep is migrated, and the floor gates it afterwards"
else
  bad "a repository with nothing to sweep is migrated, and the floor gates it afterwards" \
      "rc=$RC enrolled='$(enrolled "$R")' hook=$(has_hook "$R" && echo present || echo gone)" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — verification failure restores the swept binding (9.4e)"

# A repository handed to a floor that turns out not to govern it is returned to
# the surface it had. The failure is forced by making the global binding land
# somewhere the repository does not resolve to — here, a local binding the
# sweep is not entitled to touch reappears underneath it.
setup_case
plant_gate
R="$(gated_repo r1 redundant ours)"
# The failure is forced where it is observed, with the same PATH-injected git
# the interruption cases use: the verification asks git which hooks directory
# this repository resolves to, and here it answers with one that is not the
# floor. No seam in the binder, and no fixture contortion pretending to be a
# machine state that produces the same answer.
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_answering '*--git-path*hooks*' "$CASE/not-the-floor" "$R"
if [ "$RC" -ne 0 ] && has_hook "$R"; then
  ok "a repository the floor does not reach keeps its hook"
else
  bad "a repository the floor does not reach keeps its hook" \
      "rc=$RC hook=$(has_hook "$R" && echo present || echo GONE)" "$OUT"
fi

# The enrolment is deliberately NOT rolled back with the binding. It is inert
# while the local binding stands — the repository is gated by its own hook,
# which predates the predicate and never reads it — so unwinding it would be
# undoing something that is doing nothing.
if [ "$(enrolled "$R")" = true ] && [ -n "$(local_hp "$R")" ]; then
  ok "and the swept binding is restored rather than left unset"
else
  bad "and the swept binding is restored rather than left unset" \
      "enrolled='$(enrolled "$R")' hooksPath='$(local_hp "$R")' — a hook git no longer consults" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — a binding that is not redundant stops the repository (9.4c)"

setup_case
plant_gate
R="$(gated_repo r1 real ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R"
if [ "$RC" -ne 0 ] && [ "$(local_hp "$R")" = "$CASE/elsewhere" ] && has_hook "$R" && [ -z "$(enrolled "$R")" ]; then
  ok "a real local binding is preserved, and the repository is not migrated"
else
  bad "a real local binding is preserved, and the repository is not migrated" \
      "rc=$RC hooksPath='$(local_hp "$R")' enrolled='$(enrolled "$R")'" "$OUT"
fi

setup_case
plant_gate
R="$(gated_repo r1 declared ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R"
if [ "$RC" -ne 0 ] && [ -n "$(local_hp "$R")" ] && has_hook "$R"; then
  ok "a declared binding is redundant by value and is still not swept"
else
  bad "a declared binding is redundant by value and is still not swept" \
      "rc=$RC hooksPath='$(local_hp "$R")'" "$OUT"
fi

if said declared; then
  ok "and it is reported as declared rather than as somebody's opt-out"
else
  bad "and it is reported as declared rather than as somebody's opt-out" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — a name is not an identity (9.4f)"

setup_case
plant_gate
mkdir -p "$CASE/not-a-repo"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$CASE/not-a-repo"
if ran && [ "$RC" -ne 0 ] && [ -z "$(bound)" ] && [ ! -f "$HOOKDIR/pre-commit" ]; then
  ok "a name that is not the top of a repository is rejected before any write"
else
  bad "a name that is not the top of a repository is rejected before any write" \
      "rc=$RC binding='$(bound)'" "$OUT"
fi

# A subdirectory of a repository resolves to that repository under rev-parse,
# so accepting it would migrate a repository the operator did not name.
setup_case
plant_gate
R="$(gated_repo r1 redundant ours)"
mkdir -p "$R/sub"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R/sub"
if [ "$RC" -ne 0 ] && has_hook "$R" && [ -z "$(enrolled "$R")" ]; then
  ok "a subdirectory is not the repository, and is rejected as a name"
else
  bad "a subdirectory is not the repository, and is rejected as a name" \
      "rc=$RC enrolled='$(enrolled "$R")'" "$OUT"
fi

setup_case
plant_gate
R="$(gated_repo r1 redundant ours)"
ln -s "$R" "$CASE/alias"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R" "$CASE/alias"
if [ "$RC" -eq 0 ] && [ "$(grep -c ': enrolled' "$CASE/out")" = 1 ]; then
  ok "two names for one common directory are processed once"
else
  bad "two names for one common directory are processed once" \
      "rc=$RC, ': enrolled' appeared $(grep -c ': enrolled' "$CASE/out") times" "$OUT"
fi

# Linked worktrees share one common directory, so they share one local
# configuration and one hooks directory. Naming any checkout acts on all of
# them — so "an unnamed repository is left entirely alone" is false for a
# sibling nobody mentioned unless the preflight says its name out loud.
setup_case
plant_gate
R="$(gated_repo r1 redundant ours)"
: > "$R/seed"; git -C "$R" add -A >/dev/null 2>&1
git -C "$R" -c core.hooksPath=/nonexistent commit -q -m seed >/dev/null 2>&1
git -C "$R" worktree add -q "$CASE/wt" -b wt >/dev/null 2>&1
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R"
if said "$CASE/wt"; then
  ok "the preflight names every worktree the migration will affect"
else
  bad "the preflight names every worktree the migration will affect" \
      "the linked worktree at $CASE/wt shares the configuration and was not reported" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — the hook is recognised before it is removed (9.4g)"

# Naming a repository is the operator's belief about what is inside it. It is
# not evidence about the file, and the negative is the case that matters: a
# repository named by mistake keeps the hook its operator wrote.
setup_case
plant_gate
R="$(gated_repo r1 redundant foreign)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R"
if [ "$RC" -ne 0 ] && has_hook "$R" && [ -z "$(enrolled "$R")" ] && [ -n "$(local_hp "$R")" ]; then
  ok "a foreign pre-commit refuses the repository without writing to it"
else
  bad "a foreign pre-commit refuses the repository without writing to it" \
      "rc=$RC enrolled='$(enrolled "$R")' hooksPath='$(local_hp "$R")' hook=$(has_hook "$R" && echo present || echo GONE)" \
      "$OUT"
fi

if said "$R/.git/hooks/pre-commit"; then
  ok "and the file it declined to remove is named"
else
  bad "and the file it declined to remove is named" "$OUT"
fi

# Found by the security pass on this diff, not by review. The marker narrows
# the delete to files this workflow wrote, which is NOT the same as files in the
# repository that was named: a symlinked hooks directory sends the removal
# somewhere else while the preflight still prints the path inside the repository.
# A symlinked hook is visible in the report; a symlinked directory is not.
setup_case
plant_gate
R="$(gated_repo r1 none ours)"
mkdir -p "$CASE/other-hooks"
printf '#!/bin/sh\n%s\nexit 1\n' "$GATE_MARKER" > "$CASE/other-hooks/pre-commit"
rm -rf "$R/.git/hooks" && ln -s "$CASE/other-hooks" "$R/.git/hooks"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R"
if [ "$RC" -ne 0 ] && [ -f "$CASE/other-hooks/pre-commit" ] && [ -z "$(enrolled "$R")" ]; then
  ok "a symlinked hooks directory refuses, rather than deleting outside the repository"
else
  bad "a symlinked hooks directory refuses, rather than deleting outside the repository" \
      "rc=$RC enrolled='$(enrolled "$R")' target=$([ -f "$CASE/other-hooks/pre-commit" ] && echo present || echo DELETED)" \
      "$OUT"
fi

setup_case
plant_gate
R="$(gated_repo r1 redundant absent)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$R"
if [ "$RC" -ne 0 ] && [ -z "$(enrolled "$R")" ] && [ -n "$(local_hp "$R")" ]; then
  ok "an absent hook refuses the repository too, rather than migrating nothing"
else
  bad "an absent hook refuses the repository too, rather than migrating nothing" \
      "rc=$RC enrolled='$(enrolled "$R")' hooksPath='$(local_hp "$R")'" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "floor binder — one repository fails and the rest continue (9.4h)"

setup_case
plant_gate
BAD_R="$(gated_repo bad redundant foreign)"
GOOD_R="$(gated_repo good redundant ours)"
GLOBAL_FLOOR_ACCEPT_PLAN=1 run_binder_with "$BAD_R" "$GOOD_R"
if [ "$(enrolled "$GOOD_R")" = true ] && ! has_hook "$GOOD_R"; then
  ok "the repository after the failure is still processed"
else
  bad "the repository after the failure is still processed" \
      "enrolled='$(enrolled "$GOOD_R")' hook=$(has_hook "$GOOD_R" && echo PRESENT || echo gone)" "$OUT"
fi

if [ "$RC" -ne 0 ]; then
  ok "and the run exits non-zero, so a partial migration is not reported as a complete one"
else
  bad "and the run exits non-zero, so a partial migration is not reported as a complete one" \
      "rc=0 with $BAD_R refused" "$OUT"
fi

# The machine is still bound. The failure is about one repository, and refusing
# to bind a machine because one named path was wrong would be the larger act
# taken for the smaller reason.
if [ "$RC" -ne 0 ] && [ "$(bound)" = "$HOOKDIR" ]; then
  ok "and the machine is bound regardless, because the failure was local to one repository"
else
  bad "and the machine is bound regardless, because the failure was local to one repository" \
      "rc=$RC binding='$(bound)'" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "----------------------------------------------------------------"
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
