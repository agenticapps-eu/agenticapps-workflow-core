#!/usr/bin/env bash
# install.test.sh — behaviour suite for install.sh, the one entry point.
#
# Change: core-installer-one-entry-point. Task group 1 (the floor) lives here;
# groups 2-6 land as the behaviour they cover is written. RED before GREEN, so
# every case in this file is expected to FAIL until install.sh exists.
#
# THE CONTAINMENT RULE, AND WHAT IT ACTUALLY BUYS
#
# This suite drives an installer whose entire job is writing into a home
# directory and into host configuration. Run carelessly, it would install the
# workflow onto the machine running the tests — and a test that changes the
# machine cannot be run twice with confidence, which is the same as not being
# runnable.
#
# So every case gets its own temp HOME and its own scratch git repo, and after
# every case the suite checks a canary set: the real paths under the real home
# that this installer is capable of touching. Any change to those is a failure
# of the case that caused it, reported as a containment breach rather than as
# whatever assertion happened to notice.
#
# What the canary DOES catch: a hardcoded path, a `$HOME` captured before the
# override, a helper invoked with the caller's environment instead of the
# case's. Those are the realistic ways a front end leaks past its sandbox, and
# they are why task 1.1 comes before every other task in the change.
#
# What it DOES NOT catch: a write outside both the temp dirs AND the canary set
# — /tmp, /usr/local, a path invented later. The honest guarantee is "the
# installer did not touch the things it knows how to touch", not "the installer
# wrote nothing anywhere". A full-filesystem diff would buy the stronger
# property at a cost this suite is not worth. Stated here rather than implied,
# because the gap is the kind that gets rediscovered as a surprise.
#
# Usage: tools/install.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL="$ROOT/install.sh"
REAL_HOME="$HOME"

pass=0
fail=0

# Everything the suite creates lives under here, so a killed run leaves one
# directory to remove rather than a scatter.
SUITE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/install-test.XXXXXX")"
trap 'rm -rf "$SUITE_TMP"' EXIT

ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; shift; for l in "$@"; do printf '        %s\n' "$l"; done; fail=$((fail + 1)); }

# ── Containment ────────────────────────────────────────────────────────────
#
# The skill names this workflow installs, has installed, or must clean up.
# Kept as a list rather than derived from skills/, because the names that matter
# most are precisely the ones core no longer ships.
WORKFLOW_SKILL_NAMES="agentic-apps-workflow openspec-change-review
agenticapps-workflow setup-agenticapps-workflow update-agenticapps-workflow
setup-codex-agenticapps-workflow update-codex-agenticapps-workflow
update-opencode-agenticapps-workflow"

HOST_SKILL_DIRS=".claude/skills .codex/skills .config/opencode/skills .agents/skills"
HOST_CONFIGS=".claude/settings.json .codex/hooks.json .config/opencode/plugin/openspec-change-gate.ts"

# stat's spelling differs between BSD and GNU, and `-f` means something else
# entirely on GNU. Resolved once rather than per call.
if stat -f '%N' . >/dev/null 2>&1; then
  stat_batch() { xargs -0 stat -f '%N %z %m'; }
else
  stat_batch() { xargs -0 stat -c '%n %s %Y'; }
fi

# A digest of every canary that exists: path, size, mtime, and — for symlinks —
# the target.
#
# Depth is 2, not 4, and that is a deliberate reading of what a binding IS. A
# bound skill is an ENTRY in a skills directory; everything beneath it lives in
# the checkout, which this installer never writes to. Descending further stats
# 8,800 files to learn nothing new about the property under test.
#
# The sort is GLOBAL and comes last. An earlier draft sorted within each canary
# root and piped the loop straight to the hash, which was non-deterministic:
# each root's find ran in its own subshell writing to a shared pipe, so once the
# output passed the pipe buffer the roots interleaved differently between calls.
# Three consecutive calls returned three hashes and the suite reported a
# containment breach against an installer that did not yet exist. A flaky
# containment check is worse than none — it trains the reader to disbelieve it.
# The canary asserts the PROPERTIES THIS INSTALLER COULD VIOLATE, not "nothing
# under my home changed".
#
# The first version was a whole-tree digest over ~/.agenticapps, ~/.claude,
# ~/.codex, ~/.config/opencode and ~/.agents. It reported breaches
# intermittently against an installer that did not exist, and it took two
# rounds to see why: THE AGENT RUNNING THIS SUITE WRITES TO ~/.claude WHILE IT
# RUNS. The churn was real; it just had nothing to do with the installer. A
# quiet run then looked like a fix, which is the worse outcome of the two.
#
# The lesson generalises past this repo: a containment check that watches a
# directory somebody else legitimately writes to reports their writes as your
# bug, and the only way to keep it green is to stop believing it.
#
# So the listing records three things, each of which only this installer can
# change, and each of which is exactly what a leak would look like:
#
#   1. every file under ~/.agenticapps, by content — the publish target
#   2. for every host skill directory, the state of every name this workflow
#      binds or has ever bound — symlink target, present, or absent
#   3. for every host config, how many times the gate wiring appears in it
#
# Unrelated churn in those same directories is invisible here, and that is the
# point.
canary_listing() {
  local p n d f
  if [ -d "$REAL_HOME/.agenticapps" ]; then
    find "$REAL_HOME/.agenticapps" -type f -print0 2>/dev/null | xargs -0 shasum 2>/dev/null
  fi
  for d in $HOST_SKILL_DIRS; do
    for n in $WORKFLOW_SKILL_NAMES; do
      p="$REAL_HOME/$d/$n"
      if   [ -L "$p" ]; then printf '%s -> %s\n' "$p" "$(readlink "$p")"
      elif [ -e "$p" ]; then printf '%s present\n' "$p"
      else                   printf '%s absent\n'  "$p"
      fi
    done
  done
  for f in $HOST_CONFIGS; do
    p="$REAL_HOME/$f"
    if [ -f "$p" ]; then
      printf '%s gate-entries=%s\n' "$p" "$(grep -c 'openspec-change-gate' "$p" 2>/dev/null || printf 0)"
    else
      printf '%s absent\n' "$p"
    fi
  done
} 2>/dev/null

canary_digest() { canary_listing | shasum | awk '{print $1}'; }

CANARY_BASELINE=""

# ── Case scaffolding ───────────────────────────────────────────────────────
#
# Each case gets CASE_HOME and CASE_REPO. CASE_REPO is a real git repo because
# install-core-git-hooks.sh resolves its target through `git rev-parse`, and a
# fake directory would exercise a path the real installer never takes.
CASE_HOME=""
CASE_REPO=""
CASE_BIN=""
CASE_CORE=""

# Make a host look installed. Detection is by executable (task 4.14), so this is
# what "installed" means to the installer — not the presence of a directory.
# It lived beside the wiring cases until they were deleted; three cases then
# passed while calling a function that no longer existed, which is exactly what
# the vacuous-pass guard exists to catch. It sits with the scaffolding now, and
# above the first case that calls it — a definition below its caller is the same
# silent pass in a different disguise.
host_exec() { printf '#!/usr/bin/env bash\nexit 0\n' > "$CASE_BIN/$1"; chmod +x "$CASE_BIN/$1"; }

new_case() {
  local name="$1"
  local d
  d="$(mktemp -d "$SUITE_TMP/case.XXXXXX")"
  CASE_HOME="$d/home"
  CASE_REPO="$d/repo"
  CASE_BIN="$d/bin"
  CASE_DIR="$d"
  CASE_CORE=""            # unset means: run the real checkout's install.sh
  PATH_OVERRIDE=""
  mkdir -p "$CASE_HOME" "$CASE_REPO" "$CASE_BIN"
  git -C "$CASE_REPO" init -q 2>/dev/null
  git -C "$CASE_REPO" config user.email test@example.invalid
  git -C "$CASE_REPO" config user.name  test
  CASE_NAME="$name"
}

# ── Proving delegation ─────────────────────────────────────────────────────
#
# "Publishes through install-shared-artifact.sh and not by other means" is a
# claim about which code ran, and no assertion about the destination file can
# distinguish a correct delegation from a `cp` that produced the same bytes.
#
# So the case gets its own copy of the checkout and replaces the helper with a
# recorder. install.sh resolves its siblings from its own location, so a copy
# picks up the stubs with no test-only override inside install.sh itself —
# which matters, because a production script carrying a seam that exists only
# for its tests is a seam that can be wrong in production.
#
# 312K, so the copy is cheaper than the reasoning about avoiding it.
new_core() {
  CASE_CORE="$CASE_DIR/core"
  mkdir -p "$CASE_CORE/tools"
  # The copy is a repository, not just a directory, because the floor binder
  # establishes the local hooks binding of the checkout it runs from. Against a
  # bare directory it refuses — correctly, since binding the global path from
  # somewhere that is not a checkout would displace a hook it cannot repair —
  # and every full-run case would fail on a refusal that says nothing about
  # what the case is testing.
  git -C "$CASE_CORE" init -q
  git -C "$CASE_CORE" config user.email test@example.invalid
  git -C "$CASE_CORE" config user.name  test
  cp -R "$ROOT/reference-implementations" "$CASE_CORE/reference-implementations"
  cp -R "$ROOT/skills"                    "$CASE_CORE/skills"
  [ -d "$ROOT/hosts" ] && cp -R "$ROOT/hosts" "$CASE_CORE/hosts"
  cp    "$ROOT/tools/install-core-git-hooks.sh" "$CASE_CORE/tools/" 2>/dev/null
  if [ -f "$INSTALL" ]; then cp "$INSTALL" "$CASE_CORE/install.sh"; fi
}

# Replace a script inside the case's core copy with one that records how it was
# called and exits with a chosen status. The log is one line per call:
#   <label> <arg> <arg> ...
stub_helper() {
  local rel="$1" label="$2" rc="${3:-0}"
  local target="$CASE_CORE/$rel"
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<STUB
#!/usr/bin/env bash
printf '%s' "$label" >> "\$CALL_LOG"
for a in "\$@"; do printf ' %s' "\$a" >> "\$CALL_LOG"; done
printf '\n' >> "\$CALL_LOG"
exit $rc
STUB
  chmod +x "$target"
}

is_absolute() { case "$1" in /*) return 0;; *) return 1;; esac; }

# ── The other half of isolation ────────────────────────────────────────────
#
# GIT_CONFIG_GLOBAL sandboxes the machine-wide write and nothing sandboxes a
# LOCAL one: a repository's config path is fixed by the repository. The floor
# binder establishes the local binding of the checkout it runs from, so any
# case that runs the real install.sh writes into the repository this suite
# lives in — measured, and it did, before new_core became a repository.
#
# Recorded per case rather than once at the end, because the case that escaped
# is the one whose name has to appear next to the failure.
core_local_binding() {
  printf '%s|%s' \
    "$(git -C "$ROOT" config --local --get core.hooksPath 2>/dev/null)" \
    "$(git -C "$ROOT" config --local --get agenticapps.hooksbinding 2>/dev/null)"
}

restore_core_local_binding() {
  local want="$1" path="${1%%|*}" flag="${1##*|}"
  [ "$(core_local_binding)" = "$want" ] && return 0
  if [ -n "$path" ]; then git -C "$ROOT" config --local core.hooksPath "$path"
  else git -C "$ROOT" config --local --unset core.hooksPath 2>/dev/null; fi
  if [ -n "$flag" ]; then git -C "$ROOT" config --local agenticapps.hooksbinding "$flag"
  else git -C "$ROOT" config --local --unset agenticapps.hooksbinding 2>/dev/null; fi
}

calls() { cat "$CASE_HOME/calls.log" 2>/dev/null; }
called() { calls | grep -q "^$1"; }

# ── The vacuous-pass guard ─────────────────────────────────────────────────
#
# Many cases assert that something did NOT happen: a foreign hook was not
# overwritten, a declined acceptance left a file alone, check mode created no
# file. Every one of those passes for free while install.sh does not exist,
# because nothing ran and so nothing was touched.
#
# The first run of group 2 produced exactly that — a green "a foreign
# pre-commit hook is refused rather than replaced" against an installer that
# did not exist. A test that survives the absence of the mechanism it names is
# not testing the mechanism, and a green one is worse than a missing one
# because it is counted.
#
# So any case whose assertion is a negative opens with this.
require_ran() {
  [ "$RUN_MISSING" -eq 0 ] && return 0
  bad "$CASE_NAME" "install.sh did not run, so a negative assertion proves nothing" "$RUN_OUT"
  return 1
}

# Run install.sh inside the current case. Args are passed through.
#
# PATH is rebuilt from CASE_BIN plus the real PATH so a case can shadow a
# binary (task 1.4 hides git, 1.5 hides jq) by dropping a directory in front
# rather than by reconstructing a working PATH from nothing.
#
# GIT_CONFIG_GLOBAL is pinned per case because install.sh now writes GLOBAL git
# configuration — it binds core.hooksPath machine-wide. HOME alone is not
# enough to rely on: `git config --global` prefers $XDG_CONFIG_HOME/git/config
# when that file exists, and XDG_CONFIG_HOME is inherited from whoever ran the
# suite. A case that leaked would rebind the operator's real machine, at commit
# time, in every repository on it.
#
# Captures stdout+stderr into RUN_OUT and the status into RUN_RC.
RUN_OUT=""
RUN_RC=0
RUN_MISSING=0
run_install() {
  local script="${CASE_CORE:+$CASE_CORE/install.sh}"
  script="${script:-$INSTALL}"
  RUN_MISSING=0
  if [ ! -f "$script" ]; then
    RUN_OUT="install.sh does not exist at $INSTALL"
    RUN_RC=127
    RUN_MISSING=1
    return
  fi
  local before; before="$(core_local_binding)"
  RUN_OUT="$(cd "$CASE_REPO" && HOME="$CASE_HOME" PATH="${PATH_OVERRIDE:-$CASE_BIN:$PATH}" \
             CALL_LOG="$CASE_HOME/calls.log" \
             GIT_CONFIG_GLOBAL="$CASE_HOME/.gitconfig" GIT_CONFIG_SYSTEM=/dev/null \
             bash "$script" "$@" 2>&1)"
  RUN_RC=$?
  if [ "$(core_local_binding)" != "$before" ]; then
    bad "$CASE_NAME" \
        "isolation: the run wrote this repository's own local git config" \
        "core.hooksPath|agenticapps.hooksbinding was '$before', is now '$(core_local_binding)'" \
        "give the case its own core with new_core — the copy is a repository"
    restore_core_local_binding "$before"
  fi
}

# Making a command ABSENT, which is harder than it looks.
#
# The first version dropped a stub that exits 127 ahead of the real binary. That
# does not hide anything: `command -v git` finds the stub, is satisfied, and a
# Tier 1 check that asks "is git present" correctly answers yes. The test then
# proved nothing — it reported a partial publish because the installer had
# quite reasonably carried on.
#
# A non-executable file does not work either: PATH lookup skips it and finds the
# real one further along. The only honest way to make a command absent is to
# control PATH, so that is what this does.
#
#   hide_command git   →  PATH is CASE_BIN alone. Nothing is available, which
#                         is fine: the Tier 1 check runs before anything else
#                         and uses only shell builtins.
#   hide_command jq    →  PATH is a symlink farm of every real binary EXCEPT
#                         jq, so the rest of the installer still works.
PATH_OVERRIDE=""

# A symlink farm of every executable on the real PATH except one, cached per
# excluded name. Emptying PATH entirely was the first attempt and it removed
# `bash` too, so the harness could not even launch the script it was testing.
farm_without() {
  local want="$1" farm="$SUITE_TMP/farm-$1" d f b dirs
  [ -d "$farm" ] && { printf '%s' "$farm"; return; }
  mkdir -p "$farm"
  IFS=: read -ra dirs <<< "$PATH"
  for d in "${dirs[@]}"; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      [ -f "$f" ] && [ -x "$f" ] || continue
      b="$(basename "$f")"
      [ "$b" = "$want" ] && continue
      [ -e "$farm/$b" ] || ln -s "$f" "$farm/$b" 2>/dev/null
    done
  done
  printf '%s' "$farm"
}

hide_command() { PATH_OVERRIDE="$CASE_BIN:$(farm_without "$1")"; }

# Assert containment, then report the case's own verdict.
finish_case() {
  local digest
  canary_listing > "$SUITE_TMP/canary.now"
  digest="$(shasum < "$SUITE_TMP/canary.now" | awk '{print $1}')"
  if [ "$digest" != "$CANARY_BASELINE" ]; then
    bad "$CASE_NAME" "CONTAINMENT BREACH: a real-home canary changed during this case" \
                     "$(diff "$SUITE_TMP/canary.baseline" "$SUITE_TMP/canary.now" | head -6)" \
                     "the assertion result is not reported; fix the leak first"
    # Re-baseline, so one breach reports once instead of tainting every case
    # after it. The first breach is the one that names the cause.
    cp "$SUITE_TMP/canary.now" "$SUITE_TMP/canary.baseline"
    CANARY_BASELINE="$digest"
    return 1
  fi
  return 0
}

# ── The floor ──────────────────────────────────────────────────────────────

echo "install.sh — task 1.1: the harness contains itself"
canary_listing > "$SUITE_TMP/canary.baseline"
CANARY_BASELINE="$(shasum < "$SUITE_TMP/canary.baseline" | awk '{print $1}')"
if [ -n "$CANARY_BASELINE" ]; then
  ok "canary baseline computed over the real home"
else
  bad "canary baseline computed over the real home" "digest was empty"
fi

# The containment check is the one assertion every other case leans on, so it
# gets an assertion of its own. This case exists because the first draft failed
# it: the digest was order-unstable and reported a breach with nothing running.
second="$(canary_digest)"
if [ "$second" = "$CANARY_BASELINE" ]; then
  ok "the canary digest is deterministic across consecutive calls"
else
  bad "the canary digest is deterministic across consecutive calls" \
      "call 1 $CANARY_BASELINE" \
      "call 2 $second" \
      "every containment verdict below is worthless until this passes"
fi

new_case "the sandbox is a real git repo with its own HOME"
if [ -d "$CASE_REPO/.git" ] && [ -d "$CASE_HOME" ] && [ "$CASE_HOME" != "$REAL_HOME" ]; then
  ok "$CASE_NAME"
else
  bad "$CASE_NAME" "expected a git repo at $CASE_REPO and a temp home distinct from $REAL_HOME"
fi
finish_case

echo
echo "install.sh — task 1.2: a bare run publishes the payload and binds the floor"
new_case "bare run publishes the payload and binds the machine-level floor"
new_core
run_install
floor_dir="$CASE_HOME/.agenticapps/git-hooks"
floor_bound="$(GIT_CONFIG_GLOBAL="$CASE_HOME/.gitconfig" GIT_CONFIG_SYSTEM=/dev/null \
               git config --global --get core.hooksPath 2>/dev/null)"
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ ! -x "$CASE_HOME/.agenticapps/bin/openspec-change-gate.sh" ]; then
  bad "$CASE_NAME" "gate was not published to \$HOME/.agenticapps/bin/"
# Executable, not merely present: git does not run a non-executable hook, so
# correct bytes without the bit is a floor that reports itself as installed and
# gates nothing.
elif [ ! -x "$floor_dir/pre-commit" ]; then
  bad "$CASE_NAME" "the dispatcher was not published to \$HOME/.agenticapps/git-hooks/"
elif [ "$floor_bound" != "$floor_dir" ]; then
  bad "$CASE_NAME" "core.hooksPath was not bound to the published directory" \
      "got '$floor_bound', wanted '$floor_dir'"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 1.3: no host installed is success, and says so"
new_case "exits 0 with no host present and reports that none was wired"
new_core
run_install
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'no host|none.*wired|wired.*none'; then
  bad "$CASE_NAME" "run said nothing about no host being wired" \
                   "$(printf '%s' "$RUN_OUT" | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 1.4: git is Tier 1 and its absence is fatal"
new_case "git missing fails the run, names git, and publishes nothing"
hide_command git
run_install
if [ "$RUN_RC" -eq 0 ]; then
  bad "$CASE_NAME" "expected a non-zero exit with git absent, got 0"
elif ! printf '%s' "$RUN_OUT" | grep -qw 'git'; then
  bad "$CASE_NAME" "failure message does not name git" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ -e "$CASE_HOME/.agenticapps/bin" ] && [ -n "$(ls -A "$CASE_HOME/.agenticapps/bin" 2>/dev/null)" ]; then
  bad "$CASE_NAME" "the payload was partially published despite the Tier 1 failure"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 1.5: the installer needs nothing beyond Tier 1"
# jq was Tier 2 for exactly one reason: merging JSON into a host's config file.
# With no host configuration written, jq is not a dependency at all, and the
# case that proves it is a full run with jq hidden — not a run that reports its
# absence politely.
new_case "a full run with jq absent completes and mentions it nowhere"
new_core
hide_command jq
host_exec claude
run_install --host claude
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0 — nothing needs jq any more — got $RUN_RC" \
                   "$(printf '%s' "$RUN_OUT" | head -3)"
elif printf '%s' "$RUN_OUT" | grep -qw 'jq'; then
  bad "$CASE_NAME" "jq was mentioned by a run that does not use it" \
                   "$(printf '%s' "$RUN_OUT" | grep -w jq | head -2)"
elif [ ! -L "$CASE_HOME/.claude/skills/agentic-apps-workflow" ]; then
  bad "$CASE_NAME" "skills were not bound"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 1.6: the budget"
# Executable lines: neither comments nor blanks. Heredoc bodies count, because
# an operator reading the file to decide whether to trust it reads those too.
if [ ! -f "$INSTALL" ]; then
  bad "install.sh is at most 217 executable lines" "install.sh does not exist yet"
else
  n="$(grep -cvE '^[[:space:]]*(#|$)' "$INSTALL")"
  if [ "$n" -le 217 ]; then
    ok "install.sh is at most 217 executable lines ($n)"
  else
    bad "install.sh is at most 217 executable lines" \
        "counted $n, budget is 217, overage $((n - 217))" \
        "the spec fixes what may be deferred and in what order — do not drop a mode"
  fi
fi

echo
echo "install.sh — task 1.7: --help names every mode and the opt-in"
new_case "--help names the four modes and the replacement opt-in flag"
run_install --help
missing=""
for token in -- '--host' '--check' '--replace-unrecognised'; do
  [ "$token" = "--" ] && continue
  printf '%s' "$RUN_OUT" | grep -q -- "$token" || missing="$missing $token"
done
printf '%s' "$RUN_OUT" | grep -qi 'auto' || missing="$missing auto"
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0 from --help, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ -n "$missing" ]; then
  bad "$CASE_NAME" "--help does not mention:$missing"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 2.1: the four workflow executables go through the arbitrating helper"
new_case "each workflow executable is published through install-shared-artifact.sh with its own marker key"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
run_install
missing=""
# <src> <dst> <marker-key> — assert the marker key, because passing the wrong
# one silently disables the arbitration this delegation exists to inherit.
calls | grep -q '^SHARED .*openspec-change-gate\.sh .* gate-version$'          || missing="$missing gate-version"
calls | grep -q '^SHARED .*run-plan-review\.sh .* run-plan-review-version$'    || missing="$missing run-plan-review-version"
calls | grep -q '^SHARED .*reviewer-cli\.sh .* reviewer-cli-version$'          || missing="$missing reviewer-cli-version"
# fresh-clone-needs-nothing task 4.1a. The initializer is machine-installed and
# repository-invoked, exactly like the three above, so it is published the same
# way rather than becoming a subcommand or a file a repository carries.
calls | grep -q '^SHARED .*init-project\.sh .* init-project-version$'          || missing="$missing init-project-version"
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ -n "$missing" ]; then
  bad "$CASE_NAME" "not published through the helper with key:$missing" "calls: $(calls | tr '\n' ';')"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.13a: the project-hook publisher is retired"
# RED BEFORE GREEN APPLIES TO A DELETION TOO. These three are written and
# observed failing against the tree that still carries the publisher, because a
# test written after the deletion proves only that it can describe the present.
#
# They replaced the task 2.2 case and the code-review M1 pair, which asserted
# the opposite and were deleted at 3.13e. They were added first and observed
# failing against the tree that still had all three — 56 passed, 3 failed, the
# suite's own baseline immediately before being 56 passed, 0 failed.
#
# The task originally named a fourth: that `--check` reports no project-hook
# set. Round-2 review killed it. `--check` calls check_artifact for the four
# shared artifacts and prints nothing about project hooks today, so the
# assertion was already true and could never have gone RED. The observable it
# was reaching for lives in the install path, and it is the third case here.
if [ ! -f "$INSTALL" ]; then
  bad "install.sh carries no PROJHOOKS delegation" "install.sh does not exist"
elif grep -q 'PROJHOOKS\|install-project-hooks' "$INSTALL"; then
  bad "install.sh carries no PROJHOOKS delegation" \
      "$(grep -n 'PROJHOOKS\|install-project-hooks' "$INSTALL" | head -3)" \
      "the front end still resolves and calls the retired attesting installer"
else
  ok "install.sh carries no PROJHOOKS delegation"
fi

new_case "a full run writes no manifest under ~/.agenticapps"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
# Nothing standing in for the publisher: the assertion is that no code path
# writes an attestation, and a stub would satisfy it by doing nothing at all.
run_install
if ! require_ran; then :
elif [ -e "$CASE_HOME/.agenticapps/manifest.tsv" ]; then
  bad "$CASE_NAME" "the run wrote an attestation manifest" \
                   "$(head -3 "$CASE_HOME/.agenticapps/manifest.tsv" 2>/dev/null)" \
                   "the manifest is retired with its writer — nothing reads it"
else
  ok "$CASE_NAME"
fi
finish_case

new_case "a full run does not claim to have published and attested a project-hook set"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
stub_helper reference-implementations/openspec-tools/bind-openspec-tools.sh OPSXBIND 0
run_install
if ! require_ran; then :
elif printf '%s' "$RUN_OUT" | grep -qi 'project.hook'; then
  bad "$CASE_NAME" "the run still reports on a project-hook set" \
                   "$(printf '%s' "$RUN_OUT" | grep -i 'project.hook' | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 2.4: exit 3 from the arbitrating helper is satisfied, not skipped"
new_case "a destination already holding a newer version counts satisfied and does not fail the run"
new_core
# 3 is the helper's documented "dst already holds a STRICTLY NEWER version",
# declared in its own contract to be success. Classifying it as skipped would
# report failure on a machine that is already in the intended state.
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 3
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
run_install
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0 — exit 3 is success — got $RUN_RC" \
                   "$(printf '%s' "$RUN_OUT" | head -3)"
elif printf '%s' "$RUN_OUT" | grep -qiE 'skip(ped)?'; then
  bad "$CASE_NAME" "the run called the exit-3 path skipped" "$(printf '%s' "$RUN_OUT" | grep -i skip | head -2)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 2.5: what is published is executable"
new_case "every published artifact is executable at its destination"
new_core
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
# The publisher is left REAL — the executable bit is a property of what actually
# lands, and a stub lands nothing.
run_install
notexec=""
for a in openspec-change-gate.sh run-plan-review.sh reviewer-cli.sh init-project.sh; do
  d="$CASE_HOME/.agenticapps/bin/$a"
  [ -f "$d" ] || { notexec="$notexec $a(absent)"; continue; }
  [ -x "$d" ] || notexec="$notexec $a"
done
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ -n "$notexec" ]; then
  bad "$CASE_NAME" "not executable at the destination:$notexec"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 2.6: the floor is bound, and a foreign binding is refused"
new_case "the machine-level floor is bound through bind-global-floor.sh"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
run_install
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif ! called FLOORBIND; then
  bad "$CASE_NAME" "bind-global-floor.sh was not called" "calls: $(calls | tr '\n' ';')"
else
  ok "$CASE_NAME"
fi
finish_case

# Decision 4. install-core-git-hooks.sh resolves its destination with
# `git rev-parse --git-path hooks`, which HONOURS core.hooksPath — so once the
# floor is bound globally, calling it from install.sh redirects a
# per-repository hook into the machine-level directory, colliding with the
# published one. It also wrote into whichever repository the operator's shell
# happened to be sitting in, which is not a property of the machine.
#
# It is superseded, not deleted: it survives as core's own tool. This asserts
# the machine installer no longer reaches it.
new_case "install.sh no longer installs a per-repository hook"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
stub_helper tools/install-core-git-hooks.sh                                     GITHOOK 0
run_install
if ! require_ran; then
  :
elif called GITHOOK; then
  bad "$CASE_NAME" "install-core-git-hooks.sh was still called" "calls: $(calls | tr '\n' ';')"
elif [ -e "$CASE_REPO/.git/hooks/pre-commit" ]; then
  bad "$CASE_NAME" "a pre-commit landed in the repository the installer was run from"
else
  ok "$CASE_NAME"
fi
finish_case

# The refusal moved up a level with the floor. It used to be about a foreign
# pre-commit inside one repository; the machine installer no longer writes one,
# so that assertion would now pass because nothing happened rather than because
# something was refused. The equivalent question at the new level is a foreign
# GLOBAL core.hooksPath, and the real binder runs here — refusing a binding it
# does not own is its contract, and the assertion is that install.sh surfaces
# that refusal instead of forcing past it.
new_case "a foreign global core.hooksPath is refused rather than rebound"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
foreign_dir="$CASE_DIR/somebody-elses-hooks"
mkdir -p "$foreign_dir"
GIT_CONFIG_GLOBAL="$CASE_HOME/.gitconfig" GIT_CONFIG_SYSTEM=/dev/null \
  git config --global core.hooksPath "$foreign_dir"
run_install
bound_after="$(GIT_CONFIG_GLOBAL="$CASE_HOME/.gitconfig" GIT_CONFIG_SYSTEM=/dev/null \
               git config --global --get core.hooksPath 2>/dev/null)"
if ! require_ran; then
  :
elif [ "$bound_after" != "$foreign_dir" ]; then
  bad "$CASE_NAME" "the foreign binding was overwritten" "now: $bound_after"
elif [ "$RUN_RC" -eq 0 ]; then
  bad "$CASE_NAME" "the binding was refused but the run exited 0" \
      "a refused step is a skipped step, and a skipped step exits non-zero"
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'hookspath|floor'; then
  bad "$CASE_NAME" "the binding was left alone but the run said nothing about it" "$RUN_OUT"
else
  ok "$CASE_NAME"
fi
finish_case

# ── Bindings ───────────────────────────────────────────────────────────────
#
# Every case here binds claude explicitly. Explicit naming is not detection:
# `--host claude` says "wire this", and auto-detection's evidence rule (task
# 4.14) is a separate question tested separately.
CLAUDE_SKILLS=""
bind_case() {
  new_case "$1"
  new_core
  stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
  stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
  CLAUDE_SKILLS="$CASE_HOME/.claude/skills"
  mkdir -p "$CLAUDE_SKILLS"
}

# A stand-in for one of the archived host checkouts. Recognition is by repo name
# appearing in the resolved target, so this does not need to sit at the path the
# real one occupies — which is the point of judging it that way.
archived_skill() {
  local repo="$1" name="$2" d="$CASE_DIR/archived/$1/skills/$2"
  mkdir -p "$d"
  printf -- '---\nname: %s\n---\n' "$name" > "$d/SKILL.md"
  printf '%s' "$d"
}

echo
echo "install.sh — task 3.1: skills are symlinks into the checkout"
bind_case "each shipped skill appears as a symlink resolving into the checkout"
run_install --host claude
wrong=""
for s in agentic-apps-workflow openspec-change-review; do
  t="$CLAUDE_SKILLS/$s"
  if [ ! -L "$t" ]; then wrong="$wrong $s(not-a-symlink)"
  elif [ "$(cd "$(dirname "$(readlink "$t")")" 2>/dev/null && pwd -P)" != "$(cd "$CASE_CORE/skills" && pwd -P)" ]; then
    wrong="$wrong $s(->$(readlink "$t"))"
  fi
done
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ -n "$wrong" ]; then
  bad "$CASE_NAME" "not bound as symlinks into the checkout:$wrong"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — upstream discipline skills are bound from one checkout, not per host"
# THE GATES THE WORKFLOW NAMES WERE REACHABLE FROM EXACTLY ONE HOST.
# `superpowers` ships test-driven-development, verification-before-completion,
# finishing-a-development-branch and requesting-code-review — four of the seven
# gates in the skill's own table — and on this machine it arrived as a Claude
# PLUGIN, under ~/.claude/plugins/cache/, which no other host reads. Measured
# 2026-08-09: codex resolved none of the four and said so, correctly, while
# claude resolved all four. One workflow, two disciplines.
#
# Binding the plugin cache directly would have been worse than leaving it. The
# cache is version-PATHED and keeps old versions — 6.1.1 and 6.2.0 both present
# — so a symlink into 6.2.0 never dangles when Claude moves to 6.3.0. It keeps
# resolving, silently, to the old bytes. Every one of the 14 skills differs
# between those two versions, so that is not a cosmetic pin.
#
# So it is bound the way core's own skills are: ONE checkout, symlinked into
# every host. Same version everywhere by construction, and `git pull` moves all
# of them together.
bind_case "an upstream discipline skill is bound into the host from the shared checkout"
UP="$CASE_HOME/.agenticapps/upstream/superpowers/skills"
mkdir -p "$UP/test-driven-development" "$UP/verification-before-completion"
printf -- '---\nname: test-driven-development\n---\n' > "$UP/test-driven-development/SKILL.md"
printf -- '---\nname: verification-before-completion\n---\n' > "$UP/verification-before-completion/SKILL.md"
run_install --host claude
wrong=""
for s in test-driven-development verification-before-completion; do
  t="$CLAUDE_SKILLS/$s"
  if   [ ! -L "$t" ]; then wrong="$wrong $s(not-a-symlink)"
  elif [ ! -f "$t/SKILL.md" ]; then wrong="$wrong $s(does-not-resolve)"
  # Into the CHECKOUT, never into a plugin cache. A binding that resolves to a
  # version-pathed cache directory is the drift this case exists to forbid.
  elif case "$(readlink "$t")" in *"/upstream/superpowers/skills/$s") false ;; *) true ;; esac; then
    wrong="$wrong $s(->$(readlink "$t"))"
  fi
done
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ -n "$wrong" ]; then
  bad "$CASE_NAME" "not bound from the shared checkout:$wrong"
else
  ok "$CASE_NAME"
fi
finish_case

# A missing upstream is REPORTED, NEVER A BLOCK — the skill's own rule for every
# gate it does not own. `skip()` would make the run exit 1, which would turn an
# absent optional dependency into a failed install.
bind_case "an absent upstream checkout is reported and does not fail the run"
run_install --host claude
if ! require_ran; then :
elif [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "an absent upstream checkout failed the run (exit $RUN_RC)" \
                   "$(printf '%s' "$RUN_OUT" | head -5)"
elif printf '%s' "$RUN_OUT" | grep -qi 'SKIPPED.*superpower'; then
  bad "$CASE_NAME" "reported as a skipped step, which makes the installer exit 1"
elif ! printf '%s' "$RUN_OUT" | grep -qi 'superpower'; then
  bad "$CASE_NAME" "the run said nothing about the upstream it could not bind" \
                   "$(printf '%s' "$RUN_OUT" | head -5)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.2: a binding into an archived checkout is replaced outright"
bind_case "a symlink into an archived checkout is replaced without asking, and its old target reported"
old="$(archived_skill claude-workflow agentic-apps-workflow)"
ln -s "$old" "$CLAUDE_SKILLS/agentic-apps-workflow"
run_install --host claude
t="$CLAUDE_SKILLS/agentic-apps-workflow"
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0 — ours to replace, no consent needed — got $RUN_RC" \
                   "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ "$(readlink "$t")" = "$old" ]; then
  bad "$CASE_NAME" "the archived binding was left in place"
elif ! printf '%s' "$RUN_OUT" | grep -q 'claude-workflow'; then
  bad "$CASE_NAME" "the replacement did not name the previous target" \
                   "$(printf '%s' "$RUN_OUT" | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.3: an unrecognised symlink needs consent"
bind_case "a symlink to something unrelated is left alone and counted skipped without consent"
mkdir -p "$CASE_DIR/somebody-elses-tool/my-skill"
ln -s "$CASE_DIR/somebody-elses-tool/my-skill" "$CLAUDE_SKILLS/agentic-apps-workflow"
run_install --host claude
if ! require_ran; then :
elif [ "$(readlink "$CLAUDE_SKILLS/agentic-apps-workflow")" != "$CASE_DIR/somebody-elses-tool/my-skill" ]; then
  bad "$CASE_NAME" "an unrecognised symlink was replaced without consent"
elif [ "$RUN_RC" -eq 0 ]; then
  bad "$CASE_NAME" "a skipped requested binding must exit non-zero, got 0"
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'skip|consent|accept'; then
  bad "$CASE_NAME" "the skip was not reported" "$(printf '%s' "$RUN_OUT" | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

bind_case "the same symlink is replaced when consent is given by flag"
ln -s "$CASE_DIR" "$CLAUDE_SKILLS/agentic-apps-workflow"
run_install --host claude --replace-unrecognised
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0 with consent given, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ "$(readlink "$CLAUDE_SKILLS/agentic-apps-workflow")" = "$CASE_DIR" ]; then
  bad "$CASE_NAME" "consent was given and the binding was still not replaced"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.4: a copied skill directory needs consent"
bind_case "a directory at the target is reported as a copy and left alone without consent"
mkdir -p "$CLAUDE_SKILLS/agentic-apps-workflow"
printf 'someone edited this\n' > "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md"
run_install --host claude
if ! require_ran; then :
elif [ ! -f "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md" ]; then
  bad "$CASE_NAME" "a directory that could hold work was removed without consent"
elif [ "$RUN_RC" -eq 0 ]; then
  bad "$CASE_NAME" "a skipped requested binding must exit non-zero, got 0"
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'cop(y|ied)|director'; then
  bad "$CASE_NAME" "the directory was not reported as a copy" "$(printf '%s' "$RUN_OUT" | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.5: a regular file at the target needs consent"
bind_case "a regular file at the target is reported and left alone without consent"
printf 'notes to self\n' > "$CLAUDE_SKILLS/agentic-apps-workflow"
run_install --host claude
if ! require_ran; then :
elif [ ! -f "$CLAUDE_SKILLS/agentic-apps-workflow" ] || [ -L "$CLAUDE_SKILLS/agentic-apps-workflow" ]; then
  bad "$CASE_NAME" "a regular file was replaced without consent"
elif [ "$RUN_RC" -eq 0 ]; then
  bad "$CASE_NAME" "a skipped requested binding must exit non-zero, got 0"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.6: dangling and relative links are resolved before judgement"
bind_case "a dangling link into an archived checkout is still recognised as ours and replaced absolutely"
# The target never existed. A judgement that stats the target instead of reading
# it classifies this as foreign and stops replacing exactly the bindings this
# change exists to replace — which is what deleting the checkouts will produce.
ln -s "$CASE_DIR/archived/codex-workflow/skills/agentic-apps-workflow" "$CLAUDE_SKILLS/agentic-apps-workflow"
run_install --host claude
t="$CLAUDE_SKILLS/agentic-apps-workflow"
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ ! -e "$t" ]; then
  bad "$CASE_NAME" "the binding still dangles after the run"
elif ! is_absolute "$(readlink "$t")"; then
  bad "$CASE_NAME" "the replacement is not an absolute symlink: $(readlink "$t")"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.7: a symlink that cannot be created reports and never copies"
bind_case "an unwritable skills directory reports, continues, and does not fall back to copying"
chmod 555 "$CLAUDE_SKILLS"
run_install --host claude
chmod 755 "$CLAUDE_SKILLS"
if ! require_ran; then :
elif [ -e "$CLAUDE_SKILLS/agentic-apps-workflow" ] && [ ! -L "$CLAUDE_SKILLS/agentic-apps-workflow" ]; then
  bad "$CASE_NAME" "the installer fell back to copying"
elif [ "$RUN_RC" -eq 0 ]; then
  bad "$CASE_NAME" "a binding that could not be made must not exit 0"
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'skills|symlink|bind'; then
  bad "$CASE_NAME" "the failure was not reported" "$(printf '%s' "$RUN_OUT" | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.8: every legacy name is replaced or removed, and reported"
bind_case "legacy names are acted on by name and each outcome is reported"
for legacy in agenticapps-workflow setup-agenticapps-workflow update-agenticapps-workflow \
              setup-codex-agenticapps-workflow update-opencode-agenticapps-workflow; do
  ln -s "$(archived_skill claude-workflow "$legacy")" "$CLAUDE_SKILLS/$legacy"
done
run_install --host claude
unreported=""
for legacy in agenticapps-workflow setup-agenticapps-workflow update-agenticapps-workflow \
              setup-codex-agenticapps-workflow update-opencode-agenticapps-workflow; do
  printf '%s' "$RUN_OUT" | grep -q "$legacy" || unreported="$unreported $legacy"
done
survivors=""
for legacy in setup-agenticapps-workflow update-agenticapps-workflow \
              setup-codex-agenticapps-workflow update-opencode-agenticapps-workflow; do
  if [ -e "$CLAUDE_SKILLS/$legacy" ] || [ -L "$CLAUDE_SKILLS/$legacy" ]; then
    survivors="$survivors $legacy"
  fi
done
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ -n "$unreported" ]; then
  bad "$CASE_NAME" "acted on without reporting by name:$unreported"
elif [ -n "$survivors" ]; then
  bad "$CASE_NAME" "legacy names the manifest marks 'remove' survived:$survivors"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.9: the negative test, which must not consult the manifest"
bind_case "a binding into an archived checkout under an UNLISTED name is still found and reported"
# This is the case the manifest cannot pass by construction. The name is not one
# core has ever shipped, so iterating skills/ misses it and iterating the
# manifest misses it; only a scan of the directory itself sees it. A gap in the
# manifest is exactly this shape, and it surfaces months later as a dangling
# skill when someone deletes a checkout.
ln -s "$(archived_skill pi-agentic-apps-workflow some-forgotten-skill)" \
      "$CLAUDE_SKILLS/some-forgotten-skill"
run_install --host claude
still="$(readlink "$CLAUDE_SKILLS/some-forgotten-skill" 2>/dev/null)"
if ! require_ran; then :
elif ! printf '%s' "$RUN_OUT" | grep -q 'some-forgotten-skill'; then
  bad "$CASE_NAME" "an archived binding under an unlisted name was neither resolved nor reported" \
                   "if this only passes when the manifest names it, the sweep is reading the wrong source" \
                   "$(printf '%s' "$RUN_OUT" | head -3)"
elif printf '%s' "$still" | grep -q 'pi-agentic-apps-workflow'; then
  bad "$CASE_NAME" "the binding still resolves into an archived checkout: $still"
elif [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "nothing was left unresolved, so the run should exit 0 (got $RUN_RC)"
else
  ok "$CASE_NAME"
fi
finish_case

bind_case "a vendored copy is never rebound to another host's archived binding"
# Both hosts hold an archived binding for the same skill. Resolving one to the
# other would report success and leave the machine still pointing into a
# checkout that is about to be deleted — converted-looking, still broken.
mkdir -p "$CASE_HOME/.codex/skills"
ln -s "$(archived_skill claude-workflow cso)"  "$CLAUDE_SKILLS/cso"
ln -s "$(archived_skill codex-workflow cso)"   "$CASE_HOME/.codex/skills/codex-cso"
run_install --host claude --host codex
left=""
for p in "$CLAUDE_SKILLS/cso" "$CASE_HOME/.codex/skills/codex-cso"; do
  [ -L "$p" ] && case "$(readlink "$p")" in *-workflow/*) left="$left $(basename "$p")" ;; esac
done
if ! require_ran; then :
elif [ -n "$left" ]; then
  bad "$CASE_NAME" "still resolving into an archived checkout after the run:$left"
else
  ok "$CASE_NAME"
fi
finish_case

bind_case "a binding this workflow did not install is left completely alone"
# The real machine has `observability` sitting in ~/.codex/skills next to twelve
# workflow-installed bindings, pointing at a repo the workflow does not own. The
# removal criterion is "did we install it", not "is there an equivalent" — and
# nothing but is_archived enforces that, so it gets a test.
mkdir -p "$CASE_DIR/somebody-elses-repo/a-skill"
ln -s "$CASE_DIR/somebody-elses-repo/a-skill" "$CLAUDE_SKILLS/their-skill"
before="$(readlink "$CLAUDE_SKILLS/their-skill")"
run_install --host claude
after="$(readlink "$CLAUDE_SKILLS/their-skill" 2>/dev/null)"
if ! require_ran; then :
elif [ "$before" != "$after" ]; then
  bad "$CASE_NAME" "a binding the workflow never installed was touched" "was $before, now ${after:-REMOVED}"
elif printf '%s' "$RUN_OUT" | grep -q 'their-skill'; then
  bad "$CASE_NAME" "an unrelated binding was reported as if it were ours"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 3.10: what is replaced is preserved, and the restore command is stated"
bind_case "a replaced binding is preserved at a reported path with a restore command"
mkdir -p "$CLAUDE_SKILLS/agentic-apps-workflow"
printf 'work that must survive\n' > "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md"
run_install --host claude --replace-unrecognised
preserved="$(printf '%s' "$RUN_OUT" | grep -oE '[^[:space:]]*agentic-apps-workflow[^[:space:]]*pre-install[^[:space:]]*' | head -1)"
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0 with consent given, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ -z "$preserved" ]; then
  bad "$CASE_NAME" "no preserved path was reported" "$(printf '%s' "$RUN_OUT" | head -5)"
elif [ ! -f "$preserved/SKILL.md" ]; then
  bad "$CASE_NAME" "the reported path does not hold what was replaced: $preserved"
elif ! grep -q 'work that must survive' "$preserved/SKILL.md"; then
  bad "$CASE_NAME" "the preserved copy does not match what was replaced"
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'restore|mv |cp '; then
  bad "$CASE_NAME" "no restore command was stated"
else
  ok "$CASE_NAME"
fi
finish_case

# ── No host configuration ──────────────────────────────────────────────────
# The change is named for this. A test that only checks the wiring functions
# are gone would pass against an installer that wrote the same files by another
# route, so these assert the FILES, not the absence of the code.

echo
echo "install.sh — task 4.1: a host gets skills and nothing else"
bind_case "binding a host creates and modifies no file the host reads as configuration"
mkdir -p "$CASE_HOME/.codex" "$CASE_HOME/.config/opencode"
printf '{"model":"sonnet"}\n' > "$CASE_HOME/.claude/settings.json"
before="$(md5 -q "$CASE_HOME/.claude/settings.json" 2>/dev/null || md5sum "$CASE_HOME/.claude/settings.json" | cut -d' ' -f1)"
host_exec claude; host_exec codex; host_exec opencode
run_install --host auto
after="$(md5 -q "$CASE_HOME/.claude/settings.json" 2>/dev/null || md5sum "$CASE_HOME/.claude/settings.json" | cut -d' ' -f1)"
stray="$(ls -d "$CASE_HOME/.codex/hooks.json" \
                "$CASE_HOME/.config/opencode/plugin/openspec-change-gate.ts" 2>/dev/null | head -1)"
if ! require_ran; then :
elif [ "$before" != "$after" ]; then
  bad "$CASE_NAME" "the host's settings file was modified" "$CASE_HOME/.claude/settings.json"
elif [ -n "$stray" ]; then
  bad "$CASE_NAME" "a host configuration file was created" "$stray"
elif [ ! -L "$CASE_HOME/.claude/skills/agentic-apps-workflow" ]; then
  bad "$CASE_NAME" "skills were not bound — the run did nothing rather than the right thing"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 4.2: the removed opt-in fails loudly"
new_case "--accept-host-config is an unknown argument, not a silently accepted one"
run_install --accept-host-config
if [ "$RUN_RC" -ne 64 ]; then
  bad "$CASE_NAME" "expected exit 64 for an unknown argument, got $RUN_RC" \
                   "$(printf '%s' "$RUN_OUT" | head -3)"
elif ! printf '%s' "$RUN_OUT" | grep -qi 'unknown argument'; then
  bad "$CASE_NAME" "the unknown argument was not named" "$(printf '%s' "$RUN_OUT" | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 4.3: no host-specific artifact is published"
new_case "the installer references no codex adapter and no opencode plugin"
hits="$(grep -cE 'hosts/(codex|opencode)|openspec-change-gate\.ts|hooks\.json|settings\.json' "$ROOT/install.sh" || true)"
if [ "$hits" -ne 0 ]; then
  bad "$CASE_NAME" "install.sh still references a host configuration artifact ($hits line(s))" \
                   "$(grep -nE 'hosts/(codex|opencode)|openspec-change-gate\.ts|hooks\.json|settings\.json' "$ROOT/install.sh" | head -3)"
elif [ -d "$ROOT/hosts" ]; then
  bad "$CASE_NAME" "hosts/ still exists"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 4.14: detection is by evidence, and a shared directory names both hosts"
bind_case "a host directory without the host installed is not bound"
mkdir -p "$CASE_HOME/.codex/skills"        # the directory exists...
host_exec claude                            # ...but only claude is installed
PATH_OVERRIDE="$CASE_BIN:$(farm_without codex)"
run_install --host auto
if ! require_ran; then :
elif [ -e "$CASE_HOME/.codex/skills/agentic-apps-workflow" ]; then
  bad "$CASE_NAME" "codex was bound on the evidence of a directory alone"
elif [ ! -L "$CASE_HOME/.claude/skills/agentic-apps-workflow" ]; then
  bad "$CASE_NAME" "claude was installed and was not bound"
else
  ok "$CASE_NAME"
fi
finish_case

bind_case "the shared host-neutral skills directory is reported once, naming both hosts"
host_exec pi; host_exec omp
run_install --host auto
shared_lines="$(printf '%s' "$RUN_OUT" | grep -c '\.agents/skills')"
if ! require_ran; then :
elif [ "$shared_lines" -gt 1 ]; then
  bad "$CASE_NAME" "the shared directory was reported $shared_lines times, expected once"
elif ! printf '%s' "$RUN_OUT" | grep -qi 'pi' || ! printf '%s' "$RUN_OUT" | grep -qi 'omp'; then
  bad "$CASE_NAME" "the shared binding did not name both hosts that read it" \
                   "$(printf '%s' "$RUN_OUT" | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

# ── Check mode ─────────────────────────────────────────────────────────────

GATE_SRC="$ROOT/reference-implementations/openspec-change-gate/openspec-change-gate.sh"
checkout_version() { grep -m1 -oE "$1: *[0-9]+\.[0-9]+\.[0-9]+" "$2" | awk '{print $2}'; }

# Put an artifact in the published location at a chosen version and content.
# Content defaults to the checkout's, so "same version, same bytes" is the easy
# case and every interesting state is a deliberate deviation from it.
publish_fake() {
  local name="$1" key="$2" ver="$3" body="${4:-}"
  mkdir -p "$CASE_HOME/.agenticapps/bin"
  local dst="$CASE_HOME/.agenticapps/bin/$name"
  if [ -n "$body" ]; then
    { printf '#!/usr/bin/env bash\n# %s: %s\n%s\n' "$key" "$ver" "$body"; } > "$dst"
  else
    sed "s/^# $key: .*/# $key: $ver/" "$GATE_SRC" > "$dst"
  fi
  chmod 755 "$dst"
}

# Every file under the case home, by content. Used for "changed nothing" and
# "twice is the same" — both of which are claims about the whole sandbox, not
# about one path.
case_state() {
  find "$CASE_HOME" \( -type f -o -type l \) -print0 2>/dev/null \
    | sort -z \
    | xargs -0 -I{} sh -c 'if [ -L "{}" ]; then printf "%s -> %s\n" "{}" "$(readlink "{}")"; else shasum "{}"; fi' 2>/dev/null \
    | sort
}

echo
echo "install.sh — task 5.1: check mode reports absence and writes nothing"
new_case "--check on an empty home reports everything absent and creates no file"
new_core
before_state="$(case_state)"
run_install --check
after_state="$(case_state)"
if ! require_ran; then :
elif [ "$before_state" != "$after_state" ]; then
  bad "$CASE_NAME" "check mode created or modified a file" \
                   "$(diff <(printf '%s' "$before_state") <(printf '%s' "$after_state") | head -4)"
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'absent|not installed|missing|—'; then
  bad "$CASE_NAME" "nothing was reported as absent" "$(printf '%s' "$RUN_OUT" | head -5)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — fresh-clone-needs-nothing task 9: the openspec tooling is bound machine-level"
new_case "the binder is delegated to, once, naming every requested host"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
stub_helper reference-implementations/openspec-tools/bind-openspec-tools.sh     OPSXBIND 0
run_install --host claude --host codex
binder_calls="$(calls | grep -c '^OPSXBIND')"
if [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "expected exit 0, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif [ "$binder_calls" -ne 1 ]; then
  bad "$CASE_NAME" "expected exactly one binder call, saw $binder_calls" \
                   "install.sh delegates; per-host knowledge belongs in the binder" \
                   "calls: $(calls | tr '\n' ';')"
elif ! calls | grep '^OPSXBIND' | grep -q -- '--host claude'; then
  bad "$CASE_NAME" "claude was not named to the binder" "calls: $(calls | grep '^OPSXBIND')"
elif ! calls | grep '^OPSXBIND' | grep -q -- '--host codex'; then
  bad "$CASE_NAME" "codex was not named to the binder" "calls: $(calls | grep '^OPSXBIND')"
else
  ok "$CASE_NAME"
fi
finish_case

new_case "a binder failure is reported and does not fail the whole install"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
# 1 is what the binder returns when it could not generate, or when a name
# collided. Neither means the workflow failed to install.
stub_helper reference-implementations/openspec-tools/bind-openspec-tools.sh     OPSXBIND 1
run_install --host claude
if ! printf '%s' "$RUN_OUT" | grep -qiE 'opsx|openspec tooling|binder'; then
  bad "$CASE_NAME" "a binder failure was silent" "$(printf '%s' "$RUN_OUT" | tail -4)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — fresh-clone-needs-nothing task 4.1c: the initializer is reported like the others"
new_case "--check names the initializer"
new_core
run_install --check
if ! require_ran; then :
elif ! printf '%s' "$RUN_OUT" | grep -q 'init-project'; then
  bad "$CASE_NAME" "check mode does not report the initializer" \
                   "an artifact that installs but never appears in --check is invisible state" \
                   "$(printf '%s' "$RUN_OUT" | head -6)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 5.2: an artifact behind the checkout is present and not current"
new_case "--check names both versions and marks a stale artifact not current"
new_core
gate_ver="$(checkout_version gate-version "$GATE_SRC")"
publish_fake openspec-change-gate.sh gate-version 0.0.1
run_install --check
if ! require_ran; then :
elif ! printf '%s' "$RUN_OUT" | grep -q '0\.0\.1'; then
  bad "$CASE_NAME" "the published version was not named" "$(printf '%s' "$RUN_OUT" | head -5)"
elif ! printf '%s' "$RUN_OUT" | grep -q "$gate_ver"; then
  bad "$CASE_NAME" "the checkout's version ($gate_ver) was not named"
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'stale|not current|behind|outdated'; then
  bad "$CASE_NAME" "a stale artifact was not marked not current"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 5.3: currency is by content, and a marker cannot fake it"
new_case "an artifact hand-edited at the checkout's own version is reported not current"
new_core
gate_ver="$(checkout_version gate-version "$GATE_SRC")"
# The marker says current. The bytes do not. This is the case a
# marker-comparison implementation passes wrongly, and it is the reason
# workflow-installation judges currency against an authority checkout. The
# requirement was project-hook-binding's until the publisher retired; its
# subject here is check_artifact, which survives, so it moved rather than went.
publish_fake openspec-change-gate.sh gate-version "$gate_ver" 'echo "somebody edited me"'
run_install --check
if ! require_ran; then :
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'modified|edited|differs|not current'; then
  bad "$CASE_NAME" "a hand-edited artifact at the same version reported as current" \
                   "this is what comparing markers to markers cannot see" \
                   "$(printf '%s' "$RUN_OUT" | head -5)"
elif printf '%s' "$RUN_OUT" | grep -qiE 'stale|behind'; then
  bad "$CASE_NAME" "an edited artifact was reported as merely stale, which it is not"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 5.4: an artifact ahead of the checkout is neither stale nor current"
new_case "--check reports a newer published artifact as ahead"
new_core
publish_fake openspec-change-gate.sh gate-version 99.0.0
run_install --check
if ! require_ran; then :
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'ahead|newer'; then
  bad "$CASE_NAME" "a newer artifact was not reported as ahead" "$(printf '%s' "$RUN_OUT" | head -5)"
elif printf '%s' "$RUN_OUT" | grep -qiE 'stale|behind'; then
  bad "$CASE_NAME" "an artifact ahead of the checkout was called stale"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 5.5: unreadable is its own state, not absent and not current"
new_case "an unreadable artifact and an unparseable marker are each reported as such"
new_core
publish_fake openspec-change-gate.sh gate-version 1.0.0
chmod 000 "$CASE_HOME/.agenticapps/bin/openspec-change-gate.sh"
publish_fake reviewer-cli.sh reviewer-cli-version 1.0.0 'no marker here at all'
sed -i.bak '/reviewer-cli-version/d' "$CASE_HOME/.agenticapps/bin/reviewer-cli.sh" 2>/dev/null
rm -f "$CASE_HOME/.agenticapps/bin/reviewer-cli.sh.bak"
run_install --check
chmod 644 "$CASE_HOME/.agenticapps/bin/openspec-change-gate.sh" 2>/dev/null
if ! require_ran; then :
elif ! printf '%s' "$RUN_OUT" | grep -qiE 'unreadable|cannot read|unparse|no marker|unknown version'; then
  bad "$CASE_NAME" "neither unreadable state was reported distinctly" \
                   "$(printf '%s' "$RUN_OUT" | head -6)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 5.6: bound and unbound hosts are distinguished"
new_case "an unrequested unbound host does not by itself make check mode exit non-zero"
new_core
mkdir -p "$CASE_HOME/.claude/skills"
ln -s "$CASE_CORE/skills/agentic-apps-workflow" "$CASE_HOME/.claude/skills/agentic-apps-workflow"
run_install --check
if ! require_ran; then :
elif [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "check mode exited $RUN_RC with nothing requested and nothing wrong"
elif ! printf '%s' "$RUN_OUT" | grep -qi 'claude'; then
  bad "$CASE_NAME" "the bound host was not reported" "$(printf '%s' "$RUN_OUT" | head -5)"
elif ! printf '%s' "$RUN_OUT" | grep -qi 'codex'; then
  bad "$CASE_NAME" "an unbound host was not distinguished from a bound one"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 5.7: a full run twice leaves the same machine"
new_case "two identical runs leave identical state and the second creates no new bindings"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
run_install --host claude --host pi
first_state="$(case_state)"
run_install --host claude --host pi
second_state="$(case_state)"
# No backup is expected between these two runs, and that is not in tension with
# task 6.1: a backup is taken when something is REPLACED, and the second run
# finds every binding already correct. 6.1 re-seeds a foreign target each time,
# so each of its runs genuinely replaces something.
if ! require_ran; then :
elif [ "$first_state" != "$second_state" ]; then
  bad "$CASE_NAME" "the second run changed the machine" \
                   "$(diff <(printf '%s' "$first_state") <(printf '%s' "$second_state") | head -6)"
elif [ "$RUN_RC" -ne 0 ]; then
  bad "$CASE_NAME" "the second run exited $RUN_RC"
else
  ok "$CASE_NAME"
fi
finish_case

# ── Preserved copies ───────────────────────────────────────────────────────

echo
echo "install.sh — task 6.1: preserved copies do not overwrite one another"
new_case "replacing the same target twice leaves both preserved copies"
new_core
mkdir -p "$CASE_HOME/.claude/skills"
CLAUDE_SKILLS="$CASE_HOME/.claude/skills"
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
mkdir -p "$CLAUDE_SKILLS/agentic-apps-workflow"; printf 'first\n'  > "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md"
run_install --host claude --replace-unrecognised
rm -rf "$CLAUDE_SKILLS/agentic-apps-workflow"
mkdir -p "$CLAUDE_SKILLS/agentic-apps-workflow"; printf 'second\n' > "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md"
run_install --host claude --replace-unrecognised
VAULT="$CASE_HOME/.agenticapps/pre-install/.claude/skills"
kept="$(grep -rl 'first' "$VAULT"/*pre-install* 2>/dev/null | head -1)"
n_backups="$(ls -d "$VAULT"/*pre-install* 2>/dev/null | wc -l | tr -d ' ')"
if ! require_ran; then :
elif [ "$n_backups" -lt 2 ]; then
  bad "$CASE_NAME" "expected two preserved copies, found $n_backups"
elif [ -z "$kept" ]; then
  bad "$CASE_NAME" "the first preserved copy was overwritten by the second"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 6.1b: a preserved skill leaves the directory the host scans"
# Round-three review finding (codex, HIGH). A preserved skill is still a skill:
# a loader that deep-scans nested SKILL.md re-registers the backup under the
# name it was preserved from, so the run deletes one copy of the trigger skill
# and creates another beside it. The archived-binding scan cannot catch it —
# the survivor is a copy, not a symlink.
new_case "a backup of a removed skill is written outside the skill directory"
new_core
mkdir -p "$CASE_HOME/.claude/skills"; CLAUDE_SKILLS="$CASE_HOME/.claude/skills"
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
mkdir -p "$CLAUDE_SKILLS/agenticapps-workflow/skill"
printf 'name: agentic-apps-workflow\n' > "$CLAUDE_SKILLS/agenticapps-workflow/skill/SKILL.md"
run_install --host claude --replace-unrecognised
left="$(ls -d "$CLAUDE_SKILLS"/*pre-install* 2>/dev/null | head -1)"
nested="$(find "$CLAUDE_SKILLS" -name SKILL.md -path '*pre-install*' 2>/dev/null | head -1)"
b="$(ls -d "$CASE_HOME/.agenticapps/pre-install/.claude/skills"/*pre-install* 2>/dev/null | head -1)"
if ! require_ran; then :
elif [ -n "$left" ]; then
  bad "$CASE_NAME" "a preserved copy was left in the directory the host scans" "$left"
elif [ -n "$nested" ]; then
  bad "$CASE_NAME" "a preserved SKILL.md is still discoverable under the skill directory" "$nested"
elif [ -z "$b" ]; then
  bad "$CASE_NAME" "nothing was preserved outside the skill directory"
elif [ ! -f "$b/skill/SKILL.md" ]; then
  bad "$CASE_NAME" "the preserved copy does not hold what was removed: $b"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 6.2: a preserved copy keeps the permissions it preserved"
new_case "a preserved copy carries the mode of what it replaced"
new_core
mkdir -p "$CASE_HOME/.claude/skills"; CLAUDE_SKILLS="$CASE_HOME/.claude/skills"
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
printf 'notes\n' > "$CLAUDE_SKILLS/agentic-apps-workflow"; chmod 640 "$CLAUDE_SKILLS/agentic-apps-workflow"
run_install --host claude --replace-unrecognised
b="$(ls -d "$CASE_HOME/.agenticapps/pre-install/.claude/skills"/*pre-install* 2>/dev/null | head -1)"
if ! require_ran; then :
elif [ -z "$b" ]; then
  bad "$CASE_NAME" "nothing was preserved"
elif [ "$(stat -f '%Lp' "$b" 2>/dev/null || stat -c '%a' "$b" 2>/dev/null)" != "640" ]; then
  bad "$CASE_NAME" "preserved copy mode is $(stat -f '%Lp' "$b" 2>/dev/null), expected 640"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 6.3: a preservation that fails aborts the step"
new_case "when the preserved copy cannot be written, the target is left unmodified"
new_core
mkdir -p "$CASE_HOME/.claude/skills"; CLAUDE_SKILLS="$CASE_HOME/.claude/skills"
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
printf 'irreplaceable\n' > "$CLAUDE_SKILLS/agentic-apps-workflow"
# The directory the backup would be written into is read-only, so preserving is
# impossible while replacing is not. Proceeding here would destroy the only copy.
chmod 555 "$CLAUDE_SKILLS"
run_install --host claude --replace-unrecognised
chmod 755 "$CLAUDE_SKILLS"
if ! require_ran; then :
elif [ ! -f "$CLAUDE_SKILLS/agentic-apps-workflow" ] || ! grep -q irreplaceable "$CLAUDE_SKILLS/agentic-apps-workflow"; then
  bad "$CASE_NAME" "the target was destroyed although it could not be preserved"
elif [ "$RUN_RC" -eq 0 ]; then
  bad "$CASE_NAME" "a step that could not proceed safely must not exit 0"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "install.sh — task 6.4: the restore command printed actually restores"
new_case "running the stated restore command verbatim brings back what was replaced"
new_core
mkdir -p "$CASE_HOME/.claude/skills"; CLAUDE_SKILLS="$CASE_HOME/.claude/skills"
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
mkdir -p "$CLAUDE_SKILLS/agentic-apps-workflow"
printf 'the thing to get back\n' > "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md"
run_install --host claude --replace-unrecognised
# A restore command that is printed but never executed is documentation, and
# documentation is not a rollback plan. This runs it.
restore="$(printf '%s' "$RUN_OUT" | grep -oE '(rm -rf [^;]+; *)?mv +[^[:space:]]+ +[^[:space:]]+' | head -1)"
if ! require_ran; then :
elif [ -z "$restore" ]; then
  bad "$CASE_NAME" "no runnable restore command was printed" "$(printf '%s' "$RUN_OUT" | head -6)"
else
  ( cd "$CASE_HOME" && eval "$restore" ) >/dev/null 2>&1
  if [ -f "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md" ] &&
     grep -q 'the thing to get back' "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md"; then
    ok "$CASE_NAME"
  else
    bad "$CASE_NAME" "the restore command ran and did not restore: $restore"
  fi
fi
finish_case

echo
echo "install.sh — task 8.8: what the round-five code review found"

new_case "a bare --host is a usage error, not a shell error"
new_core
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED 0
stub_helper reference-implementations/global-floor/bind-global-floor.sh FLOORBIND 0
# `set -u` is on. Before the guard, a trailing `--host` expanded an unset $2 and
# aborted with the shell's own message and the shell's own status — the one bad
# argument in the parser that did not get the usage error every other one gets.
run_install --host
if ! require_ran; then :
elif [ "$RUN_RC" -ne 64 ]; then
  bad "$CASE_NAME" "expected the usage status 64, got $RUN_RC" "$(printf '%s' "$RUN_OUT" | head -3)"
elif ! printf '%s' "$RUN_OUT" | grep -q 'host name'; then
  bad "$CASE_NAME" "exited 64 without saying what was missing" "$(printf '%s' "$RUN_OUT" | head -3)"
else
  ok "$CASE_NAME"
fi
finish_case

bind_case "a vendored binding is not rebound to something that is not a skill"
# `[ -e ]` was the whole test for a candidate, so an empty directory or a stray
# file named `cso` satisfied the search and the binding was rebound to a
# non-skill — reported as a rebind, indistinguishable from a real one. Carrying
# a SKILL.md is the test now. Removal is the correct outcome here.
mkdir -p "$CASE_HOME/.agents/skills/cso"
mkdir -p "$CASE_HOME/.codex/skills"
ln -s "$(archived_skill codex-workflow cso)" "$CASE_HOME/.codex/skills/codex-cso"
run_install --host codex
after="$(readlink "$CASE_HOME/.codex/skills/codex-cso" 2>/dev/null)"
if ! require_ran; then :
elif [ -n "$after" ]; then
  bad "$CASE_NAME" "rebound to a candidate carrying no SKILL.md: $after"
elif ! printf '%s' "$RUN_OUT" | grep -q 'no host-neutral equivalent'; then
  bad "$CASE_NAME" "the binding went without the run saying why" "$(printf '%s' "$RUN_OUT" | head -4)"
else
  ok "$CASE_NAME"
fi
finish_case

bind_case "the printed restore command quotes the paths it names"
# Task 6.4 proves the command runs; it runs under paths with no spaces in them.
# A home directory with a space turned the advertised command into two wrong
# ones, and an operator finds that out at the moment they need it to work.
mkdir -p "$CLAUDE_SKILLS/agentic-apps-workflow"
printf 'work that must survive\n' > "$CLAUDE_SKILLS/agentic-apps-workflow/SKILL.md"
run_install --host claude --replace-unrecognised
if ! require_ran; then :
elif ! printf '%s' "$RUN_OUT" | grep -q 'restore: *rm -rf "'; then
  bad "$CASE_NAME" "the restore command names its paths unquoted" \
                   "$(printf '%s' "$RUN_OUT" | grep restore | head -2)"
else
  ok "$CASE_NAME"
fi
finish_case

# Code review M1 — "a step reports its OWN outcome" — lived here as a pair of
# cases, and both went with the publisher at 3.13e. The rule they encoded was
# that a step's report must not be conditioned on `$SKIPPED`, and the
# project-hook delegation was its only subject: what publish() reports now is
# one line per artifact from the case statement, which consults nothing outside
# the call it is reporting on. A case whose subject is gone proves only that it
# can describe the present.

echo
echo "install.sh — code review M3: --host auto ADDS to the named set, never replaces it"
# `REQUESTED="$(detect)"` threw away every host the operator had named. On a
# machine where the named host is not installed — the exact case for naming it
# rather than relying on detection — the request vanished silently and the run
# reported success having not bound it.
new_case "a host named alongside --host auto is bound even when detection cannot find it"
new_core
host_exec claude                 # detectable
# EVERY host this installer knows is on the real PATH of the machine this was
# written on, and the case's PATH ends in the real one — so `detect` found codex
# by itself and the assertion passed while proving nothing. The host that must
# be undetectable has to be made so explicitly.
hide_command codex
stub_helper reference-implementations/shared-install/install-shared-artifact.sh SHARED    0
stub_helper reference-implementations/global-floor/bind-global-floor.sh         FLOORBIND 0
stub_helper reference-implementations/openspec-tools/bind-openspec-tools.sh     OPSXBIND  0
run_install --host auto --host codex
if ! require_ran; then :
elif [ ! -L "$CASE_HOME/.claude/skills/agentic-apps-workflow" ]; then
  bad "$CASE_NAME" "the DETECTED host was not bound" "$(printf '%s' "$RUN_OUT" | head -6)"
elif [ ! -L "$CASE_HOME/.codex/skills/agentic-apps-workflow" ]; then
  bad "$CASE_NAME" "the explicitly named host was dropped by --host auto" \
                   "$(printf '%s' "$RUN_OUT" | head -6)"
else
  ok "$CASE_NAME"
fi
finish_case

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
