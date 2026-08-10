#!/usr/bin/env bash
# init-project.sh — establish what a repository carries to use this workflow.
#
# init-project-version: 1.2.0
#
#   1.2.0 — refuses a symlinked AGENTS.md, stops `cmp` comparing a path to
#           itself, and reads both names before reporting success. Without all
#           three it turned a repository's instruction file into a symlink cycle
#           that no check on either side could see. Two repositories, 2026-08-10.
#
#   cd <your repo> && ~/.agenticapps/bin/init-project.sh
#
# It writes exactly three things: `openspec/`, one instruction file — `AGENTS.md`
# real, `CLAUDE.md` a symlink to it — and one local git config key enrolling the
# repository in the machine's enforcement floor. No skills, no hooks, no host
# configuration, no CI workflow, no network. Those are the machine's business
# and `install.sh` establishes them.
#
# THE THIRD WRITE IS NOT A FILE, AND LEAVING IT OUT MADE THE OTHER TWO INERT.
# The published pre-commit runs in every repository on a bound machine and exits
# 0 unless `agenticapps.workflow.enrolled` is set locally, so a repository with
# `openspec/` and an instruction file and no key is ungated while being
# indistinguishable, from every file on disk, from one that is gated. Measured
# 2026-08-08: five repositories carried live OpenSpec changes and not one was
# enrolled, because the only thing that had ever written the key was somebody
# remembering to run a git command.
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

# AGENTS.md AS A SYMLINK IS THE ARRANGEMENT THAT CLOSES A CYCLE, and until this
# check existed nothing looked for it. The write below makes CLAUDE.md a link to
# AGENTS.md; if AGENTS.md is already a link back, both names end at mode 120000
# pointing at each other, every read returns ELOOP, and the content is gone.
#
# Measured 2026-08-10: two repositories in this fleet, byte-identical link blobs
# in both, undetected for about 36 hours. Nothing noticed because an unreadable
# instruction file is indistinguishable from an absent one.
#
# Refused rather than repaired, like every other hostile state here: which name
# should hold the content is the operator's call, not this script's.
if [ -L AGENTS.md ]; then
  die "AGENTS.md is a symlink to $(readlink AGENTS.md). This script makes CLAUDE.md
            the link, and creating it while AGENTS.md is one would point the two names at
            each other and destroy the file. Put the real instruction file at AGENTS.md —
            or move the content there and remove the link — then re-run."
fi

# Both names as separate regular files. Identical content has no rule to choose
# between, so it collapses; differing content is a decision about which rule
# survives, and that is not this script's to make.
#
# There is no COLLAPSE flag any more. It existed only to authorise an `rm -f
# CLAUDE.md` before the link was made, and the write below replaces the file in
# one step instead — so the refusal is all this block was ever for.
#
# BOTH NAMES ARE TESTED FOR BEING LINKS, not just CLAUDE.md. `-f` and `cmp` each
# dereference, so when one name is a link to the other this block compared a
# file to ITSELF, found it trivially identical, and waved through the very
# arrangement it exists to refuse. A comparison that can pass by aliasing is not
# evidence that two independent files agree.
if [ -f AGENTS.md ] && [ ! -L AGENTS.md ] && [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
  cmp -s AGENTS.md CLAUDE.md \
    || die "AGENTS.md and CLAUDE.md differ. Reconcile them by hand — collapsing them
            would decide which rule survives, and that is yours to decide."
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
  # BUILT BESIDE THE DESTINATION, THEN MOVED OVER IT. This was `rm -f
  # CLAUDE.md` followed by `ln -s`, and a failing link left the repository with
  # neither file while the message named only the link it could not create.
  # `mv -f` replaces a regular file in one step, so CLAUDE.md is never absent.
  #
  # THIS COMMENT USED TO SAY NO CONTENT WAS AT RISK, because "`cmp -s` above has
  # already proved the two byte-identical, so it all survives in AGENTS.md".
  # That invariant did not hold and the claim licensed the `mv -f` that
  # destroyed two repositories: when AGENTS.md was a link back to CLAUDE.md,
  # `cmp` had compared CLAUDE.md to itself and proved nothing, and AGENTS.md was
  # not a second copy of anything. What makes the write safe now is the
  # preflight refusal of a symlinked AGENTS.md, not this comparison.
  tmp=".CLAUDE.md.init-project.$$"
  ln -s AGENTS.md "$tmp" || die "could not create the CLAUDE.md link — CLAUDE.md is untouched"
  mv -f "$tmp" CLAUDE.md || { rm -f "$tmp"; die "could not move the link into place — CLAUDE.md is untouched"; }
  say "CLAUDE.md    -> AGENTS.md"
fi

# VERIFIED BY READING, NEVER BY STAT. `-L` reports true for BOTH halves of a
# symlink cycle and `readlink` reports a plausible target for each, so every
# structural check this script and its suite made was satisfied by two
# repositories whose instruction file could not be read at all. Only a read
# tells a working link from a loop.
a_content=$(cat AGENTS.md 2>/dev/null) \
  || die "AGENTS.md cannot be read after the run — refusing to report success"
c_content=$(cat CLAUDE.md 2>/dev/null) \
  || die "CLAUDE.md cannot be read after the run — refusing to report success"
[ -n "$a_content" ] \
  || die "the instruction file is empty after the run — refusing to report success"
[ "$a_content" = "$c_content" ] \
  || die "AGENTS.md and CLAUDE.md do not return the same content after the run"

# ENROLMENT — the write that makes the two above mean anything.
#
# `--local`, never `--global`: the dispatcher's own header records a run where a
# global key of this name enrolled every repository on the machine, and an
# initializer that reached for global would be that defect with a tool behind it.
#
# Written unconditionally rather than only when absent. `git config` is idempotent
# for a value that is already set, and the case worth handling is the opposite
# one — a repository whose key says `false`, which reads as configured and gates
# nothing, because the dispatcher resolves it with `--type=bool`.
if git config --local agenticapps.workflow.enrolled true 2>/dev/null; then
  say "enrolled     this repository in the machine's enforcement floor"
else
  # Not fatal. The two artifacts are written and correct, and a repository that
  # cannot be enrolled is one the floor does not gate — which is worth saying
  # loudly and is not worth discarding the rest of the run over.
  say ""
  say "WARNING: could not write agenticapps.workflow.enrolled to this repository's"
  say "         git config. openspec/ and the instruction file are in place, but the"
  say "         machine's pre-commit floor will NOT gate this repository until it is"
  say "         set: git config --local agenticapps.workflow.enrolled true"
fi

if [ "$DISCLOSE" = yes ]; then
  say ""
  say "NOTE: your CLAUDE.md is now AGENTS.md. Content that only Claude read is"
  say "      read by every host that reads AGENTS.md — codex, opencode, pi, omp."
fi
