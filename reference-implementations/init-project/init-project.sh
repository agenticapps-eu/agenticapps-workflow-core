#!/usr/bin/env bash
# init-project.sh — establish what a repository carries to use this workflow.
#
# init-project-version: 1.0.0
#
#   cd <your repo> && ~/.agenticapps/bin/init-project.sh
#
# It writes exactly two things: `openspec/`, and one instruction file —
# `AGENTS.md` real, `CLAUDE.md` a symlink to it. No skills, no hooks, no host
# configuration, no CI workflow, no network. Those are the machine's business
# and `install.sh` establishes them.
#
# WHY IT IS THIS SHORT
#
# It runs inside a repository you already own, against files you already wrote,
# which is a higher-trust surface than a machine installer. You should be able
# to read the whole thing before trusting it, so there is nothing here but the
# checks and the two writes.
#
# It REFUSES rather than repairs. Every starting state that could collapse two
# instruction files into one — or pick which of two rules survives — stops the
# run instead. Every check happens before the first write, so a refusal never
# leaves half a repository behind.

set -uo pipefail

BEGIN_MARKER='<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->'
END_MARKER='<!-- END: agentic-apps-workflow sections -->'

die() { printf 'init-project: %s\n' "$1" >&2; exit 1; }
say() { printf '%s\n' "$1"; }

# --- Preflight: everything that can refuse, before anything that writes -------

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
  || die "not a git repository — nothing to initialize"
cd "$ROOT" || die "cannot enter $ROOT"

command -v openspec >/dev/null 2>&1 \
  || die "openspec is not installed, and it creates openspec/. Install it and re-run."

[ -d AGENTS.md ] && die "AGENTS.md is a directory"
[ -d CLAUDE.md ] && die "CLAUDE.md is a directory"

if [ -L CLAUDE.md ]; then
  [ -e CLAUDE.md ] || die "CLAUDE.md is a symlink with no target ($(readlink CLAUDE.md))"
  [ "$(readlink CLAUDE.md)" = "AGENTS.md" ] \
    || die "CLAUDE.md already links to $(readlink CLAUDE.md) — refusing to rewrite it"
fi

# Both names as separate regular files. Identical content has no rule to choose
# between, so it collapses; differing content is a decision about which rule
# survives, and that is not this script's to make.
COLLAPSE=no
if [ -f AGENTS.md ] && [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
  cmp -s AGENTS.md CLAUDE.md \
    || die "AGENTS.md and CLAUDE.md differ. Reconcile them by hand — collapsing them
            would decide which rule survives, and that is yours to decide."
  COLLAPSE=yes
fi

# --- Write ------------------------------------------------------------------

if [ -d openspec ]; then
  say "openspec/    already present"
else
  # `--tools none` is required, not incidental. The CLI refuses without a
  # --tools flag, and every other value writes per-host command and skill files
  # into the repository — `--tools claude` alone writes six commands and six
  # skills under .claude/. This script establishes two artifacts and no host
  # configuration, so the only consistent value is none.
  openspec init --tools none >/dev/null || die "openspec init failed"
  say "openspec/    created"
fi

# One instruction file under two names. The only case that needs care is a
# repository with CLAUDE.md alone: appending to it and creating AGENTS.md beside
# it is the obvious move, and it produces the two divergent files this whole
# arrangement exists to prevent.
DISCLOSE=no
if [ ! -e AGENTS.md ] && [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
  mv CLAUDE.md AGENTS.md || die "could not move CLAUDE.md to AGENTS.md"
  DISCLOSE=yes
  say "AGENTS.md    adopted from CLAUDE.md"
elif [ -e AGENTS.md ]; then
  say "AGENTS.md    already present"
else
  : > AGENTS.md || die "could not create AGENTS.md"
  say "AGENTS.md    created"
fi

if grep -qF "$BEGIN_MARKER" AGENTS.md 2>/dev/null; then
  say "workflow     section already present"
else
  # A pointer, never a copy. Behaviour lives in the skill, which is one file
  # reaching every host; a copy here would be a version of it, and versions in
  # repositories are the drift this workflow removes.
  {
    [ -s AGENTS.md ] && printf '\n'
    printf '%s\n' "$BEGIN_MARKER"
    printf '\n## The AgenticApps workflow\n\n'
    printf 'Work moves through the OpenSpec lifecycle, and how to do that lives in the\n'
    printf '`agentic-apps-workflow` skill on this machine — not in this file. Read the\n'
    printf 'skill for the loop, the gates and the coding discipline.\n\n'
    printf 'This repository carries two workflow artifacts: `openspec/`, which is its\n'
    printf 'durable truth, and this instruction file. Everything else — skills, hooks,\n'
    printf 'enforcement — is machine-level and comes from `install.sh`.\n\n'
    printf '%s\n' "$END_MARKER"
  } >> AGENTS.md || die "could not append the workflow section"
  say "workflow     section appended"
fi

if [ -L CLAUDE.md ]; then
  say "CLAUDE.md    already links to AGENTS.md"
else
  [ "$COLLAPSE" = yes ] && { rm -f CLAUDE.md || die "could not replace CLAUDE.md"; }
  ln -s AGENTS.md CLAUDE.md || die "could not link CLAUDE.md to AGENTS.md"
  say "CLAUDE.md    -> AGENTS.md"
fi

if [ "$DISCLOSE" = yes ]; then
  say ""
  say "NOTE: your CLAUDE.md is now AGENTS.md. Content that only Claude read is"
  say "      read by every host that reads AGENTS.md — codex, opencode, pi, omp."
fi
