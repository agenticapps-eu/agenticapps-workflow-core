#!/usr/bin/env bash
# bind-global-floor.sh — publish the machine-level pre-commit and bind it.
#
# One act, at the level it belongs to. The gate's hook is published once to
# ~/.agenticapps/git-hooks/ and bound with `git config --global core.hooksPath`,
# so every enrolled repository is covered without being visited. Nine
# repositories on the machine this was measured on carried the gate at four
# different sizes and no surface named the divergence; a per-repository copy is
# a fork that nothing reports has forked.
#
# THE ORDER IS THE POINT: PUBLISH, THEN BIND.
#
# Binding first and failing before the hook lands leaves core.hooksPath pointing
# at a directory with no pre-commit — and a commit under that binding SUCCEEDS
# SILENTLY, verified on git 2.50.1. The machine is then globally unbound in
# effect while every surface reports it as bound. Publishing first means the
# worst partial state is a published hook nothing has bound yet, which is the
# floor as it exists today and is therefore no regression at all. The two orders
# are not symmetric and the safe one costs nothing.
#
# PUBLISHING IS DELEGATED, NEVER REIMPLEMENTED. install-shared-artifact.sh
# carries the version arbitration, downgrade refusal and cross-installer lock
# that make "the destination is at least as new as the source" true under
# concurrency. A `cp` here would produce the same bytes on a clean machine and
# silently overwrite a newer published hook on any other.
#
# Exit 0 = published and bound, or already so.
# Exit 1 = refused (a foreign binding) or failed (publish or bind). In both
#          cases the caller reports the step as skipped, so the run exits
#          non-zero rather than claiming a floor the machine does not have.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SELF_DIR/pre-commit"
SHARED="$SELF_DIR/../shared-install/install-shared-artifact.sh"

# Pinned by the spec delta rather than chosen here, because `--check` must
# verify that core.hooksPath "resolves to the published directory" and that is
# unverifiable while the directory is named only in prose.
HOOKS_DIR="$HOME/.agenticapps/git-hooks"
MARKER_KEY='global-floor-version'

say() { printf 'global-floor: %s\n' "$*"; }

# DECLARED PREREQUISITE (§21). Reported by name, and never offered: git is a
# system runtime. Without the check the failure arrives as git's own "command
# not found", which names the symptom rather than the missing tool.
command -v git >/dev/null 2>&1 || {
  say "missing: git — the floor is bound by setting core.hooksPath in global"
  say "git configuration, so it cannot be bound without it. Install git, then re-run."
  exit 1; }

# ── The published directory ────────────────────────────────────────────────
# The dispatcher refuses a symlinked or group/world-writable `hooks.d`, because
# either lets another local account supply code that runs on every commit. It
# cannot make the same check about the directory it LIVES in: by the time the
# dispatcher runs, anyone who could write there has already replaced it. So the
# guard is applied one level up, here, before anything is published into it.
#
# The symlink check must come BEFORE mkdir. `mkdir -p` over an existing symlink
# succeeds silently, and measured before this was written: the run then
# published the dispatcher into the link's target and bound core.hooksPath to
# it — handing the machine's commit-time hook directory to whoever owned the
# target.
if [ -L "$HOOKS_DIR" ]; then
  say "REFUSED — $HOOKS_DIR is a symlink. The directory git runs hooks from"
  say "must be one you own outright; a symlink redirects all of them at once."
  exit 1
fi

mkdir -p "$HOOKS_DIR" || { say "FAILED to create $HOOKS_DIR. Nothing was bound."; exit 1; }

# `find -perm` rather than `stat`, whose format flags differ between macOS and
# GNU. The mode otherwise comes from the operator's umask, which is 022 on a
# stock macOS and is not guaranteed to be.
if [ -n "$(find "$HOOKS_DIR" -maxdepth 0 \( -perm -g+w -o -perm -o+w \) 2>/dev/null)" ]; then
  say "REFUSED — $HOOKS_DIR is group- or world-writable, so another local user"
  say "could replace the hook that runs on every commit you make. chmod 755 it."
  exit 1
fi

# ── Publish ────────────────────────────────────────────────────────────────

"$SHARED" "$SRC" "$HOOKS_DIR/pre-commit" "$MARKER_KEY" >/dev/null 2>&1
rc=$?
case $rc in
  0) say "published pre-commit to $HOOKS_DIR" ;;
  # Exit 3 is the helper's documented SUCCESS: the destination already holds a
  # strictly newer version, so "at least as new as the source" holds either
  # way. Calling it a failure would refuse to bind a machine that is more
  # current than this checkout — correct state, reported as broken.
  3) say "satisfied pre-commit — destination already newer" ;;
  *) say "FAILED to publish pre-commit to $HOOKS_DIR (exit $rc)."
     say "core.hooksPath was NOT set: a binding with no hook behind it commits silently."
     exit 1 ;;
esac

# ── Bind ───────────────────────────────────────────────────────────────────
# `--type=path` so git expands a `~` the operator wrote by hand; `--get`
# returns the raw string otherwise and the comparison below would miss.
current="$(git config --global --get --type=path core.hooksPath 2>/dev/null)"

# Raw equality first, then physical paths. On macOS a home directory reached
# through a symlink spells the same directory two ways, and a binder that
# reported its own binding as foreign would refuse permanently.
same_dir() {
  [ "$1" = "$2" ] && return 0
  local a b
  a="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
  b="$(cd "$2" 2>/dev/null && pwd -P)" || return 1
  [ -n "$a" ] && [ "$a" = "$b" ]
}

if [ -z "$current" ]; then
  git config --global core.hooksPath "$HOOKS_DIR" || {
    say "FAILED to set core.hooksPath. The hook is published but the machine is UNBOUND."
    exit 1; }
  say "bound core.hooksPath -> $HOOKS_DIR"
elif same_dir "$current" "$HOOKS_DIR"; then
  say "satisfied — core.hooksPath already resolves to $HOOKS_DIR"
else
  # Reported, never overwritten. An operator who has bound a hooks directory
  # did so deliberately, and a tool that silently rebinds it retakes a decision
  # that was already made — machine-wide, at commit time. This is the posture
  # the git-hook installer already takes toward a foreign hook, one level up.
  say "REFUSED — core.hooksPath is already set to $current"
  say "This workflow would have set $HOOKS_DIR. The global configuration is unchanged."
  say "Composition belongs in $HOOKS_DIR/hooks.d, which the published hook runs."
  exit 1
fi
