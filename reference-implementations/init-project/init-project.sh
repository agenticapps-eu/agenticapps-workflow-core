#!/usr/bin/env bash
# init-project.sh — establish what a repository carries to use this workflow.
#
# init-project-version: 2.0.0
#
#   2.0.0 — TWO REAL FILES. `CLAUDE.md` is no longer a symlink to `AGENTS.md`;
#           both names are regular files holding identical content, and the
#           equality the link gave by construction is now a gate check
#           (`openspec-change-gate.sh --pre-commit`, gate 2.1.0). MAJOR: the
#           arrangement this script produces has changed, and a repository
#           carrying the 1.x arrangement is REFUSED rather than migrated.
#           * the reason is blast radius, not portability. A mechanism
#             delivering an eight-line pointer owned the whole file: 5% of
#             cparx's instruction file, 0% of callbot's. On 2026-08-10 that
#             disproportion turned a guard defect into 22,292 bytes of lost
#             content across two repositories
#           * it no longer MOVES, REPLACES, LINKS or DELETES anything. The only
#             write to an existing file is between the markers, in place, so
#             the file keeps its path, its inode and its mode
#           * the block is INSERTED OR UPDATED. 1.x skipped the file entirely
#             once a marker was present, so a repository could carry a section
#             from any past version for ever
#           * a CLAUDE.md-only repository keeps CLAUDE.md where it is. 1.x
#             moved it to AGENTS.md, which relocated a file nobody asked to
#             have relocated. The readership still widens, and that is still
#             disclosed
#           * NEITHER NAME MAY BE A SYMLINK, in either direction, and the
#             refusal names which one and the migration step
#   1.2.0 — refuses a symlinked AGENTS.md, stops `cmp` comparing a path to
#           itself, and reads both names before reporting success. Without all
#           three it turned a repository's instruction file into a symlink cycle
#           that no check on either side could see. Two repositories, 2026-08-10.
#
#   cd <your repo> && ~/.agenticapps/bin/init-project.sh
#
# It writes exactly three things: `openspec/`, one instruction file under two
# names — `AGENTS.md` and `CLAUDE.md`, both regular, byte-identical — and one
# local git config key enrolling the repository in the machine's enforcement
# floor. No skills, no hooks, no host configuration, no CI workflow, no network.
# Those are the machine's business and `install.sh` establishes them.
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

# A SYMLINK UNDER EITHER NAME IS REFUSED, and this is the check that changed in
# 2.0.0. Until now the script CREATED one of these links, so it could only
# refuse the shapes it did not create; now neither name may be a link, in either
# direction, and a repository carrying the 1.x arrangement stops here.
#
# Refused rather than migrated in place. Replacing a link with a copy of the
# content is a one-time, per-repository act that belongs in a reviewable commit,
# not in a scaffolder run an operator may not be watching — and which name
# should hold the content is theirs to decide, not this script's.
#
# The link is never FOLLOWED, either, because its target may lie outside the
# worktree: `-f` and `cmp` both dereference, which is how a link from one name
# to the other once compared a file to itself and proved nothing.
for name in AGENTS.md CLAUDE.md; do
  [ -L "$name" ] || continue
  target=$(readlink "$name")
  other=$([ "$name" = AGENTS.md ] && printf 'CLAUDE.md' || printf 'AGENTS.md')
  case "$target" in
    AGENTS.md|CLAUDE.md)
      die "$name is a symlink to $target — the arrangement this workflow used before 2.0.0.
            Both names must now be regular files with identical content. Migrate with a
            reviewable commit: copy $other over the link ($name), so that the two are two
            real files, then re-run." ;;
    *)
      die "$name is a symlink to $target. This script writes only regular files and will
            not write through a link, whose target may be outside this repository. Replace
            $name with a regular file, then re-run." ;;
  esac
done

# NOT A REGULAR FILE, AND NOT A LINK EITHER — a directory, a FIFO, a socket, a
# device. `-e` is true for all of them and the requirement says regular file, so
# they all stop here. The FIFO is the one that matters in practice: it is not a
# directory, nothing structural distinguishes it in a listing, and READING one
# blocks until a writer appears. A refusal is a worse outcome than success and a
# far better one than a scaffolder that never returns.
for name in AGENTS.md CLAUDE.md; do
  if [ -e "$name" ] && [ ! -f "$name" ]; then
    die "$name exists and is not a regular file. Both instruction file names must be
            regular files. Remove or rename it, then re-run."
  fi
done

# Both names as separate regular files. Identical content has nothing to choose
# between; differing content is a decision about which rule survives, and that
# is not this script's to make.
if [ -f AGENTS.md ] && [ -f CLAUDE.md ]; then
  cmp -s AGENTS.md CLAUDE.md \
    || die "AGENTS.md and CLAUDE.md differ. Reconcile them by hand — deciding which of two
            rules survives is yours to decide, and this script will not guess. They must be
            byte-identical before it can write to either."
fi

# THE BASE. One file supplies the content both names end up holding: whichever
# exists, and AGENTS.md when both do — they are identical by the check above, so
# the choice is arbitrary and only the determinism matters.
BASE=""
ADOPTED_FROM_CLAUDE=no
if [ -f AGENTS.md ]; then
  BASE=AGENTS.md
elif [ -f CLAUDE.md ]; then
  BASE=CLAUDE.md
  ADOPTED_FROM_CLAUDE=yes
fi

# THE MARKER PAIR MUST DELIMIT SOMETHING. Updating the block means replacing the
# lines between the two markers, and a file carrying one marker without the
# other, or two of either, gives no answer to "where does the block end". The
# obvious guesses — to the end of the file, or to the first marker of any kind —
# both eat content the script does not own. Refuse and say so.
BEGIN_LINE=""
END_LINE=""
if [ -n "$BASE" ]; then
  n_begin=$(grep -cF "$BEGIN_MARKER" "$BASE")
  n_end=$(grep -cF "$END_MARKER" "$BASE")
  if [ "$n_begin" -gt 1 ] || [ "$n_end" -gt 1 ]; then
    die "$BASE carries $n_begin begin and $n_end end markers. Exactly one of each, or none,
            is the only shape that can be updated safely. Reconcile it by hand, then re-run."
  fi
  if [ "$n_begin" -ne "$n_end" ]; then
    die "$BASE carries $n_begin begin and $n_end end markers — an unterminated workflow
            section. Where the block ends cannot be known, and guessing would rewrite
            content this script does not own. Repair the markers, then re-run."
  fi
  if [ "$n_begin" -eq 1 ]; then
    BEGIN_LINE=$(grep -nF "$BEGIN_MARKER" "$BASE" | cut -d: -f1)
    END_LINE=$(grep -nF "$END_MARKER" "$BASE" | cut -d: -f1)
    [ "$BEGIN_LINE" -lt "$END_LINE" ] \
      || die "$BASE carries the end marker above the begin marker. Repair them, then re-run."
  fi
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

# A pointer, never a copy. Behaviour lives in the skill, which is one file
# reaching every host; a copy here would be a version of it, and versions in
# repositories are the drift this workflow removes.
render_block() {
  printf '%s\n' "$BEGIN_MARKER"
  printf '\n## The AgenticApps workflow\n\n'
  printf 'Work moves through the OpenSpec lifecycle, and how to do that lives in the\n'
  printf '`agentic-apps-workflow` skill on this machine — not in this file. Read the\n'
  printf 'skill for the loop, the gates and the coding discipline.\n\n'
  printf 'This repository carries two workflow artifacts: `openspec/`, which is its\n'
  printf 'durable truth, and this instruction file. Everything else — skills, hooks,\n'
  printf 'enforcement — is machine-level and comes from `install.sh`.\n\n'
  printf '%s\n' "$END_MARKER"
}

# THE NEW CONTENT, BUILT WHOLE BEFORE EITHER NAME IS OPENED, and built in a
# VARIABLE rather than a temporary file. A temp file beside the destination is a
# path this script would then have to move or delete, and it may do neither; a
# temp file elsewhere is a deletion it would still owe. The trailing sentinel is
# the standard guard against `$( )` eating trailing newlines — without it a file
# ending in a blank line loses it on every run, which is a byte outside the
# markers changing, which is the one thing this write promises not to do.
#
# UPDATE, NOT SKIP. 1.x wrote the block only when no marker was present, so a
# repository carrying a section from any earlier version kept it for ever. The
# bytes before the begin marker and after the end marker are copied through
# verbatim; everything between them is replaced. That is the exact scope of the
# preservation claim, and the only scope in which it can be true.
if [ -n "$BEGIN_LINE" ]; then
  NEW=$( { head -n "$((BEGIN_LINE - 1))" "$BASE"; render_block; tail -n "+$((END_LINE + 1))" "$BASE"; printf 'X'; } )
  ACTION="section updated"
elif [ -n "$BASE" ]; then
  # Appended with one blank line between, and a newline forced onto a file that
  # lacks one — otherwise the marker would land on the end of somebody's last
  # sentence. That newline is the single byte outside the markers this script
  # will add, and only to a file that was not newline-terminated to begin with.
  NEW=$( { cat "$BASE"; [ -s "$BASE" ] && [ "$(tail -c1 "$BASE" | od -An -tu1 | tr -d ' \n')" != 10 ] && printf '\n'; [ -s "$BASE" ] && printf '\n'; render_block; printf 'X'; } )
  ACTION="section appended"
else
  NEW=$( { render_block; printf 'X'; } )
  ACTION="section written"
fi
NEW=${NEW%X}

# WRITTEN IN PLACE, TO BOTH NAMES, and in that order for a reason: a redirection
# truncates and rewrites the file that is already there, keeping its inode, its
# mode and its path. Nothing here moves a file over another, creates a link, or
# removes a name — the three operations that turned a guard defect into data
# loss, and the three this version does not perform at all.
#
# The second write can still fail after the first succeeded, which leaves the
# two names differing. That is reported rather than papered over, because the
# gate will fail the next commit and the operator needs to know why.
printf '%s' "$NEW" > AGENTS.md \
  || die "could not write AGENTS.md"
printf '%s' "$NEW" > CLAUDE.md \
  || die "could not write CLAUDE.md — AGENTS.md has been updated and the two names now
            differ. Copy AGENTS.md over CLAUDE.md, or re-run once the cause is fixed."

say "AGENTS.md    $ACTION"
say "CLAUDE.md    $ACTION"

# VERIFIED BY READING, NEVER BY STAT. `-L` reports true for BOTH halves of a
# symlink cycle and `readlink` reports a plausible target for each, so every
# structural check this script and its suite made was satisfied by two
# repositories whose instruction file could not be read at all. Only a read
# tells a working file from a broken one, and it is also the only check that
# proves the two writes above landed the same bytes.
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
  say "         git config. openspec/ and the instruction files are in place, but the"
  say "         machine's pre-commit floor will NOT gate this repository until it is"
  say "         set: git config --local agenticapps.workflow.enrolled true"
fi

# The readership still widens, even though nothing moved. CLAUDE.md keeps its
# path and its content; what changed is that the same bytes now also sit in
# AGENTS.md, which four other hosts read. That is a semantic change to somebody
# else's file and it gets said out loud.
if [ "$ADOPTED_FROM_CLAUDE" = yes ]; then
  say ""
  say "NOTE: your CLAUDE.md stays where it is, and AGENTS.md now holds the same"
  say "      content. Rules that only Claude read are read by every host that reads"
  say "      AGENTS.md — codex, opencode, pi, omp. The two must stay identical; the"
  say "      commit gate fails a commit in which they diverge."
fi
