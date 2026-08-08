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
# THE MIGRATION SET IS NAMED, NEVER DISCOVERED.
#
#   bind-global-floor.sh [repository ...]
#
# Each argument is a repository to migrate off its own pre-commit and onto the
# floor. With no arguments nothing is migrated, which is how install.sh calls
# it: "acts only on repositories the operator names" is then true of the
# unattended path by construction rather than by a flag defaulting correctly.
#
# The floor governs only repositories that enrolled, and enrolling is an act
# performed inside the repository it applies to — so ENROLMENT IS ITSELF THE
# CONSENT and the binding owes no separate one for a repository that already
# enrolled. What is owed is the set this run will NEWLY enrol, which is the set
# it was handed. Nothing needs searching for. A walk would search the machine to
# rebuild a list already in a variable, and could not make any of the four
# judgements that reduced 61 measured repositories to three: archived vs live,
# husky vs our gate, deliberate adoption vs drive-by install, retired checkout
# vs current. Not one is a property of a file on disk.
#
# ENROL → SWEEP → VERIFY → REMOVE, and every step is load-bearing.
#
# Enrolment is inert while a local core.hooksPath still stands: the repository
# is gated by its own hook, which predates the enrolment predicate and never
# reads it. That is exactly what makes enrolling first free and sweeping first
# unsafe — sweeping an unenrolled repository hands it to the published
# dispatcher, whose first act is to exit 0 for want of the marker. The window
# between sweep and enrolment is one in which the repository has a hook file, a
# global binding and NO ENFORCEMENT, and an interruption inside it leaves that
# state permanently with nothing reporting it. Both plan reviewers found this
# independently in the draft that had sweep first.
#
# EVERY NAMED REPOSITORY IS ENROLLED BEFORE THE GLOBAL BINDING LANDS, not inside
# its own sequence. The sweep is only one of the two things that can displace a
# repository's own hook, and it is the smaller one: a repository with NO local
# core.hooksPath — which is what tools/install-core-git-hooks.sh leaves behind,
# since it writes into the directory git already resolves — stops consulting
# `.git/hooks/` the instant `core.hooksPath` is set globally. There is no sweep
# to order anything against. Enrolling inside the per-repository loop therefore
# reopened exactly the window the loop's order was chosen to close, one step
# earlier and for every named repository at once, and a cut in it leaves a
# repository with its hook file still on disk and nothing running it.
#
# This is the argument the core-repair step below already makes about core's own
# checkout — "setting the global binding IS the moment core's own hook stops
# being preferred" — applied to the repositories the operator named. Same
# displacement, same instant; it was only ever answered for one of them.
#
# Exit 0 = published and bound, or already so, and every named repository
#          migrated.
# Exit 1 = refused (a foreign binding, a declined preflight) or failed (publish,
#          bind, or any named repository). In every case the caller reports the
#          step as skipped, so the run exits non-zero rather than claiming a
#          floor the machine does not have.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SELF_DIR/pre-commit"
SHARED="$SELF_DIR/../shared-install/install-shared-artifact.sh"

# Pinned by the spec delta rather than chosen here, because `--check` must
# verify that core.hooksPath "resolves to the published directory" and that is
# unverifiable while the directory is named only in prose.
HOOKS_DIR="$HOME/.agenticapps/git-hooks"
MARKER_KEY='global-floor-version'

# The ownership claim tools/install-core-git-hooks.sh writes into every hook it
# installs. Matched as a WHOLE LINE: a file that merely mentions the marker in
# passing has not claimed it. This is the only thing standing between "the
# operator typed this path" and "this installer may delete the file at the end
# of it".
GATE_HOOK_MARKER='# managed-by: agenticapps-workflow-core tools/install-core-git-hooks.sh'

say() { printf 'global-floor: %s\n' "$*"; }

# Raw equality first, then physical paths. On macOS a home directory reached
# through a symlink spells the same directory two ways, and a binder that
# reported its own binding as foreign would refuse permanently. Defined up here
# rather than beside its first use because the migration's resolution step needs
# it before anything is published.
same_dir() {
  [ "$1" = "$2" ] && return 0
  local a b
  a="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
  b="$(cd "$2" 2>/dev/null && pwd -P)" || return 1
  [ -n "$a" ] && [ "$a" = "$b" ]
}

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

# ── Inventory, before anything is published or bound ───────────────────────
# THE ASYMMETRY: PUBLISH IS FILE-SCOPED, BIND IS DIRECTORY-SCOPED.
#
# One file is published and a whole directory is bound. Git runs whatever it
# finds there by name, so binding activates every entry — pre-push, commit-msg,
# any of them — machine-wide, in every repository the floor governs. The two
# guards above cannot close that. They establish that the directory is not a
# symlink and that no OTHER account can write it, which together prove who
# COULD have written a file and never that the operator meant it to run on
# every commit. An entry the operator dropped there themselves passes both.
#
# Measured 2026-08-08: this directory held one file, a 46-line pre-commit
# vendored from an archived host repository, unmarked, exporting
# OPENSPEC_GATE_SELF=opencode and describing a rule retired at gate 2.0.0. At
# `pre-commit` it self-heals, because publishing replaces it. Named `pre-push`
# it would have become the machine's commit-time gate, unchallenged.
#
# Consent is PER ENTRY and NAMES IT. "The directory contains unexpected files,
# proceed?" is the prompt everyone accepts, and it grants the same thing
# whether the entry is a stale copy of our own hook or a pre-push nobody
# remembers.
ACCEPT="${GLOBAL_FLOOR_ACCEPT:-}"

# `$ACCEPT` is unquoted so the list splits on whitespace — and unquoted
# expansion also does PATHNAME expansion, so globbing is disabled around it.
# Without `set -f`, GLOBAL_FLOOR_ACCEPT='*' expanded against the working
# directory the binder happened to be run from: reproduced, with a file named
# `pre-push` in that directory, `*` matched the entry and the machine bound.
# That is the blanket acceptance this requirement forbids, arriving through the
# shell rather than the design, and it accepts different entries depending on
# where the command was run.
accepted() {
  local a rc=1
  set -f
  for a in $ACCEPT; do [ "$a" = "$1" ] && { rc=0; break; }; done
  set +f
  return "$rc"
}

# Asked only when there is somebody to ask. install.sh runs this with stdin
# inherited, so an interactive install can decide in place; a scripted one
# reports what it would have asked and refuses, which is the same posture
# install.sh takes for every other acceptance it needs.
confirm() {
  [ -t 0 ] || return 1
  printf 'global-floor: run %s on every commit, in every repository the floor governs? [y/N] ' "$1"
  local a
  read -r a || return 1
  case "$a" in y | Y) return 0 ;; esac
  return 1
}

unaccepted=''
inventoried=0
pre_commit_detail=''
pre_commit_marked=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  name="${path##*/}"
  detail="$(wc -c < "$path" 2>/dev/null | tr -d ' ') bytes"
  [ -d "$path" ] && detail='directory'
  detail="$detail, $(date -r "$path" '+%Y-%m-%d' 2>/dev/null)"

  case "$name" in
    # Where the published dispatcher sends operator-owned hooks. Part of the
    # design, so flagging it would fire the refusal on every correctly composed
    # machine — which is how a guard comes to be switched off.
    hooks.d) continue ;;
    # THE VERDICT ON pre-commit IS DEFERRED TO THE PUBLISHER, and the security
    # pass is why. This used to exempt the entry whenever it carried a version
    # marker — but a marker is a comment, so its presence cannot establish that
    # this installer wrote the file. Reproduced: a pre-commit carrying
    # `# global-floor-version: 9.9.9` was newer than the checkout's, so
    # arbitration correctly declined to publish, the file survived, and the run
    # bound the directory it sits in while printing "holds nothing this
    # installer did not publish".
    #
    # The carve-out was justified by "publishing replaces it". Where the publish
    # does not replace it, the justification goes with it — so what settles the
    # question is the publisher's own exit status, below.
    pre-commit)
      pre_commit_detail="$detail"
      grep -q "^# $MARKER_KEY: " "$path" 2>/dev/null && pre_commit_marked=1
      continue ;;
  esac

  inventoried=1
  say "inventory: unrecognised entry — $name ($detail)"
  if accepted "$name" || confirm "$name"; then
    say "  accepted by name"
  else
    unaccepted="$unaccepted $name"
  fi
done <<INVENTORY
$(find "$HOOKS_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)
INVENTORY

if [ -n "$unaccepted" ]; then
  say "REFUSED —$unaccepted would be activated by binding this directory, and"
  say "this installer did not publish it. Every repository the floor governs would"
  say "run it. Nothing was published and core.hooksPath was NOT set."
  say "Accept it by name and re-run:"
  say "  GLOBAL_FLOOR_ACCEPT=\"$(printf '%s' "${unaccepted# }")\" $0"
  exit 1
fi

# ── The named set: resolved and classified before anything is done ─────────
# Everything here is READ-ONLY. It runs before the publish so that the report
# below can be the dry-run the operator accepts, and so that a name that cannot
# be resolved is rejected while there is still nothing to undo.
planned=0
refused=0

if [ $# -gt 0 ]; then
  PLAN="$(mktemp -d)" || { say "FAILED to create a working directory. Nothing was published."; exit 1; }
  trap 'rm -rf "$PLAN"' EXIT
  : > "$PLAN/report"
  : > "$PLAN/seen"

  for name in "$@"; do
    # A TYPED PATH IS NOT AN IDENTITY, and `rev-parse` inside a subdirectory
    # answers about the repository containing it. Without the equality test a
    # named subdirectory would migrate a repository nobody named — the same
    # arbitrary-repository write Decision 4 removed, arrived at by accident.
    top="$(git -C "$name" rev-parse --show-toplevel 2>/dev/null)"
    if [ -z "$top" ] || ! same_dir "$name" "$top"; then
      say "REFUSED — $name is not the top of a git repository."
      say "Nothing was published and core.hooksPath was NOT set. A set that cannot be"
      say "stated correctly cannot be accepted correctly either, so the whole run stops"
      say "rather than proceeding with the names that happened to parse."
      exit 1
    fi

    # `--git-common-dir`, never `--git-path hooks`: the latter HONORS
    # core.hooksPath, so the value under examination would confirm itself. It
    # also resolves a linked worktree to the main checkout, which is both the
    # directory git reads hooks from and the identity two checkouts share.
    common="$(git -C "$top" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
    if [ -z "$common" ]; then
      common="$(git -C "$top" rev-parse --git-common-dir 2>/dev/null)"
      case "$common" in '' | /*) ;; *) common="$top/$common" ;; esac
    fi
    if [ -z "$common" ]; then
      say "REFUSED — cannot resolve the git directory of $name. Nothing was published."
      exit 1
    fi

    key="$(cd "$common" 2>/dev/null && pwd -P)" || key="$common"
    [ -n "$key" ] || key="$common"
    if grep -qxF "$key" "$PLAN/seen" 2>/dev/null; then
      printf '  %s names a repository already in this set — it is processed once\n' "$name" >> "$PLAN/report"
      continue
    fi
    printf '%s\n' "$key" >> "$PLAN/seen"

    # NAMING A REPOSITORY IS NOT EVIDENCE ABOUT THE HOOK INSIDE IT. It is the
    # operator's belief about what is there. Recognition therefore comes from
    # the file, and the case that matters is the negative one: a repository
    # named by mistake keeps the hook its operator wrote. Same shape as the
    # inventory above, one level down — a file's location proves who COULD have
    # written it and never who did.
    hook="$common/hooks/pre-commit"
    # THE FILE THIS DELETES MUST BE THE ONE THE REPORT NAMED. A symlinked hooks
    # directory redirects the removal to a file somewhere else entirely, and
    # unlike a symlinked hook — refused below — it does so invisibly: the
    # preflight prints `<common>/hooks/pre-commit`, and the operator accepts a
    # path that is not where the delete lands. Refused for the reason the
    # published directory and hooks.d are both refused when symlinked, one
    # level further down.
    if [ -L "$common/hooks" ]; then
      printf '  REFUSE %s — %s/hooks is a symlink, so what is removed is not what\n' "$top" "$common" >> "$PLAN/report"
      printf '    this report can name. Nothing in it is touched.\n' >> "$PLAN/report"
      refused=$((refused + 1))
      continue
    fi
    if [ ! -f "$hook" ]; then
      printf '  REFUSE %s — there is no pre-commit at %s to migrate\n' "$top" "$hook" >> "$PLAN/report"
      refused=$((refused + 1))
      continue
    fi
    if [ -L "$hook" ] || ! grep -qxF "$GATE_HOOK_MARKER" "$hook" 2>/dev/null; then
      printf '  REFUSE %s — %s carries no ownership marker, so it is not this\n' "$top" "$hook" >> "$PLAN/report"
      printf '    workflow'"'"'s gate and will not be removed\n' >> "$PLAN/report"
      refused=$((refused + 1))
      continue
    fi

    # A local core.hooksPath that names the directory git would resolve anyway
    # grants no behaviour, so unsetting it changes nothing except restoring the
    # floor's reach. Anything else is a deliberate act. And a binding may be
    # REDUNDANT BY VALUE AND STILL LOAD-BEARING — core's own is exactly that —
    # so a declaration excludes it from the sweep without inspecting where it
    # points.
    lhp="$(git -C "$top" config --local --get --type=path core.hooksPath 2>/dev/null)"
    ldeclared="$(git -C "$top" config --local --get agenticapps.hooksbinding 2>/dev/null)"
    sweep=''
    if [ -n "$lhp" ] && [ "$ldeclared" = declared ]; then
      printf '  REFUSE %s — its local core.hooksPath is declared (%s), and a declared\n' "$top" "$lhp" >> "$PLAN/report"
      printf '    binding is excluded from the sweep whatever it points at\n' >> "$PLAN/report"
      refused=$((refused + 1))
      continue
    elif [ -n "$lhp" ] && ! same_dir "$lhp" "$common/hooks"; then
      printf '  REFUSE %s — its local core.hooksPath names %s, which git prefers over\n' "$top" "$lhp" >> "$PLAN/report"
      printf '    the floor. It is outside the floor by its own choice.\n' >> "$PLAN/report"
      refused=$((refused + 1))
      continue
    elif [ -n "$lhp" ]; then
      sweep="$lhp"
    fi

    if [ -n "$sweep" ]; then
      printf '  migrate %s — enrol, sweep %s, verify, then remove %s\n' "$top" "$sweep" "$hook" >> "$PLAN/report"
    else
      printf '  migrate %s — enrol, verify, then remove %s\n' "$top" "$hook" >> "$PLAN/report"
    fi

    # LINKED WORKTREES SHARE ONE COMMON DIRECTORY, so they share one local
    # configuration and one hooks directory. Naming any checkout acts on all of
    # them — which makes "a repository it was not given is left entirely alone"
    # false for a sibling nobody mentioned, unless the preflight says its name.
    git -C "$top" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' |
      while IFS= read -r wt; do
        [ -n "$wt" ] || continue
        same_dir "$wt" "$top" && continue
        printf '    this also affects the linked worktree at %s, which shares that configuration\n' "$wt" >> "$PLAN/report"
      done

    printf '%s\n%s\n%s\n%s\n' "$top" "$common" "$hook" "$sweep" > "$PLAN/repo.$planned"
    planned=$((planned + 1))
  done
fi

# ── One report, one acceptance ─────────────────────────────────────────────
# What will be published, what this run will newly enrol, and what will be done
# to each named repository, under a SINGLE acceptance. Three prompts asking
# about one act is how an operator learns to answer y without reading, which is
# the failure the per-entry inventory above exists to prevent — reintroducing it
# one level up would undo it.
#
# The guarantee below is scoped rather than absolute, deliberately. install.sh
# publishes its payload before it ever reaches this script, so "declining leaves
# the machine untouched" is a promise this file cannot keep. It names what it
# actually covers instead.
PLAN_ACCEPT="${GLOBAL_FLOOR_ACCEPT_PLAN:-}"

plan_accepted() {
  case "$PLAN_ACCEPT" in
    1 | y | Y | yes | true) return 0 ;;
    # Empty is "not answered" and falls through to the prompt. Any other value
    # IS an answer and it is not yes: GLOBAL_FLOOR_ACCEPT_PLAN=0 must not
    # accept. The enrolment predicate learned this one level down — a key whose
    # value is ignored is not an opt-in, it is a tripwire.
    '') ;;
    *) return 1 ;;
  esac
  [ -t 0 ] || return 1
  printf 'global-floor: proceed with all of the above? [y/N] '
  local a
  read -r a || return 1
  case "$a" in y | Y) return 0 ;; esac
  return 1
}

if [ $# -gt 0 ]; then
  say "preflight — nothing below has been done yet"
  if [ -n "$pre_commit_detail" ]; then
    say "  publish pre-commit -> $HOOKS_DIR, replacing what is there now ($pre_commit_detail)"
  else
    say "  publish pre-commit -> $HOOKS_DIR"
  fi
  say "  bind core.hooksPath -> $HOOKS_DIR"
  while IFS= read -r line; do say "$line"; done < "$PLAN/report"
  # THE MUTATION SET IS NOT THE IMPACT SET. A repository enrolled earlier by
  # init-project.sh becomes governed the moment the binding lands, without
  # appearing here and without being named. Claiming to enumerate what the
  # binding governs would require the search this design removed, and would be
  # false the first time somebody ran the initialiser.
  say "  note: repositories enrolled earlier are governed by this binding too. This"
  say "  run reports only what it will NEWLY enrol; --check is where they are listed."
  if ! plan_accepted; then
    say "DECLINED — nothing was published, core.hooksPath was NOT set, and no named"
    say "repository was enrolled, swept or stripped of its hook."
    exit 1
  fi
fi

# ── Publish ────────────────────────────────────────────────────────────────

"$SHARED" "$SRC" "$HOOKS_DIR/pre-commit" "$MARKER_KEY" >/dev/null 2>&1
rc=$?
case $rc in
  0) say "published pre-commit to $HOOKS_DIR"
     # It is ours now. Worth reporting only if it was not before: a hook
     # replaced in silence looks exactly like one that was never there, which
     # is how the vendored copy sat in this directory unnoticed.
     if [ -n "$pre_commit_detail" ] && [ "$pre_commit_marked" = 0 ]; then
       inventoried=1
       say "inventory: unrecognised entry — pre-commit ($pre_commit_detail), no $MARKER_KEY marker."
       say "  It has been replaced by the publish above, which is why it does not refuse."
     fi ;;
  # Exit 3 is the helper's documented SUCCESS: the destination already holds a
  # strictly newer version, so "at least as new as the source" holds either
  # way. Calling it a PUBLISH failure would refuse a machine that is more
  # current than this checkout — correct state, reported as broken.
  #
  # It is not a bind decision, though, and conflating the two is the hole the
  # security pass found. The publish succeeded and the file in place is still
  # not one this run wrote, so the entry goes back through the same consent the
  # inventory applies to every other entry it did not publish.
  3) say "satisfied pre-commit — destination already newer"
     # Gated on the inventory having actually SEEN a file. "Already newer" with
     # nothing there is contradictory state, and there is no entry to consent
     # to — asking about a file that is not present is a prompt nobody can
     # answer.
     if [ -n "$pre_commit_detail" ]; then
       inventoried=1
       say "inventory: unrecognised entry — pre-commit ($pre_commit_detail)"
       say "  Newer than this checkout's, so the publish left it in place: this run did"
       say "  not write the hook it is about to bind to every repository on the machine."
       if accepted pre-commit || confirm pre-commit; then
         say "  accepted by name"
       else
         say "REFUSED — binding this directory would run a pre-commit this run neither"
         say "published nor replaced, on every commit in every repository the floor"
         say "governs. core.hooksPath was NOT set and the file was not touched."
         say "Accept it by name and re-run:"
         say "  GLOBAL_FLOOR_ACCEPT=\"pre-commit\" $0"
         exit 1
       fi
     fi ;;
  *) say "FAILED to publish pre-commit to $HOOKS_DIR (exit $rc)."
     say "core.hooksPath was NOT set: a binding with no hook behind it commits silently."
     exit 1 ;;
esac

# Reported even when it finds nothing, because silence and "nobody looked" read
# identically — and nobody looking is the defect this closes. Printed after the
# publish rather than before it, because before the publish this claim can be
# false: the entry the arbitration declines to replace is exactly the one the
# claim would be covering up.
[ "$inventoried" = 0 ] && say "inventory: $HOOKS_DIR holds nothing this installer did not publish"

# ── Bind ───────────────────────────────────────────────────────────────────
# `--type=path` so git expands a `~` the operator wrote by hand; `--get`
# returns the raw string otherwise and the comparison below would miss.
current="$(git config --global --get --type=path core.hooksPath 2>/dev/null)"

# A foreign binding is settled before core is touched, and the order is load
# bearing. Refusing means the global binding is never set, so core's hook is
# never displaced, so there is no casualty to repair — and writing into a
# repository with nothing to repair is the category error Decision 4 removed.
#
# Reported, never overwritten. An operator who has bound a hooks directory did
# so deliberately, and a tool that silently rebinds it retakes a decision that
# was already made — machine-wide, at commit time. This is the posture the
# git-hook installer already takes toward a foreign hook, one level up.
if [ -n "$current" ] && ! same_dir "$current" "$HOOKS_DIR"; then
  say "REFUSED — core.hooksPath is already set to $current"
  say "This workflow would have set $HOOKS_DIR. The global configuration is unchanged."
  say "Composition belongs in $HOOKS_DIR/hooks.d, which the published hook runs."
  exit 1
fi

# ── Core's own binding, before the global one ──────────────────────────────
# Setting the global binding IS the moment core's own hook stops being
# preferred: with core.hooksPath set, `.git/hooks/` is not consulted at all.
# Four candidate owners for this repair were searched for and every one
# excludes it in its own text — install.sh by Decision 4, init-project.sh and
# fresh-clone-needs-nothing by "no hooks", core's CI by being a detector rather
# than an establisher. So the binder takes it: it is the only artifact that
# knows both facts at once, and it runs from inside core's checkout by
# construction. The displacement and the repair are one act, for the same
# reason publish and bind are one act.
CORE_ROOT="$(cd "$SELF_DIR/../.." && pwd)"

# The checkout must be the repository itself, not merely inside one. Without
# this, a binder unpacked below some unrelated repository would write a local
# binding into THAT repository — which is precisely the arbitrary-repository
# write Decision 4 removed, arrived at by accident instead of by design.
core_top="$(git -C "$CORE_ROOT" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$core_top" ] || ! same_dir "$core_top" "$CORE_ROOT"; then
  say "FAILED — core's local core.hooksPath cannot be established: $CORE_ROOT"
  say "is not the top of a git repository. This script runs from inside core's"
  say "checkout by construction, and binding the global path from anywhere else"
  say "would displace a hook it cannot repair. Nothing was bound."
  exit 1
fi

# `--git-common-dir`, never `--git-path hooks`: the latter HONORS core.hooksPath
# and would return whatever is already set, so a wrong binding would confirm
# itself. `--git-common-dir` also resolves a linked worktree to the main
# checkout, which is the directory git actually reads hooks from.
core_common="$(git -C "$CORE_ROOT" rev-parse --git-common-dir 2>/dev/null)"
case "$core_common" in
  '') say "FAILED to resolve core's git directory. Nothing was bound."; exit 1 ;;
  /*) ;;
  *)  core_common="$CORE_ROOT/$core_common" ;;
esac
CORE_HOOKS="$core_common/hooks"

core_local="$(git -C "$CORE_ROOT" config --local --get --type=path core.hooksPath 2>/dev/null)"
core_declared="$(git -C "$CORE_ROOT" config --local --get agenticapps.hooksbinding 2>/dev/null)"

declare_core() {
  git -C "$CORE_ROOT" config --local agenticapps.hooksbinding declared && return 0
  # The sweep unsets every local binding that names the default directory,
  # because five of the six on the machine measured were redundant. The
  # declaration is the only thing distinguishing core's deliberate one from
  # those, so a binding without it is a repair the next installer run undoes.
  say "FAILED to declare core's local core.hooksPath. The global binding was NOT set."
  return 1
}

if [ -n "$core_local" ] && ! same_dir "$core_local" "$CORE_HOOKS"; then
  # Same posture as the global refusal above, one level down. husky sets exactly
  # this, and retaking that decision at commit time is what this change refuses
  # to do — including by leaving a declaration that would tell the sweep to
  # protect somebody else's hooks directory.
  say "REFUSED — core's local core.hooksPath is already set to $core_local"
  say "This workflow would have set $CORE_HOOKS. Core's configuration is unchanged"
  say "and the global binding was NOT set: it would displace a hook this run"
  say "cannot account for."
  exit 1
elif [ -n "$core_local" ] && [ "$core_declared" = declared ]; then
  say "satisfied — core's local core.hooksPath already declares $CORE_HOOKS"
elif [ -n "$core_local" ]; then
  # The right directory with no declaration is the interrupted repair, not an
  # operator decision. Completing it takes nothing back.
  declare_core || exit 1
  say "declared core's local core.hooksPath -> $CORE_HOOKS"
else
  git -C "$CORE_ROOT" config --local core.hooksPath "$CORE_HOOKS" || {
    say "FAILED to set core's local core.hooksPath. The global binding was NOT set:"
    say "it would leave core gated by a floor dispatcher that exits 0 in silence"
    say "for a repository the floor does not govern."
    exit 1; }
  declare_core || exit 1
  say "bound core's local core.hooksPath -> $CORE_HOOKS"
fi

# ── Enrolment, before the binding that displaces their hooks ───────────────
# Last thing before the global binding and after every refusal above, so the two
# properties hold together: a run that refuses — a foreign global binding, a
# foreign local one in core — has still written nothing into a named repository,
# and a run that proceeds has enrolled every one of them before the instant
# their own hooks stop being consulted.
#
# Inert here in the strongest sense: with no global binding yet, the predicate
# this writes has no reader at all. If the binding below then fails, the
# repositories are enrolled, still gated by their own hooks, and re-running is
# the whole of the repair.
#
# A repository that cannot be enrolled is dropped from the migration rather than
# stopping it. Its hook is untouched and still gates it, which is the same
# posture every later step takes toward the repository it fails on.
failed=0
i=0
while [ "$i" -lt "$planned" ]; do
  { read -r e_top; } < "$PLAN/repo.$i"
  if git -C "$e_top" config --local agenticapps.workflow.enrolled true 2>/dev/null; then
    say "$e_top: enrolled"
  else
    say "$e_top: FAILED to enrol — its hook is left in place and still gates it"
    : > "$PLAN/skip.$i"
    failed=$((failed + 1))
  fi
  i=$((i + 1))
done

# ── The global binding ─────────────────────────────────────────────────────
if [ -z "$current" ]; then
  git config --global core.hooksPath "$HOOKS_DIR" || {
    say "FAILED to set core.hooksPath. The hook is published but the machine is UNBOUND."
    exit 1; }
  say "bound core.hooksPath -> $HOOKS_DIR"
else
  say "satisfied — core.hooksPath already resolves to $HOOKS_DIR"
fi

# ── The migration: sweep → verify → remove, one repository at a time ───────
# After the binding, because the verification step asks whether the floor
# governs the repository and there is no floor to be governed by until then.
# The enrolment is the one step that cannot wait for it, and it already ran.
#
# One repository is carried to completion before the next begins, which is what
# makes the interrupted-partway state describable: everything before the cut is
# migrated, everything after it still carries its own hook and is enrolled
# behind it, and the repository the cut landed inside is gated at every instant
# — by the floor it is already enrolled in, whether or not its own hook has
# been reached yet.
i=0
while [ "$i" -lt "$planned" ]; do
  { read -r m_top; read -r m_common; read -r m_hook; read -r m_sweep; } < "$PLAN/repo.$i"
  # Already counted where it failed, above. Skipped rather than retried: the
  # repository is unenrolled, so sweeping it would hand it to a dispatcher that
  # exits 0 for want of the marker.
  if [ -f "$PLAN/skip.$i" ]; then
    i=$((i + 1))
    continue
  fi
  i=$((i + 1))

  if [ -n "$m_sweep" ]; then
    # Re-read rather than trust the preflight. The value classified as redundant
    # minutes ago is the value about to be deleted, and nothing has held a lock
    # on that repository in between.
    now="$(git -C "$m_top" config --local --get --type=path core.hooksPath 2>/dev/null)"
    if [ "$now" != "$m_sweep" ]; then
      say "$m_top: NOT MIGRATED — its local core.hooksPath is now '${now:-unset}', not the"
      say "  '$m_sweep' the preflight classified. Its hook is left in place."
      failed=$((failed + 1))
      continue
    fi
    if ! git -C "$m_top" config --local --unset core.hooksPath 2>/dev/null; then
      say "$m_top: FAILED to sweep its local core.hooksPath — its hook is left in place"
      failed=$((failed + 1))
      continue
    fi
    say "$m_top: swept local core.hooksPath (was $m_sweep)"
  fi

  # THE VERIFICATION RESOLVES THE REPOSITORY'S HOOKS DIRECTORY rather than
  # reading the global configuration back. "The binding is live" is a fact about
  # the machine; "the binding governs this repository" is a fact about the
  # repository, and a local binding anywhere in the stack makes them different
  # facts. Here `--git-path hooks` is the right call precisely because it HONORS
  # core.hooksPath: the question is what git will actually do.
  resolved="$(git -C "$m_top" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)"
  if [ -z "$resolved" ] || ! same_dir "$resolved" "$HOOKS_DIR"; then
    if [ -n "$m_sweep" ]; then
      if git -C "$m_top" config --local core.hooksPath "$m_sweep" 2>/dev/null; then
        say "$m_top: restored local core.hooksPath -> $m_sweep"
      else
        say "$m_top: FAILED to restore local core.hooksPath '$m_sweep' — it is now unset"
        say "  and its own hook is no longer consulted. Restore it by hand."
      fi
    fi
    say "$m_top: NOT MIGRATED — its hooks resolve to '${resolved:-nothing}', not to the"
    say "  floor at $HOOKS_DIR. Its hook is left in place."
    failed=$((failed + 1))
    continue
  fi
  say "$m_top: verified — the floor governs it"

  # Recognised once at the preflight and again here, immediately before the
  # delete. The gap between them is a whole publish and bind, and the operator
  # accepted the removal of a file that was this workflow's gate at the time
  # they read the report.
  if [ ! -f "$m_hook" ] || [ -L "$m_hook" ] || ! grep -qxF "$GATE_HOOK_MARKER" "$m_hook" 2>/dev/null; then
    say "$m_top: NOT MIGRATED — $m_hook is no longer recognisable as this workflow's"
    say "  gate, so it is left alone. The repository is enrolled and the floor governs it."
    failed=$((failed + 1))
    continue
  fi
  if ! rm -f "$m_hook"; then
    say "$m_top: FAILED to remove $m_hook — the repository is now gated twice"
    failed=$((failed + 1))
    continue
  fi
  say "$m_top: removed $m_hook"
  say "$m_top: MIGRATED"
done

# A partial migration is never reported as a complete one. The machine keeps its
# binding either way: the failure is local to a repository, and refusing to bind
# a machine because one named path was wrong would be the larger act taken for
# the smaller reason.
if [ "$((failed + refused))" -gt 0 ]; then
  say "migration incomplete — $((failed + refused)) named repositories were not migrated,"
  say "each keeping the hook it already had. The machine is bound."
  exit 1
fi
