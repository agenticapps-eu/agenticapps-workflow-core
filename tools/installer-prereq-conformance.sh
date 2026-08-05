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
# Emits `NNN|<code>`, one output line per source line. Comments blank, quoted
# literals gone, `$…` expansions appended so a variable read inside a string
# survives. Two constructs span lines and must be resolved here, because every
# scan below reads one line at a time:
#
#   HEREDOC BODIES ARE DATA. An installer that writes its own README with
#   `cat > README.md <<'DOC'` puts an `npm i -g …` inside the body, and a
#   line-at-a-time reader scores the documentation as an install site. That is
#   the mistake the quote strip exists to prevent, one construct over.
#
#   CONTINUED COMMANDS ARE ONE COMMAND. `npm install \` newline `-g pkg` has
#   no line containing both the verb and the flag, so the census matched
#   nothing and the consent row reported that no install reaches outside the
#   workflow's surface — of a script whose next line installs globally.
#   codex-workflow's real site already breaks that line; it happens to break
#   one token to the right.
#
# A joined command is emitted at its LAST physical line carrying its FIRST
# line's number, so `head -n` prefixes stay usable and the number reported to
# the operator is where the command starts.
awk '
function even_quotes(s,   n) {
  n = gsub(/"/, "\"", s);   if (n % 2) return 0
  n = gsub(/\047/, "\047", s); if (n % 2) return 0
  return 1
}
function emit(n, raw,   exps, t, r) {
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
  print n "|" r " " exps
}
{
  raw = $0

  if (inhere) {
    line = raw
    sub(/^[ \t]+/, "", line)
    if (line == hereterm) inhere = 0
    print NR "|"
    next
  }

  if (buf == "" && raw ~ /^[ \t]*#/) { print NR "|"; next }
  if (buf == "") bufstart = NR

  if (raw ~ /\\[ \t]*$/) {
    sub(/\\[ \t]*$/, " ", raw)
    buf = buf raw
    print NR "|"
    next
  }

  logical = buf raw
  buf = ""

  # `<<WORD` / `<<-WORD`, quoted or not, but never `<<<` and never a `<<` that
  # sits inside a string — an odd quote count before it means it is text.
  #
  # The `<<<` test is a check on the PRECEDING character, not an alternation.
  # A herestring `read -r a b c <<<"$1"` matches `<<"$1"` starting one
  # character in, and reading that as a heredoc opens a body whose terminator
  # is `$1` — never found, so every line after it goes blank. The pi installer
  # has two herestrings on line 118, and the whole rest of the file went dark.
  if (match(logical, /<<-?[ \t]*("[^"]+"|\047[^\047]+\047|[A-Za-z_][A-Za-z0-9_]*)/)) {
    prev = (RSTART > 1) ? substr(logical, RSTART - 1, 1) : ""
    if (prev != "<" && even_quotes(substr(logical, 1, RSTART - 1))) {
      hereterm = substr(logical, RSTART, RLENGTH)
      sub(/^<<-?[ \t]*/, "", hereterm)
      gsub(/["\047]/, "", hereterm)
      inhere = 1
    }
  }

  emit(bufstart, logical)
}
END {
  if (buf != "") emit(bufstart, buf)
  # A heredoc whose terminator is never found blanks every line after it, and
  # a truncated view is the one thing this must never score silently — it is
  # the harness declining to look while sounding like it looked.
  if (inhere) print "0|__UNTERMINATED_HEREDOC__ " hereterm
}
' "$INSTALLER" > "$CODE"

if grep -q '__UNTERMINATED_HEREDOC__' "$CODE"; then
  echo "  UNSCOREABLE  $LABEL — unterminated heredoc; the file could not be read" >&2
  echo "        everything after it would have been scored as if it were absent" >&2
  exit 2
fi

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
# The workflow's own directory is almost never written through its literal
# path. Every installer in the fleet binds it once — `AA_BIN`, `AGENTICAPPS_BIN`
# — and writes through the variable thereafter. Matching only the literal finds
# the write in one installer out of four and reports the rest as having nothing
# to judge, which is the harness declining to look while sounding like it
# looked. So: resolve any variable bound to an .agenticapps path, then treat a
# write or a report through that variable as a write or a report.
#
# `export AA_BIN=…`, `readonly`, `local` and `declare` bind it just as plainly
# as a bare assignment does, and anchoring on the identifier alone missed all
# four — the same false "nothing to judge" as matching the literal path, one
# keyword over.
OWNED_VARS="$(grep -oE '^[[:space:]]*(export|readonly|declare|local|typeset)?[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[^[:space:];]*\.agenticapps' "$RAW" \
  | sed 's/=.*//' \
  | sed -E 's/^[[:space:]]*(export|readonly|declare|local|typeset)[[:space:]]+//' \
  | tr -d ' \t' | sort -u || true)"
OWNED_PAT='\.agenticapps'
for v in $OWNED_VARS; do
  OWNED_PAT="${OWNED_PAT}|[\$][{]?${v}"
done

OWNED_WRITES="$(grep -nE "$WRITE_VERB" "$RAW" | grep -E "$OWNED_PAT" || true)"
OWNED_REPORTS="$(grep -nE '(echo|printf)' "$RAW" | grep -E "$OWNED_PAT" || true)"
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
# A guard reaches a site only until a construct CLOSES above it. `fi`, `done`,
# `esac`, `else` and `}` at column 0 end the branch the guard was in, so a
# guard above one of them settles nothing about a site below it.
#
# Searching the whole prefix instead made the row "does the word `read` occur
# earlier in this file", and that fails in the direction that costs the most:
# the FIRST correctly gated site in a script permanently satisfies every site
# added after it. An installer with one gated install and one ungated install
# scores clean. The row would go green exactly as the fleet started adopting
# §21 and never fail again.
#
# A `while`/`until` read is a loop over input, not a question put to the
# operator, so it is not consent evidence.
GUARD_READ='(^|[;&|(){}]|[[:space:]])read([[:space:]]|$)'
LOOP_READ='(^|[[:space:]])(while|until)([[:space:]]|$)'
CUTTER='^[0-9]+\|(fi|done|esac|else|elif|;;|\})([[:space:]]|$)'
# The opt-in is read once at the top and TESTED near the site — through the
# variable it was bound to, which is the shape all four hosts will write. Only
# the code view is searched, so a `--install-prereqs` inside a usage string is
# still a mention rather than a guard.
OPTIN_VARS="$(code_body | grep -E 'AGENTICAPPS_INSTALL_PREREQS|--install-prereqs' \
  | grep -oE '[A-Za-z_][A-Za-z0-9_]*=' | sed 's/=$//' \
  | grep -v '^AGENTICAPPS_INSTALL_PREREQS$' | sort -u || true)"
GUARD_OPTIN='AGENTICAPPS_INSTALL_PREREQS|--install-prereqs'
for v in $OPTIN_VARS; do
  GUARD_OPTIN="$GUARD_OPTIN|(^|[^A-Za-z0-9_])${v}([^A-Za-z0-9_]|$)"
done
if [ "$SITE_COUNT" -eq 0 ]; then
  ok "consent-guard: no out-of-boundary install command was found"
  note "detecting and instructing is conformant; only installing unasked is not."
  note "the census reads command shapes — an install through a variable, or"
  note "through a package manager not on its list, would not be seen."
else
  unguarded=""
  for ln in $(grep -nE "$GLOBAL_INSTALL" "$CODE" | cut -d: -f1); do
    src="$(sed -n "${ln}p" "$CODE" | cut -d'|' -f1)"
    cut_at="$(head -n "$((ln - 1))" "$CODE" | grep -nE "$CUTTER" | tail -1 | cut -d: -f1)"
    before="$(sed -n "$((${cut_at:-0} + 1)),${ln}p" "$CODE")"
    if printf '%s\n' "$before" | grep -vE "$LOOP_READ" | grep -qE "$GUARD_READ" || \
       printf '%s\n' "$before" | grep -qE "$GUARD_OPTIN"; then
      :
    else
      # The whole line, not just the matched pattern. §21 requires the check to
      # name the command; `npm i -g` with the package sheared off names the
      # pattern that matched, and leaves the operator to go and find what it
      # was actually going to install.
      # `tr -c '[:print:]'` also converts the trailing newline, which appended a
      # stray `?` to every command this row named — it read as part of the
      # command the operator was being sent to look at.
      cmd="$(sed -n "${ln}p" "$CODE" | sed 's/^[0-9]*|//;s/^[[:space:]]*//;s/[[:space:]]*$//' \
        | tr -d '\n' | LC_ALL=C tr -c '[:print:]' '?' | cut -c1-120)"
      unguarded="$unguarded
  line $src: $cmd"
    fi
  done
  if [ -n "$unguarded" ]; then
    bad "consent-guard: install reachable with no consent read and no opt-in"
    printf '%s\n' "$unguarded" | grep -v '^$' | while IFS= read -r l; do note "$l"; done
    note "§21 — consent is required to change software the workflow does not own."
  else
    ok "consent-guard: every out-of-boundary install has a guard in its branch"
    note "a consent read or the opt-in was found in each site's own branch, with"
    note "no construct closing between; that it dominates the site is not provable here."
  fi
fi

# ── R3 non-interactive (task 3.5) ───────────────────────────────────────────
if [ "$SITE_COUNT" -eq 0 ]; then
  huh "non-interactive: no consent-requiring install, so nothing to gate"
elif code_body | grep -qE '\-t[[:space:]]+0'; then
  ok "non-interactive: stdin is tested for being a terminal"
  note "the test is present somewhere in the script; that this particular test"
  note "is the one gating the install is not established here."
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
# §21 requires every file written into the owned directory to be reported BY
# NAME. Naming the directory once tells the operator a write happened and
# nothing about what is now in it, which is the reporting obligation met in
# form rather than substance. Files are enumerated from the write itself; a
# write through a glob or a loop resolves to no filename, and the row says so
# rather than passing on evidence it does not have.
OWNED_FILES="$(printf '%s\n' "$OWNED_WRITES" \
  | grep -E '(cp|install|ln|mv|tee|touch|cat[[:space:]]+[^|]*>)' \
  | grep -oE "($OWNED_PAT)[^\"'[:space:]]*" \
  | grep -oE '/[A-Za-z0-9._-]+\.[A-Za-z0-9]+$' | tr -d '/' | sort -u || true)"
REPORTED_TEXT="$(grep -E '(echo|printf)' "$RAW" || true)"
if [ -z "$OWNED_WRITES" ]; then
  huh "owned-writes-reported: writes nothing into the workflow's own directory"
elif [ -z "$OWNED_REPORTS" ]; then
  bad "owned-writes-reported: writes ~/.agenticapps/ and never says so"
  note "the exemption from consent is paired with the obligation to report;"
  note "without the pair it is a loophole rather than a boundary."
else
  unnamed=""
  for f in $OWNED_FILES; do
    printf '%s\n' "$REPORTED_TEXT" | grep -qF "$f" || unnamed="$unnamed $f"
  done
  if [ -n "$unnamed" ]; then
    bad "owned-writes-reported: written into ~/.agenticapps/ but never named:$unnamed"
    note "§21 — every file written into a directory this workflow owns is"
    note "reported by name. Naming the directory is not naming the files."
  elif [ -n "$OWNED_FILES" ]; then
    ok "owned-writes-reported: every file written into ~/.agenticapps/ is named"
  else
    huh "owned-writes-reported: the directory is reported, but no write here"
    note "resolves to a filename, so whether each file is named is undecided."
  fi
fi

# ── R6 redaction ────────────────────────────────────────────────────────────
SECRET='_authToken|[A-Za-z_]*TOKEN[[:space:]]*=|token=|password=|passwd=|api[_-]?key=|://[^/[:space:]]*:[^@[:space:]]*@|npm_[A-Za-z0-9]{12,}|gh[pousr]_[A-Za-z0-9]{20,}'
PRINTED="$(grep -nE '(echo|printf)' "$RAW" || true)"
# Numbered from the SOURCE, not from `$RAW`. `$RAW` has its comment lines
# removed, so its line numbers are positions in a file the operator does not
# have — this row was sending them to a line that was not the one.
LEAKS="$(grep -nE '(echo|printf)' "$INSTALLER" | grep -vE '^[0-9]+:[[:space:]]*#' \
  | grep -E "$SECRET" | cut -d: -f1 || true)"
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
