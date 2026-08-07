#!/usr/bin/env bash
# install.sh — the one entry point that puts this workflow on a machine.
#
#   ./install.sh                          payload + core's git pre-commit hook
#   ./install.sh --host claude --host pi  ...plus skills for the named hosts
#   ./install.sh --host auto              ...for whichever hosts are installed
#   ./install.sh --check                  report state, change nothing
#
# THIS IS A FRONT END. Publishing and hook installation are delegated, never
# reimplemented: those helpers carry version arbitration, downgrade refusal,
# cross-installer locking, atomic replacement, attestation, and hooks-directory
# resolution that tolerates linked worktrees and core.hooksPath. A front end
# that reimplements its back end acquires the back end's bugs without its fixes.
#
# IT WRITES NO HOST CONFIGURATION. A host gets skills, and nothing else. The
# enforcement floor is git and CI, which every host shares; the per-host hook
# was the only host-specific thing here and it is not coming back by accident.
#
# Tier 1 is git and bash. Nothing else may hard-fail the install.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.agenticapps/bin"
SHARED="$ROOT/reference-implementations/shared-install/install-shared-artifact.sh"
PROJHOOKS="$ROOT/reference-implementations/shared-install/install-project-hooks.sh"
COREHOOKS="$ROOT/tools/install-core-git-hooks.sh"
OPSXBIND="$ROOT/reference-implementations/openspec-tools/bind-openspec-tools.sh"

# Published through the ARBITRATING helper, one call each, with the marker key
# that makes its version comparison work. The project-hook set is NOT here: it
# goes through the ATTESTING installer below, which writes the manifest that
# project-hook-binding requires and that this helper does not.
ARTIFACTS="openspec-change-gate/openspec-change-gate.sh:gate-version
run-plan-review/run-plan-review.sh:run-plan-review-version
reviewer-cli/reviewer-cli.sh:reviewer-cli-version
init-project/init-project.sh:init-project-version"

# host : skill directory (under $HOME) : executable that proves it is installed
HOSTS="claude:.claude/skills:claude
codex:.codex/skills:codex
opencode:.config/opencode/skills:opencode
pi:.agents/skills:pi
omp:.agents/skills:omp"

# Names this workflow installed under that the archived-symlink sweep cannot
# see, because they are not symlinks. `agenticapps-workflow` is a real directory
# holding a copied skill — the hyphenless duplicate of the trigger skill, and
# the second of the two files that both claimed to be it.
LEGACY_DIRS="agenticapps-workflow"

# A tombstone list, not a dependency: nothing is read from these at install
# time. Matched as a substring of the RESOLVED target so the judgement does not
# depend on where the checkouts happened to live.
ARCHIVED="claude-workflow codex-workflow opencode-workflow pi-agentic-apps-workflow"

MODE=install
REQUESTED=""
REPLACE_UNRECOGNISED="${INSTALL_REPLACE_UNRECOGNISED:-0}"
SKIPPED=0

say()  { printf '%s\n' "$*"; }
skip() { printf 'SKIPPED: %s\n' "$*"; SKIPPED=$((SKIPPED + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }
field() { printf '%s' "$1" | cut -d: -f"$2"; }
marker() { grep -m1 -oE "^# $1: *[0-9]+\.[0-9]+\.[0-9]+" "$2" 2>/dev/null | awk '{print $3}'; }
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  say "  --replace-unrecognised   replace an unrecognised binding target (INSTALL_REPLACE_UNRECOGNISED=1)"
}

# ── Recoverability ─────────────────────────────────────────────────────────
# Scoped to what this script replaces with its own hands. Published artifacts
# are NOT covered: their installer holds a lock across its own read-compare-
# write, so a copy taken before delegating can be superseded before that lock
# is acquired. Their protection is the arbitration itself.
#
# A preserved skill is still a skill. Codex's loader deep-scans nested
# SKILL.md, so `agenticapps-workflow.pre-install.1` left where it stood would
# re-register the duplicate this run just removed — the run would delete one
# copy of the trigger skill and create another beside it. Backups taken from a
# skills directory therefore mirror out under ~/.agenticapps, which no host
# reads. Host configuration files stay backed up in place: their loaders match
# exact names, and an adjacent copy is the obvious restore.
preserve() {
  local p="$1" n=1 b="$1"
  case "$p" in "$HOME"/*skills/*) b="$HOME/.agenticapps/pre-install/${p#"$HOME"/}"; mkdir -p "${b%/*}" 2>/dev/null ;; esac
  while [ -e "$b.pre-install.$n" ]; do n=$((n + 1)); done
  b="$b.pre-install.$n"
  cp -Rp "$p" "$b" 2>/dev/null || return 1
  say "  preserved $p -> $b"
  # Quoted, because the restore command IS the recoverability guarantee. A home
  # directory with a space in it turned the advertised command into two wrong
  # ones, and an operator only finds that out at the moment they need it.
  say "  restore:  rm -rf \"$p\"; mv \"$b\" \"$p\""
}

is_archived() {
  local r
  for r in $ARCHIVED; do case "$1" in *"$r"*) return 0 ;; esac; done
  return 1
}

# $1 already-granted flag, $2 prompt, $3 what to report when it is not granted.
# There was a second opt-in here, granting "edit the JSON your editor reads".
# It went with the host wiring: a consent rule for an act that can no longer
# occur is dead text, and dead text is read as a live guarantee.
ask() {
  [ "$1" = 1 ] && return 0
  if [ -t 0 ]; then printf '%s [y/N] ' "$2"; read -r a && case "$a" in y | Y) return 0 ;; esac; fi
  skip "$3"
  return 1
}
consent() { ask "$REPLACE_UNRECOGNISED" "Replace $1 ($2)?" \
  "not replaced without acceptance: $1 ($2) — pass --replace-unrecognised"; }

# ── Bindings ───────────────────────────────────────────────────────────────
# Reached only after sweep_vendored, so an archived symlink cannot still be
# here: it was rebound or removed, and reported, before this ran. What remains
# is a target that is already correct, or one this workflow does not recognise.
bind_one() {
  local src="$1" dst="$2" tgt what
  if [ -L "$dst" ]; then
    tgt="$(readlink "$dst")"
    [ "$tgt" = "$src" ] && return 0
    consent "$dst" "symlink to $tgt" || return 1
    preserve "$dst" || { skip "could not preserve $dst"; return 1; }
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    what="regular file"; [ -d "$dst" ] && what="copied skill directory"
    consent "$dst" "$what" || return 1
    preserve "$dst" || { skip "could not preserve $dst"; return 1; }
    rm -rf "$dst"
  fi
  ln -s "$src" "$dst" 2>/dev/null || { skip "could not create symlink $dst"; return 1; }
}

apply_legacy() {
  local dir="$1" name
  for name in $LEGACY_DIRS; do
    [ -d "$dir/$name" ] && [ ! -L "$dir/$name" ] || continue
    preserve "$dir/$name" && rm -rf "${dir:?}/${name:?}" && say "  removed legacy skill $name (a copy, not a link)"
  done
}

# The archived host installers vendored host-prefixed copies of upstream skills
# — codex-cso, opencode-qa, codex-impeccable-audit — which is the vendoring the
# workflow now forbids. The mapping back is mechanical, so it is computed rather
# than tabulated: strip the host prefix, strip an `-audit` suffix, and look for a
# host-neutral skill of that name. `~/.agents/skills` is preferred because it is
# the shared store the other hosts already symlink into.
#
# A candidate has to BE a skill, not merely exist: an empty directory or a stray
# file named `cso` would otherwise satisfy the search and a vendored binding
# would be rebound to a non-skill. Carrying a `SKILL.md` is the test. Every
# target the real run chose already satisfied it, so this narrows the search
# without changing any decision it made.
neutral_of() {
  local n="${1#codex-}" d
  n="${n#opencode-}"; n="${n%-audit}"
  # A candidate that is ITSELF an archived binding is not an equivalent — one
  # host's dead link is no better a target than another's, and rebinding to it
  # would leave the machine looking converted while still resolving into a
  # checkout that is about to be deleted.
  for d in "$ROOT/skills" "$HOME/.agents/skills" "$HOME/.claude/skills"; do
    [ -e "$d/$n/SKILL.md" ] && [ "$d/$n" != "$2" ] && ! { [ -L "$d/$n" ] && is_archived "$(readlink "$d/$n")"; } && { printf '%s' "$d/$n"; return 0; }
  done
  return 1
}

# Sweep the archived bindings the named manifest does not cover. This is
# discovery ACTING, which the design first rejected on the grounds that
# discovery "cannot decide between replace and remove" — and that objection is
# answered here: the presence of a host-neutral equivalent is what decides.
# The manifest still owns every case needing judgement, including the ones that
# are not symlinks at all.
sweep_vendored() {
  local dir="$1" p name old n
  for p in "$dir"/*; do
    # SC2015's "C may run when A is true" is the intent here, not a bug: the
    # `continue` is meant to fire for any of the three failing — not a symlink,
    # unreadable, or not archived. All three mean the same thing: not ours.
    # shellcheck disable=SC2015
    [ -L "$p" ] && old="$(readlink "$p")" && is_archived "$old" || continue
    name="$(basename "$p")"
    if n="$(neutral_of "$name" "$p")"; then
      # The link is removed before the new one is created, so a failed `ln`
      # leaves the binding as nothing at all. Saying so is the whole point: a
      # run that destroyed a binding and reported success is the failure mode
      # this installer exists to avoid.
      if rm -f "$p" && ln -s "$n" "$p"; then say "  rebound $name (was $old) -> $n"
      else skip "could not rebind $name — it was $old and is now unbound"; fi
    else
      if rm -f "$p"; then say "  removed $name (was $old) — no host-neutral equivalent is installed"
      else skip "could not remove $name (was $old)"; fi
    fi
  done
}

bind_dir() {
  local dir="$1" readers="$2" s
  mkdir -p "$dir" 2>/dev/null
  say "  $dir (read by $readers)"
  apply_legacy "$dir"
  sweep_vendored "$dir"
  for s in "$ROOT"/skills/*; do
    [ -d "$s" ] || continue
    bind_one "$s" "$dir/$(basename "$s")"
  done
}

# The completeness check for the legacy manifest, and it must not consult it.
# Checking the manifest against itself proves nothing about the names it omits,
# which is the only failure mode that matters: a gap surfaces months later as a
# dangling skill when somebody deletes a checkout.
scan_archived() {
  local h dir p tgt found=0
  for h in $HOSTS; do
    dir="$HOME/$(field "$h" 2)"
    [ -d "$dir" ] || continue
    for p in "$dir"/*; do
      [ -L "$p" ] || continue
      tgt="$(readlink "$p")"
      is_archived "$tgt" && { say "  ARCHIVED BINDING $p -> $tgt"; found=1; }
    done
  done
  [ "$found" = 1 ] && skip "bindings into unmaintained checkouts survive — the legacy manifest has a gap"
  return 0
}

# ── Check ──────────────────────────────────────────────────────────────────
# Currency is judged by CONTENT against the checkout. A marker comparison
# reports a hand-edited artifact as current, which is the condition an operator
# runs this mode to find.
check_artifact() {
  local rel="$1" key="$2" name src dst pv cv
  name="$(basename "$rel")"; src="$ROOT/reference-implementations/$rel"; dst="$BIN/$name"
  [ -e "$dst" ] || { say "  $name absent"; return; }
  [ -r "$dst" ] || { say "  $name present but unreadable"; return; }
  pv="$(marker "$key" "$dst")"; cv="$(marker "$key" "$src")"
  [ -n "$pv" ] || { say "  $name present, no parseable marker — version unknown"; return; }
  if cmp -s "$dst" "$src"; then say "  $name $pv current"
  elif [ "$pv" = "$cv" ]; then say "  $name $pv MODIFIED — same version as checkout, different bytes, not current"
  elif newer "$pv" "$cv"; then say "  $name $pv ahead of checkout $cv"
  else say "  $name $pv not current — checkout has $cv"
  fi
}

do_check() {
  local h name dir
  say "artifacts in $BIN"
  for a in $ARTIFACTS; do check_artifact "${a%%:*}" "${a##*:}"; done
  say "hosts"
  for h in $HOSTS; do
    name="${h%%:*}"; dir="$HOME/$(field "$h" 2)"
    if [ -L "$dir/agentic-apps-workflow" ]; then
      say "  $name bound -> $(readlink "$dir/agentic-apps-workflow")"
    else
      say "  $name not bound ($dir absent or unbound)"
    fi
  done
}

# ── Install ────────────────────────────────────────────────────────────────
publish() {
  local a rel key name rc out
  mkdir -p "$BIN"
  for a in $ARTIFACTS; do
    rel="${a%%:*}"; key="${a##*:}"; name="$(basename "$rel")"
    "$SHARED" "$ROOT/reference-implementations/$rel" "$BIN/$name" "$key" >/dev/null 2>&1
    rc=$?
    case $rc in
      0) say "  published $name" ;;
      # Exit 3 is this helper's documented SUCCESS: the destination already
      # holds a strictly newer version, so "at least as new as the source"
      # holds either way. Calling it skipped would fail a correct machine.
      3) say "  satisfied $name — destination already newer" ;;
      *) skip "could not publish $name (exit $rc)" ;;
    esac
  done
  out="$("$PROJHOOKS" 2>&1)" || { say "$out"; skip "project hooks were not published and attested"; }
  [ -n "$out" ] && [ "$SKIPPED" = 0 ] && say "  published and attested the project-hook set"
  return 0
}

# Every host is treated identically: it gets skills. There is deliberately no
# per-host branch here — the moment one exists, the next one is cheap.
install_hosts() {
  local h name dir readers seen=""
  for h in $HOSTS; do
    name="${h%%:*}"; dir="$(field "$h" 2)"
    case " $REQUESTED " in *" $name "*) ;; *) continue ;; esac
    case " $seen " in *" $dir "*) continue ;; esac
    # One directory serves two hosts, so it is reported once, naming both.
    readers="$(printf '%s' "$HOSTS" | awk -F: -v d="$dir" '$2==d{printf "%s%s", sep, $1; sep=", "}')"
    seen="$seen $dir"
    bind_dir "$HOME/$dir" "$readers"
  done

  # The openspec CLI's own skills and commands, bound once per machine so no
  # repository has to carry them. ONE call naming every host: the per-host
  # shapes differ wildly — claude nests its commands, opencode flattens them,
  # codex has none and pi has no machine directory at all — and that knowledge
  # belongs in the binder, not in a per-host branch here. A binder failure is
  # reported and does not fail the install: it means openspec is missing or a
  # name collided, neither of which is the workflow failing to install.
  local hostargs="" n
  for n in $REQUESTED; do hostargs="$hostargs --host $n"; done
  # It reports itself; capturing its output here would only be this file
  # reprinting another file's words, and the budget is spent better elsewhere.
  # shellcheck disable=SC2086
  "$OPSXBIND" $hostargs || say "  opsx tooling: not fully bound"

  say "  no host configuration was written — the gate runs at git commit and in CI"
}

detect() {
  local h found=""
  for h in $HOSTS; do have "${h##*:}" && found="$found ${h%%:*}"; done
  printf '%s' "$found"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --check) MODE=check; shift ;;
    # `set -u` is on, so a bare trailing `--host` would abort on an unset $2
    # with a shell error instead of the usage error every other bad argument gets.
    --host) [ $# -ge 2 ] || { say "--host needs a host name"; usage; exit 64; }; REQUESTED="$REQUESTED $2"; shift 2 ;;
    --replace-unrecognised) REPLACE_UNRECOGNISED=1; shift ;;
    *) say "unknown argument: $1"; usage; exit 64 ;;
  esac
done

have git || { say "FAILED: git is required and was not found. Nothing was published."; exit 1; }
have bash || { say "FAILED: bash is required and was not found. Nothing was published."; exit 1; }

if [ "$MODE" = check ]; then do_check; exit 0; fi

case " $REQUESTED " in *" auto "*) REQUESTED="$(detect)"; say "detected hosts:${REQUESTED:- none}" ;; esac

say "publishing to $BIN"
publish
say "installing core's git pre-commit hook"
"$COREHOOKS" >/dev/null 2>&1 || skip "core's git pre-commit hook was not installed"

if [ -n "${REQUESTED// /}" ]; then
  say "binding hosts:$REQUESTED"
  install_hosts
else
  say "no host was requested, so no host was wired — the git and CI floor is installed"
fi

scan_archived
if [ "$SKIPPED" -gt 0 ]; then
  say "$SKIPPED step(s) were skipped. Re-run after resolving them."
  exit 1
fi
say "done."
