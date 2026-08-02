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
#
# Exit 0 = installed, upgraded, repaired or already current.
# Exit 1 = refused (foreign hook, or hooks dir inside the working tree).
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

# Refuse to write into tracked repository content.
if git ls-files --error-unmatch "$HOOKS_DIR" >/dev/null 2>&1; then
  printf 'refusing: resolved hooks directory is tracked repository content:\n  %s\n' "$HOOKS_DIR" >&2
  printf 'core.hooksPath points into the working tree. Installing there would commit a\n' >&2
  printf 'hook into the repository, which is a different decision from installing one\n' >&2
  printf 'locally. Unset core.hooksPath or install the hook deliberately by hand.\n' >&2
  exit 1
fi

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
ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"
GATE="\${OPENSPEC_GATE:-\$ROOT/reference-implementations/openspec-change-gate/openspec-change-gate.sh}"
if [ ! -x "\$GATE" ]; then
  printf 'openspec-gate: WARNING — gate not found at %s; commit not gated.\\n' "\$GATE" >&2
  exit 0
fi
export OPENSPEC_GATE_SELF="\${OPENSPEC_GATE_SELF:-claude}"
exec "\$GATE" --pre-commit
EOF

mkdir -p "$HOOKS_DIR"

if [ ! -e "$HOOK" ]; then
  printf '%s\n' "$DESIRED" > "$HOOK" && chmod +x "$HOOK"
  printf 'installed: %s\n' "$HOOK"; exit 0
fi

if ! grep -qF "$MARKER" "$HOOK" 2>/dev/null; then
  printf 'refusing: %s exists and was not written by this installer.\n' "$HOOK" >&2
  printf 'It carries no ownership marker, so overwriting it could destroy work this\n' >&2
  printf 'script knows nothing about. Inspect it, then move it aside if you want the\n' >&2
  printf 'gate installed.\n' >&2
  exit 1
fi

if [ "$(cat "$HOOK")" != "$DESIRED" ]; then
  printf '%s\n' "$DESIRED" > "$HOOK" && chmod +x "$HOOK"
  printf 'upgraded: %s (was stale)\n' "$HOOK"; exit 0
fi

if [ ! -x "$HOOK" ]; then
  chmod +x "$HOOK"
  printf 'repaired: %s (content current, execute bit restored)\n' "$HOOK"; exit 0
fi

printf 'already current: %s\n' "$HOOK"
exit 0
