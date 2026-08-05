#!/usr/bin/env bash
# installer-prereq-conformance.sh — scores one installer against spec §21,
# "Installer prerequisites and consent".
#
# Usage: tools/installer-prereq-conformance.sh <path-to-install.sh>
#
# Exit 0 = no row failed, 1 = at least one row failed, 2 = nothing was scored
# (unusable target, unrecognisable target, or a usage error).
#
# SHAPE (capability: conformance-harness-reporting, §20)
#
# SINGLE-TARGET: exactly one target, and it ABORTS on one it cannot use rather
# than counting a failure row and continuing. §20 permits that explicitly — the
# rule is "never exit 0 having scored nothing", and an abort before any row
# satisfies it.
#
# WHAT THIS CAN AND CANNOT SEE
#
# Consent behaviour is only fully observable by RUNNING an installer, and
# running a host's installer is not something core can do safely: it writes to
# the operator's machine, which is the very thing under discussion. So this is
# a static reader. It scores what shell text can settle and reports the rest
# INCONCLUSIVE — never as passing, because a host must not reach a passing
# total on rows nobody scored.
#
# The strongest thing it can prove is a NEGATIVE: an install command that
# crosses the ownership boundary with no consent read and no opt-in anywhere
# before it is unguarded on any reading. That is the codex/opencode defect, and
# it is what this harness exists to name. A PASS on that row means "a guard was
# found before every install site", not "the guard provably dominates it" — a
# script could still reach the install through an indirection this does not
# model. The coverage line, printed on every run, is what keeps that honest.
#
# THE CODE VIEW
#
# Every scan runs over a derived view of the script in which comments are
# blanked and QUOTED LITERALS ARE REMOVED, with `$…` expansions put back. That
# one transformation carries most of the accuracy here, because it encodes the
# distinction the contract turns on:
#
#   echo "install it with: npm install -g @fission-ai/openspec"   -> text
#   npm install -g @fission-ai/openspec                           -> an install
#   CMD="npm install -g @fission-ai/openspec"                     -> text
#
# Without it, `claude-workflow` — which detects, prints the command and never
# installs — would be reported as committing the exact violation it does not
# commit, and the harness would condemn the two conformant hosts along with the
# two defective ones.
#
# Expansions survive the strip because a variable inside a string is code:
# `"${AGENTICAPPS_INSTALL_PREREQS:-0}"` is the opt-in being READ, whereas
# `"pass --install-prereqs"` inside a usage message is the opt-in being
# MENTIONED. A harness that could not tell those apart would accept a help
# string as a guard.
#
# Command substitutions survive for the same reason and a sharper one:
# `OUT="$(npm install -g pkg)"` IS the install. Dropping it with its
# surrounding quotes let an unguarded global install read as fully conformant —
# the consent row, this harness's central job, defeated by a pair of quotes.

set -uo pipefail

pass=0
fail=0
inconclusive=0
WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

# ── target screening (§20) ──────────────────────────────────────────────────
harness_screen_target() { # $1 = path; sets REASON, returns 1 if unscoreable
  REASON=""
  if [ -L "$1" ] && [ ! -e "$1" ]; then REASON="not a regular file (dangling symlink)"; return 1; fi
  if [ ! -e "$1" ]; then REASON="not found"; return 1; fi
  if [ ! -f "$1" ]; then REASON="not a regular file"; return 1; fi
  if [ ! -s "$1" ]; then REASON="empty"; return 1; fi
  if [ ! -r "$1" ]; then REASON="unreadable"; return 1; fi
  return 0
}

# A path is attacker-influenceable in the general case; output that can be
# forged with an embedded newline can be made to print a line reading like PASS.
harness_safe_label() { # $1 = path
  printf '%s' "$1" | LC_ALL=C tr -c '[:print:]' '?'
}

INSTALLER="${1:-}"
[ -n "$INSTALLER" ] || {
  echo "usage: $0 <path-to-install.sh>" >&2
  echo "scores one installer against spec §21 (installer prerequisites and consent)" >&2
  exit 2
}
[ "$#" -eq 1 ] || {
  echo "usage: $0 <path-to-install.sh> — exactly one target, got $#" >&2
  exit 2
}
harness_screen_target "$INSTALLER" || {
  echo "  UNSCOREABLE  $(harness_safe_label "$INSTALLER") — $REASON" >&2
  exit 2
}

LABEL="$(harness_safe_label "$INSTALLER")"
WORK="$(mktemp -d)"
CODE="$WORK/code"

# ── the code view ───────────────────────────────────────────────────────────
# Emits `NNN|<code>` per source line. Comments blank, quoted literals gone,
# `$…` expansions appended so a variable read inside a string survives.
awk '
{
  raw = $0
  if (raw ~ /^[ \t]*#/) { print NR "|"; next }
  exps = ""
  t = raw
  while (match(t, /\$\([^)]*\)|\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@*?]/)) {
    exps = exps " " substr(t, RSTART, RLENGTH)
    t = substr(t, RSTART + RLENGTH)
  }
  r = raw
  gsub(/"[^"]*"/, " ", r)
  gsub(/\047[^\047]*\047/, " ", r)
  sub(/[ \t]#.*$/, "", r)
  print NR "|" r " " exps
}
' "$INSTALLER" > "$CODE"

# Raw view minus whole-line comments, for report detection — a reported path
# lives INSIDE a string, so the code view is the wrong instrument for it.
grep -vE '^[[:space:]]*#' "$INSTALLER" > "$WORK/raw" 2>/dev/null || true
RAW="$WORK/raw"

code_body() { sed 's/^[0-9]*|//' "$CODE"; }

ok()   { echo "  PASS  $1"; pass=$((pass + 1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail + 1)); }
huh()  { echo "  INCONCLUSIVE  $1"; inconclusive=$((inconclusive + 1)); }
note() { echo "        $1"; }

# ── the install-site census (task 3.3) ──────────────────────────────────────
# Structural, not phrasal: an install that can reach outside the target
# repository is recognised by the command that performs it, so nothing depends
# on an installer describing itself in words this harness happens to know.
GLOBAL_INSTALL='(npm|pnpm)[[:space:]]+(i|install|add)[[:space:]]+((-g|--global|--location=global)([[:space:]]|$))'
GLOBAL_INSTALL="$GLOBAL_INSTALL|(npm|pnpm)[[:space:]]+(-g|--global)[[:space:]]+(i|install|add)"
GLOBAL_INSTALL="$GLOBAL_INSTALL|yarn[[:space:]]+global[[:space:]]+add"
GLOBAL_INSTALL="$GLOBAL_INSTALL|pip3?[[:space:]]+install[[:space:]]+.*--user"
GLOBAL_INSTALL="$GLOBAL_INSTALL|pipx[[:space:]]+install"
GLOBAL_INSTALL="$GLOBAL_INSTALL|(gem|cargo|brew)[[:space:]]+install"
GLOBAL_INSTALL="$GLOBAL_INSTALL|go[[:space:]]+install[[:space:]]+[^[:space:]]+@"
GLOBAL_INSTALL="$GLOBAL_INSTALL|curl[[:space:]]+[^|]*\|[[:space:]]*(ba)?sh"

SITES="$(grep -nE "$GLOBAL_INSTALL" "$CODE" | sed 's/^[0-9]*://' || true)"
SITE_COUNT=0
[ -n "$SITES" ] && SITE_COUNT="$(printf '%s\n' "$SITES" | grep -c . )"

# ── prerequisite checks ─────────────────────────────────────────────────────
# `command -v "$1"` inside a one-line `have()` is the fleet's universal idiom,
# so a harness that only read literal `command -v X` would find every installer
# declares nothing. Resolve the wrapper, then read its call sites.
WRAPPERS="$(code_body | grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{.*(command -v|type -[Pp]|which |hash )' \
  | grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' | tr -d ' \t' || true)"

CHECKED="$(code_body | grep -oE '(command[[:space:]]+-v|type[[:space:]]+-[Pp]|which|hash)[[:space:]]+[A-Za-z0-9_.-]+' \
  | awk '{print $NF}' || true)"
for w in $WRAPPERS; do
  more="$(code_body | grep -oE "(^|[;&|({[:space:]])${w}[[:space:]]+[A-Za-z0-9_.-]+" | awk '{print $NF}' || true)"
  CHECKED="$CHECKED
$more"
done
CHECKED="$(printf '%s\n' "$CHECKED" | grep -v '^$' | sort -u || true)"

KNOWN_TOOLS="npm npx node git openspec codex opencode pi python3 pip pip3 go cargo brew gem yarn pnpm"
INVOKED=""
for t in $KNOWN_TOOLS; do
  if code_body | grep -qE "(^|[;&|(){}]|[[:space:]])${t}[[:space:]]"; then
    INVOKED="$INVOKED $t"
  fi
done

# ── writes ──────────────────────────────────────────────────────────────────
WRITE_VERB='(mkdir|cp|install|ln|mv|tee|chmod|touch|rm|cat[[:space:]]+[^|]*>)'
OWNED_WRITES="$(grep -nE "$WRITE_VERB" "$RAW" | grep -E '\.agenticapps' || true)"
OWNED_REPORTS="$(grep -nE '(echo|printf)' "$RAW" | grep -E '\.agenticapps' || true)"
# Provisioning destinations. The host-shaped directories are the obvious half;
# the second half is a write into a RESOLVED destination — `$HOOKS_DIR`,
# `$DEST`, `$TARGET_ROOT`. Core's own `install-core-git-hooks.sh` provisions
# `git rev-parse --git-path hooks` and touches none of the named directories,
# so a screen listing only those calls core's own installer unrecognisable and
# lets core ship a contract it never scored itself against.
PROVISION_DEST='\.claude|\.codex|\.opencode|\.pi/|openspec/|\.git/hooks|hooks/'
PROVISION_DEST="$PROVISION_DEST"'|\$\{?[A-Z_]*(DIR|PATH|DEST|ROOT|HOOK|TARGET|REPO|PROJECT)'
REPO_WRITES="$(grep -nE "$WRITE_VERB" "$RAW" | grep -E "$PROVISION_DEST" || true)"

# ── recognisability ─────────────────────────────────────────────────────────
# The single-target abort, applied to a target that parses but is not an
# installer. Scoring it would produce a row tally about a file nobody claimed
# was an installer, and §20's rule is that a harness never reports a verdict it
# did not reach.
if [ -z "$CHECKED" ] && [ "$SITE_COUNT" -eq 0 ] && [ -z "$OWNED_WRITES" ] && [ -z "$REPO_WRITES" ]; then
  echo "  UNSCOREABLE  $LABEL — not recognisable as an installer" >&2
  echo "        no prerequisite check, no install command, and no provisioning write" >&2
  exit 2
fi

echo "═══ $LABEL"

# ── R1 prereq-detection (task 3.2) ──────────────────────────────────────────
UNDECLARED=""
for t in $INVOKED; do
  printf '%s\n' "$CHECKED" | grep -qx "$t" || UNDECLARED="$UNDECLARED $t"
done
if [ -n "$UNDECLARED" ]; then
  bad "prereq-detection: invoked but never checked:$UNDECLARED"
  note "§21 — an installer declares the external tools it depends on."
elif [ -n "$CHECKED" ]; then
  ok "prereq-detection: every tool it invokes is also checked for"
else
  huh "prereq-detection: no prerequisite check and no known tool invoked"
  note "nothing to cross-reference; not the same as nothing to declare."
fi

# ── R2 consent-guard (tasks 3.3, 3.4) ───────────────────────────────────────
GUARD_READ='(^|[;&|(){}]|[[:space:]])read([[:space:]]|$)'
GUARD_OPTIN='AGENTICAPPS_INSTALL_PREREQS|--install-prereqs'
if [ "$SITE_COUNT" -eq 0 ]; then
  ok "consent-guard: no install reaches outside the workflow's own surface"
  note "detecting and instructing is conformant; only installing unasked is not."
else
  unguarded=""
  for ln in $(grep -nE "$GLOBAL_INSTALL" "$CODE" | cut -d: -f1); do
    src="$(sed -n "${ln}p" "$CODE" | cut -d'|' -f1)"
    before="$(head -n "$ln" "$CODE")"
    if printf '%s\n' "$before" | grep -qE "$GUARD_READ" || \
       printf '%s\n' "$before" | grep -qE "$GUARD_OPTIN"; then
      :
    else
      cmd="$(sed -n "${ln}p" "$CODE" | sed 's/^[0-9]*|//' | grep -oE "$GLOBAL_INSTALL" | head -1)"
      unguarded="$unguarded
  line $src: $cmd"
    fi
  done
  if [ -n "$unguarded" ]; then
    bad "consent-guard: install reachable with no consent read and no opt-in"
    printf '%s\n' "$unguarded" | grep -v '^$' | while IFS= read -r l; do note "$l"; done
    note "§21 — consent is required to change software the workflow does not own."
  else
    ok "consent-guard: every out-of-boundary install has a guard before it"
    note "a guard was found before each site; that it dominates them is not provable here."
  fi
fi

# ── R3 non-interactive (task 3.5) ───────────────────────────────────────────
if [ "$SITE_COUNT" -eq 0 ]; then
  huh "non-interactive: no consent-requiring install, so nothing to gate"
elif code_body | grep -qE '\-t[[:space:]]+0'; then
  ok "non-interactive: stdin is tested for being a terminal"
else
  bad "non-interactive: no test for an absent terminal before an install"
  note "§21 names the rule — standard input not being a terminal."
fi

# ── R4 opt-in ───────────────────────────────────────────────────────────────
if [ "$SITE_COUNT" -eq 0 ]; then
  huh "opt-in: installs nothing, so it is not required to accept the opt-in"
else
  missing=""
  code_body | grep -q 'AGENTICAPPS_INSTALL_PREREQS' || missing="$missing AGENTICAPPS_INSTALL_PREREQS"
  code_body | grep -q -- '--install-prereqs'        || missing="$missing --install-prereqs"
  if [ -n "$missing" ]; then
    bad "opt-in: not accepted:$missing"
    note "both spellings are fixed by §21; a host-chosen name is four names."
  else
    ok "opt-in: both AGENTICAPPS_INSTALL_PREREQS and --install-prereqs are read"
  fi
fi

# ── R5 owned-writes-reported ────────────────────────────────────────────────
if [ -z "$OWNED_WRITES" ]; then
  huh "owned-writes-reported: writes nothing into the workflow's own directory"
elif [ -n "$OWNED_REPORTS" ]; then
  ok "owned-writes-reported: the write into ~/.agenticapps/ is reported"
else
  bad "owned-writes-reported: writes ~/.agenticapps/ and never says so"
  note "the exemption from consent is paired with the obligation to report;"
  note "without the pair it is a loophole rather than a boundary."
fi

# ── R6 redaction ────────────────────────────────────────────────────────────
SECRET='_authToken|[A-Za-z_]*TOKEN[[:space:]]*=|token=|password=|passwd=|api[_-]?key=|://[^/[:space:]]*:[^@[:space:]]*@|npm_[A-Za-z0-9]{12,}|gh[pousr]_[A-Za-z0-9]{20,}'
PRINTED="$(grep -nE '(echo|printf)' "$RAW" || true)"
LEAKS="$(printf '%s\n' "$PRINTED" | grep -nE "$SECRET" | cut -d: -f2 || true)"
if [ -n "$LEAKS" ]; then
  bad "redaction: a printed line carries something credential-shaped"
  printf '%s\n' "$LEAKS" | grep -v '^$' | head -5 | while IFS= read -r l; do note "line $l"; done
  note "the value is withheld here on purpose — naming it would republish it."
elif printf '%s\n' "$PRINTED" | grep -qE 'install|npm[[:space:]]|pip[[:space:]]'; then
  ok "redaction: commands are printed and none carries a credential"
else
  huh "redaction: prints no command, so there is nothing to redact"
fi

# ── R7 uninstall-preserves-prereqs ──────────────────────────────────────────
REMOVE_PREREQ='(npm|pnpm|yarn)[[:space:]]+(rm|uninstall|remove)[[:space:]]+(-g|--global)|pip3?[[:space:]]+uninstall|(gem|cargo|brew|pipx)[[:space:]]+uninstall'
if code_body | grep -qE -- '--uninstall|(^|[[:space:]])uninstall\)|uninstall\(\)'; then
  if code_body | grep -qE "$REMOVE_PREREQ"; then
    bad "uninstall-preserves-prereqs: removal takes a prerequisite with it"
    note "§21 — by now other projects may resolve it; removing it changes"
    note "software the workflow does not own, which consent existed to prevent."
  else
    ok "uninstall-preserves-prereqs: removal leaves prerequisites in place"
  fi
else
  huh "uninstall-preserves-prereqs: no removal path, so nothing to judge"
fi

# ── coverage and total (tasks 3.6, 3.7) ─────────────────────────────────────
# Emitted on EVERY run, complete ones included. A line that appears only when
# something is wrong becomes the signal, and its absence then has to be noticed
# to mean anything.
scored=$((pass + fail))
total=$((scored + inconclusive))
echo
echo "─── coverage: $scored of $total rows scored, $inconclusive inconclusive"
echo "═══ TOTAL: $pass passed, $fail failed, $inconclusive inconclusive"

if [ "$scored" -eq 0 ]; then
  echo "scored nothing — that is the absence of a result, not a pass" >&2
  exit 2
fi
[ "$fail" -eq 0 ] || exit 1
exit 0
