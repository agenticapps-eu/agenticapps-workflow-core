#!/usr/bin/env bash
# bind-openspec-tools.sh — bind the openspec CLI's skills and commands into a
# host's MACHINE-level directories, so no repository has to carry them.
#
# bind-openspec-tools-version: 1.0.0
#
#   bind-openspec-tools.sh --host claude --host opencode
#     [--store DIR]   where generated files persist (default ~/.agenticapps/openspec-tools)
#     [--home DIR]    the home to bind into (default $HOME)
#
# WHY THIS EXISTS
#
# `openspec init --tools <host>` is a per-project agent installer: it writes six
# skills, and for most hosts a set of commands, into whatever repository it is
# run in. That is behaviour in a repository, which means a *version* of
# behaviour per repository, which is the drift this workflow exists to remove.
# Generating once per machine and binding gives every repository the same
# commands — including repositories nobody ever initialized.
#
# THE SHAPES ARE NOT UNIFORM, AND THAT IS THE WHOLE DIFFICULTY
#
# Skills are: six directories at <host>/skills/openspec-*/. Commands are not.
# Measured 2026-08-07 (MEASUREMENT-opsx.md in the change):
#
#   claude    .claude/commands/opsx/*.md     nested   -> ~/.claude/commands/opsx
#   opencode  .opencode/commands/opsx-*.md   flat     -> ~/.config/opencode/commands/
#   codex     none generated at all                   -> nothing to bind
#   pi        .pi/prompts/opsx-*.md (in-repo only)    -> no machine directory exists
#   omp       nothing established                     -> unverified
#
# A binder that applied one pattern to five hosts would be wrong on three of
# them, and wrong silently, because a symlink into a directory a host does not
# read succeeds and then resolves nothing. That is the defect that left pi bound
# to ~/.agents/skills for as long as the mapping existed.
#
# The store is persistent on purpose: the links point into it, so generating
# into a temp directory would leave every link dangling the moment it was
# cleaned up.

set -uo pipefail

STORE="${HOME}/.agenticapps/openspec-tools"
BIND_HOME="$HOME"
HOSTS=""
rc=0

# `set -u` is on, so an arm that shifts 2 without checking $# aborts on an unset
# $2 with a shell error naming THIS file's line number instead of the operator's
# mistake. install.sh:328 fixes the same defect on the same flag and carries a
# regression test for it; this is that fix, on the script install.sh calls.
need() { [ "$1" -ge 2 ] || { printf 'bind-openspec-tools: %s needs %s\n' "$2" "$3" >&2; exit 2; }; }

while [ $# -gt 0 ]; do
  case "$1" in
    --host)  need $# --host  "a host name";  HOSTS="$HOSTS $2"; shift 2 ;;
    --store) need $# --store "a directory";  STORE="$2";        shift 2 ;;
    --home)  need $# --home  "a directory";  BIND_HOME="$2";    shift 2 ;;
    *) printf 'bind-openspec-tools: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -n "$HOSTS" ] || { printf 'bind-openspec-tools: no --host given\n' >&2; exit 2; }

command -v openspec >/dev/null 2>&1 || {
  printf 'bind-openspec-tools: openspec is not installed, and it generates what this binds\n' >&2
  exit 1
}

note() { printf '  %s\n' "$1"; }

# link <src> <dst> — symlink, never copy. An existing link of ours is left as
# is; anything else under our name belongs to somebody and is reported.
#
# THE RETURN VALUE IS THE CALLER'S COUNTER. Every path below used to return 0,
# including the two that bind nothing, so `link … && n=$((n + 1))` scored a
# refusal as a success: three colliding destinations reported `skills: 3 bound`
# having created no symlink at all. A binder that reports binding what it
# declined to bind is worse than one that fails, because nothing invites the
# operator to look. Only a link that now exists returns 0.
link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    # Already ours, and already pointing where it should. Bound is bound.
    [ "$(readlink "$dst")" = "$src" ] && return 0
    note "collision: $dst already links elsewhere — left alone"
    rc=1
    return 1
  fi
  if [ -e "$dst" ]; then
    note "collision: $dst exists and is not ours — left alone"
    rc=1
    return 1
  fi
  mkdir -p "$(dirname "$dst")" && ln -s "$src" "$dst" && return 0
  # A destination that cannot be written is a different failure from one that
  # collided — an unwritable skills directory, a full disk — and it was silent.
  note "could not link $dst"
  rc=1
  return 1
}

# generate <host> <tool> — into $STORE/<host>, once. The tool name is not always
# the host name: omp is `oh-my-pi` to the CLI. openspec needs no git repository.
generate() {
  local dir="$STORE/$1" tool="$2"
  [ -d "$dir" ] && return 0
  mkdir -p "$dir" || return 1
  ( cd "$dir" && openspec init --tools "$tool" >/dev/null 2>&1 ) || return 1
}

for host in $HOSTS; do
  tool="$host"
  # host : where the CLI writes : machine skill dir : machine command dir : command style
  case "$host" in
    claude)   src=.claude;          skills=.claude/skills;           cmds=.claude/commands;           style=nested ;;
    codex)    src=.codex;           skills=.codex/skills;            cmds="";                         style=none ;;
    opencode) src=.opencode;        skills=.config/opencode/skills;  cmds=.config/opencode/commands;  style=flat ;;
    pi)       src=.pi;              skills=.pi/agent/skills;         cmds="";                         style=unverified ;;
    # omp is @oh-my-pi/pi-coding-agent, and its own dist names both directories:
    # "NEVER edit user-authored skills under ~/.omp/agent/skills", and "Load
    # commands from .agent/commands and .agents/commands (project walk-up + user
    # home)". It also reads ~/.claude/commands and ~/.config/opencode/commands,
    # so it would inherit opsx from a neighbour — it gets its own regardless, or
    # omp works only on machines where some other host was also requested.
    omp)      src=.omp; tool=oh-my-pi; skills=.omp/agent/skills;      cmds=.agents/commands;           style=flat ;;
    *) note "$host: unknown host, skipped"; rc=1; continue ;;
  esac

  printf '%s\n' "$host"

  # There was a `[ -z "$skills" ]` branch here, reporting "no established
  # directory, nothing bound". Every one of the five arms above sets a non-empty
  # `skills`, and an unknown host has already `continue`d — so it could not run,
  # and its comment described a state omp is not in. Dead text is read as a live
  # guarantee, which is why install.sh:108 deletes its own dead consent rule
  # rather than leaving it to be reassuring. The unverified case that IS real is
  # the command directory, and `style=unverified` still carries it below.

  generate "$host" "$tool" || { note "generation failed"; rc=1; continue; }

  n=0
  for s in "$STORE/$host/$src"/skills/openspec-*; do
    [ -d "$s" ] || continue
    link "$s" "$BIND_HOME/$skills/$(basename "$s")" && n=$((n + 1))
  done
  note "skills: $n bound into ~/$skills"

  case "$style" in
    nested)
      # One link for the whole directory: claude reads commands/opsx/*.md.
      if [ -d "$STORE/$host/$src/commands/opsx" ]; then
        link "$STORE/$host/$src/commands/opsx" "$BIND_HOME/$cmds/opsx"
        note "commands: opsx/ bound into ~/$cmds"
      else
        note "commands: none generated"
      fi ;;
    flat)
      c=0
      for f in "$STORE/$host/$src"/commands/opsx-*.md; do
        [ -f "$f" ] || continue
        link "$f" "$BIND_HOME/$cmds/$(basename "$f")" && c=$((c + 1))
      done
      note "commands: $c bound into ~/$cmds" ;;
    none)
      # ~/.codex/prompts is real and other tools populate it. The CLI simply
      # emits no codex commands, so the gap is the generator's, not the host's.
      note "commands: none generated for codex — nothing to bind, not a failure" ;;
    unverified)
      note "commands: unverified — no machine-level directory established for $host" ;;
  esac
done

exit $rc
