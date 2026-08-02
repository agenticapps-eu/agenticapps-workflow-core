#!/usr/bin/env bash
# tools/install-core-git-hooks.sh — install core's own pre-commit gate.
#
# The hooks directory is not tracked by git, so this cannot arrive by checkout.
#
# RESOLUTION. The destination comes from `git rev-parse --git-path hooks`, never
# from a literal `.git/hooks/` path. Two reasons, both verified rather than
# assumed:
#
#   - In a LINKED WORKTREE, `.git` is a FILE, not a directory, so `.git/hooks/`
#     does not exist. rev-parse returns the main checkout's hooks directory,
#     which is also the one git will read — worktrees share hooks.
#   - rev-parse HONORS core.hooksPath. Set core.hooksPath=.githooks and the
#     command returns `.githooks`. So this script does not inspect that setting
#     and does not refuse when it is present: the resolver already targets the
#     directory git actually reads. Refusing on its mere presence would be a
#     false positive every time, including when it names the default directory.
#
# The one case that DOES warrant refusal is a resolved hooks directory inside
# the working tree, which means hooksPath points at tracked repository content.
# Installing there writes into the repo rather than into local untracked config
# — a different act with different consequences, so it is reported, not decided.
#
# OWNERSHIP is a marker line, not byte equality. Byte equality cannot express
# ownership across versions: a hook this script wrote and later revised would
# read as foreign and be refused forever, so the gate could never be advanced.
# A marker is an ownership CLAIM, not an integrity proof — a hand-edited or
# adversarially marked hook will be treated as ours and updated in place. For a
# locally-bypassable, --no-verify-able convenience hook that is proportionate.
# The claim must be the WHOLE line: a hook that merely mentions the marker in
# passing has not made it.
#
# Exit 0 = installed, upgraded, repaired or already current.
# Exit 1 = refused (foreign hook, a symlink, or hooks dir inside the working tree).
set -uo pipefail

MARKER='# managed-by: agenticapps-workflow-core tools/install-core-git-hooks.sh'

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'not inside a git repository\n' >&2; exit 1; }
cd "$ROOT" || exit 1

HOOKS_DIR="$(git rev-parse --git-path hooks)" || exit 1
case "$HOOKS_DIR" in
  /*) ;;                                   # already absolute
  *)  HOOKS_DIR="$ROOT/$HOOKS_DIR" ;;
esac

# Refuse to write anywhere INSIDE the working tree.
#
# The test is path containment, not tracking status. An earlier revision asked
# `git ls-files --error-unmatch "$HOOKS_DIR"` — but an UNTRACKED directory inside
# the tree (core.hooksPath=.githooks, freshly created) fails that lookup, which
# the script then read as permission to write. Reproduced: the hook landed in
# the worktree. Tracking status answers "is this committed", and the question
# here is "is this repository content", which an untracked in-tree path also is.
# Canonicalise a path that need NOT exist: resolve the deepest existing
# ancestor with cd+pwd -P, then re-append the components below it.
#
# `cd` can only resolve a directory that is already there, and a single-level
# parent fallback is not enough. With core.hooksPath=deep/not/there BOTH the
# directory and its parent are missing, so the fallback produced the
# absolute-looking `/there` — which does not start with $ROOT_P, sailed through
# the containment test below, and let `mkdir -p` create the missing parents and
# install a hook INSIDE the working tree, reported as success. Reproduced before
# this was written. It is the same defect as the tracking-status test that
# preceded it: the guard answered a question adjacent to the one being asked.
canon(){
  p="$1"; rest=""
  while [ -n "$p" ] && [ ! -d "$p" ]; do
    rest="$(basename "$p")${rest:+/$rest}"
    p="$(dirname "$p")"
  done
  head="$( cd "$p" 2>/dev/null && pwd -P )" || return 1
  [ -n "$head" ] || return 1
  printf '%s' "${head%/}${rest:+/$rest}"
}
ROOT_P="$(canon "$ROOT")" || { printf 'failed: could not resolve %s\n' "$ROOT" >&2; exit 1; }
HOOKS_P="$(canon "$HOOKS_DIR")" || { printf 'failed: could not resolve %s\n' "$HOOKS_DIR" >&2; exit 1; }

case "$HOOKS_P/" in
  "$ROOT_P"/.git/*) ;;                      # inside .git — the normal case, fine
  "$ROOT_P"/*)
    printf 'refusing: resolved hooks directory is inside the working tree:\n  %s\n' "$HOOKS_P" >&2
    printf 'core.hooksPath points at repository content. Installing there writes a hook\n' >&2
    printf 'into the repo rather than into local untracked config — a different decision\n' >&2
    printf 'with different consequences. Unset core.hooksPath, point it outside the tree,\n' >&2
    printf 'or install the hook deliberately by hand.\n' >&2
    exit 1
    ;;
esac

if [ "$HOOKS_DIR" != "$ROOT/.git/hooks" ]; then
  printf 'note: hooks directory resolves to %s\n' "$HOOKS_DIR"
  printf '      (a linked worktree shares the main checkout'"'"'s hooks, and core.hooksPath\n'
  printf '       is honoured by the resolver — this hook applies to both)\n'
fi

HOOK="$HOOKS_DIR/pre-commit"

read -r -d '' DESIRED <<EOF
#!/usr/bin/env bash
$MARKER
#
# Core's pre-commit gate (spec §18). Resolves core's OWN working-tree reference
# implementation, not the shared install at ~/.agenticapps/bin/ — core is the
# source of truth for those bytes. See ADR-0028.
#
# Fails OPEN if the gate is missing: a commit hook that hard-fails on absent
# tooling trains people to pass --no-verify, which disables it permanently.
# Regenerate with: bash tools/install-core-git-hooks.sh
#
# git runs hooks from the top of the working tree, so rev-parse resolves here —
# but its failure is checked rather than assumed, because an empty ROOT would
# silently degrade this into the fail-open branch and report nothing useful.
#
# No OPENSPEC_GATE_SELF export: the gate has IGNORED it since 1.5.0 and reads
# the implementing host from the REVIEWS.md trailer instead.
ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT=""
if [ -z "\$ROOT" ] && [ -z "\${OPENSPEC_GATE:-}" ]; then
  printf 'openspec-gate: WARNING — not inside a git working tree; commit not gated.\\n' >&2
  exit 0
fi
GATE="\${OPENSPEC_GATE:-\$ROOT/reference-implementations/openspec-change-gate/openspec-change-gate.sh}"
if [ ! -x "\$GATE" ]; then
  printf 'openspec-gate: WARNING — gate not found at %s; commit not gated.\\n' "\$GATE" >&2
  exit 0
fi
exec "\$GATE" --pre-commit
EOF

# Every filesystem operation is required to succeed. Without this, a failing
# mkdir, write or chmod still fell through to printing "installed" and exiting
# 0 — reporting a gate that is not there.
#
# The write is ATOMIC: a temporary file in the same directory, made executable,
# then renamed over the destination. Redirecting straight onto "$HOOK"
# truncates a working hook before the new bytes are known to be complete, so an
# ENOSPC or an interrupt leaves a TRUNCATED hook that git will still execute —
# reported as a failure while having already broken what was there. Same
# same-directory-temp-plus-rename pattern as
# reference-implementations/shared-install/install-shared-artifact.sh.
write_hook(){
  mkdir -p "$HOOKS_DIR" || { printf 'failed: could not create %s\n' "$HOOKS_DIR" >&2; return 1; }
  tmp="$HOOKS_DIR/.pre-commit.$$.tmp"
  printf '%s\n' "$DESIRED" > "$tmp" || {
    printf 'failed: could not write %s\n' "$tmp" >&2; rm -f "$tmp"; return 1; }
  chmod +x "$tmp" || {
    printf 'failed: could not chmod +x %s\n' "$tmp" >&2; rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$HOOK" || {
    printf 'failed: could not move %s into place\n' "$tmp" >&2; rm -f "$tmp"; return 1; }
  return 0
}

# -e is FALSE for a dangling symlink, so testing it alone took the "nothing is
# here" branch for `pre-commit -> ../../created-in-worktree`, and the redirect
# then FOLLOWED the link and created that file — inside the working tree, the
# very thing the containment check above exists to prevent, reported as
# `installed`. Reproduced. -L is therefore tested separately, and a symlink is
# never written through: it carries no marker this script can read, so it is
# foreign by the same rule that governs any other hook it did not write.
if [ -L "$HOOK" ]; then
  printf 'refusing: %s is a symlink -> %s\n' "$HOOK" "$(readlink "$HOOK")" >&2
  printf 'Writing through it would modify the link target rather than the hook, and the\n' >&2
  printf 'target may lie inside the working tree. Inspect it, then move it aside if you\n' >&2
  printf 'want the gate installed.\n' >&2
  exit 1
fi

if [ ! -e "$HOOK" ]; then
  write_hook || exit 1
  printf 'installed: %s\n' "$HOOK"; exit 0
fi

# -x, not a bare substring match: the marker must be the WHOLE line. With
# `grep -qF` a foreign hook that merely MENTIONS the marker — inside an echo, a
# comment about this installer, a copied-in doc block — was claimed as ours and
# overwritten. Reproduced: a hook whose body was `echo '# managed-by: ... is
# only documentation'; exit 42` was silently replaced. Ownership is a claim the
# writer makes on its own line, not a string that appears somewhere in a file.
if ! grep -qxF "$MARKER" "$HOOK" 2>/dev/null; then
  printf 'refusing: %s exists and was not written by this installer.\n' "$HOOK" >&2
  printf 'It carries no ownership marker, so overwriting it could destroy work this\n' >&2
  printf 'script knows nothing about. Inspect it, then move it aside if you want the\n' >&2
  printf 'gate installed.\n' >&2
  exit 1
fi

if [ "$(cat "$HOOK")" != "$DESIRED" ]; then
  write_hook || exit 1
  printf 'upgraded: %s (was stale)\n' "$HOOK"; exit 0
fi

if [ ! -x "$HOOK" ]; then
  chmod +x "$HOOK" || { printf 'failed: could not chmod +x %s\n' "$HOOK" >&2; exit 1; }
  printf 'repaired: %s (content current, execute bit restored)\n' "$HOOK"; exit 0
fi

printf 'already current: %s\n' "$HOOK"
exit 0
