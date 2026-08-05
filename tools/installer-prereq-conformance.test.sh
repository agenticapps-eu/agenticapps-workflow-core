#!/usr/bin/env bash
# installer-prereq-conformance.test.sh — pins `installer-prereq-conformance.sh`
# in both directions.
#
# This is a TEST, not a conformance harness. It scores core's own harness
# against §21 and §20; the harness scores a host's installer against §21.
# Named per the `drift-report.test.sh` precedent.
#
# WHY BOTH DIRECTIONS
#
# A harness that fails everything is as useless as one that passes everything,
# and only one of those is caught by pointing it at a broken installer. So
# every row is pinned twice: a conformant reference installer that MUST reach
# a clean exit, and a violating fixture that MUST fail the specific row it
# violates AND no other. The second clause is the one that matters — a row
# that fires on every fixture is indistinguishable from a row that fires on
# nothing.
#
# THE FIXTURES ARE THE REAL FLEET
#
# Four of them reproduce the shapes actually on disk in the four host repos,
# because the contract was written about those shapes and a harness that does
# not sort them correctly has not been tested:
#
#   codexish   — `npm i -g` reachable with no prompt and no flag. The defect.
#   claudeish  — detects `openspec`, prints the command, never installs.
#                MUST NOT fail the consent row: instructing without installing
#                is conformant even though it does not offer.
#   ownedonly  — writes only into ~/.agenticapps/bin/. MUST NOT require
#                consent, MUST be required to report. This is the ownership
#                boundary's whole point, and the row that would have caught
#                the location rule condemning all four installers.
#   repolocal  — writes only inside the target repo. Needs no prompt.
#
# Usage: tools/installer-prereq-conformance.test.sh [row-name-substring]

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS="$HERE/installer-prereq-conformance.sh"
FILTER="${1:-}"

pass=0 fail=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; fail=$((fail + 1)); [ -n "${2:-}" ] && echo "        $2"; }

# Run the harness over a fixture. Sets OUT and CODE.
run() { # $1 = fixture path, rest = extra args
  OUT="$("$HARNESS" "$@" 2>&1)"
  CODE=$?
}

# A row assertion: name, then expectations against the last run.
want_code() { # $1 = label, $2 = expected exit code
  if [ "$CODE" -eq "$2" ]; then ok "$1 (exit $CODE)"
  else bad "$1" "expected exit $2, got $CODE. Output:
$OUT"; fi
}

want_row() { # $1 = label, $2 = row id, $3 = expected verdict (PASS/FAIL/INCONCLUSIVE)
  local line
  line="$(printf '%s\n' "$OUT" | grep -E "^[[:space:]]*(PASS|FAIL|INCONCLUSIVE)[[:space:]]+$2:" | head -1)"
  if [ -z "$line" ]; then
    bad "$1" "row '$2' never reported. Output:
$OUT"
    return
  fi
  case "$line" in
    *"$3  $2:"*|*"$3 $2:"*) ok "$1 ($2 = $3)" ;;
    *) bad "$1" "row '$2' expected $3, got: $line" ;;
  esac
}

want_out() { # $1 = label, $2 = grep -E pattern
  if printf '%s\n' "$OUT" | grep -qE "$2"; then ok "$1"
  else bad "$1" "output did not match /$2/. Output:
$OUT"; fi
}

want_not_out() { # $1 = label, $2 = grep -E pattern
  if printf '%s\n' "$OUT" | grep -qE "$2"; then
    bad "$1" "output matched /$2/ and should not have. Output:
$OUT"
  else ok "$1"; fi
}

selected() { case "$1" in *"$FILTER"*) return 0 ;; *) return 1 ;; esac; }

# ── fixtures ────────────────────────────────────────────────────────────────
# Each is a plausible installer, not a keyword salad — the harness reads shell
# text, so a fixture that is not shell proves nothing about a real installer.
#
# NB: `fx name <<'EOF'` at statement level, never `$(fx name <<'EOF' ...)`.
# A heredoc body inside command substitution defeats bash 3.2's parser as soon
# as the body contains an apostrophe, and these bodies are prose-commented, so
# they all do. The paths are assigned below instead.

fx() { # $1 = name; body on stdin
  cat > "$WORK/$1.sh"
}

fx reference <<'EOF'
#!/usr/bin/env bash
# A fully conformant installer: declares, reports, offers, gates, redacts.
set -euo pipefail

INSTALL_PREREQS="${AGENTICAPPS_INSTALL_PREREQS:-0}"
for arg in "$@"; do
  case "$arg" in
    --install-prereqs) INSTALL_PREREQS=1 ;;
    --uninstall) MODE=uninstall ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# Declared prerequisites: npm (runtime, never offered), openspec (offerable).
if ! have npm; then
  echo "missing: npm — required to install openspec. Install Node.js first."
  exit 1
fi

if ! have openspec; then
  echo "missing: openspec — the change gate cannot validate without it."
  CMD="npm install -g @fission-ai/openspec"
  echo "would run: $CMD"
  if [ "$INSTALL_PREREQS" = "1" ]; then
    echo "installing openspec because --install-prereqs was set"
    npm install -g @fission-ai/openspec
  elif [ -t 0 ]; then
    printf 'install it now? [y/N] '
    read -r answer
    case "$answer" in
      y|Y|yes|YES) npm install -g @fission-ai/openspec ;;
      *) echo "skipped: openspec install declined. Run: $CMD"; SKIPPED=1 ;;
    esac
  else
    echo "skipped: no terminal. Run: $CMD, or set AGENTICAPPS_INSTALL_PREREQS=1"
    SKIPPED=1
  fi
fi

mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/openspec-change-gate.sh"
echo "wrote $HOME/.agenticapps/bin/openspec-change-gate.sh"

if [ "${MODE:-install}" = "uninstall" ]; then
  rm -f "$HOME/.agenticapps/bin/openspec-change-gate.sh"
  echo "left installed: openspec. Remove it yourself with: npm rm -g @fission-ai/openspec"
fi

if [ -n "${SKIPPED:-}" ]; then
  echo "completed with skipped steps"
  exit 1
fi
EOF

fx codexish <<'EOF'
#!/usr/bin/env bash
# The real codex-workflow / opencode-workflow shape.
set -euo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
have npm || { echo "npm required"; exit 1; }
have codex || { echo "codex required"; exit 1; }
if ! have openspec; then
  # openspec is the front end's core dependency — auto-install it rather
  # than only instructing.
  npm i -g @fission-ai/openspec
fi
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/openspec-change-gate.sh"
echo "installed into $HOME/.agenticapps/bin"
EOF

fx claudeish <<'EOF'
#!/usr/bin/env bash
# The real claude-workflow / pi shape: detects, instructs, never installs.
set -euo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
if ! have openspec; then
  echo "missing: openspec — the change gate cannot validate without it."
  echo "install it with: npm install -g @fission-ai/openspec"
fi
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/openspec-change-gate.sh"
echo "wrote $HOME/.agenticapps/bin/openspec-change-gate.sh"
EOF

fx ownedonly <<'EOF'
#!/usr/bin/env bash
# Writes only into the workflow's own directory, and says so.
set -euo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
have openspec || echo "missing: openspec — validation will not run."
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/openspec-change-gate.sh"
cp reviewer.sh "$HOME/.agenticapps/bin/reviewer-cli.sh"
echo "wrote $HOME/.agenticapps/bin/openspec-change-gate.sh"
echo "wrote $HOME/.agenticapps/bin/reviewer-cli.sh"
EOF

fx ownedsilent <<'EOF'
#!/usr/bin/env bash
# Same writes, never reported. The exemption without the obligation.
set -euo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
have openspec || echo "missing: openspec — validation will not run."
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/openspec-change-gate.sh"
EOF

fx repolocal <<'EOF'
#!/usr/bin/env bash
# Writes only inside the target repo.
set -euo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
have openspec || echo "missing: openspec — validation will not run. Install: npm i -g @fission-ai/openspec"
TARGET="${1:-.}"
mkdir -p "$TARGET/.claude/skills"
cp -R skills/. "$TARGET/.claude/skills/"
echo "provisioned $TARGET/.claude/skills"
EOF

fx flagonly <<'EOF'
#!/usr/bin/env bash
# Guarded by the opt-in alone, with no prompt. Conformant: the flag IS the
# operator's acceptance, and the non-interactive path reports rather than
# installing.
set -euo pipefail
INSTALL_PREREQS="${AGENTICAPPS_INSTALL_PREREQS:-0}"
case "${1:-}" in --install-prereqs) INSTALL_PREREQS=1 ;; esac
have() { command -v "$1" >/dev/null 2>&1; }
have npm || { echo "npm required — install Node.js"; exit 1; }
if ! have openspec; then
  echo "missing: openspec. would run: npm install -g @fission-ai/openspec"
  if [ "$INSTALL_PREREQS" = "1" ]; then
    npm install -g @fission-ai/openspec
  elif [ -t 0 ]; then
    printf 'install it? [y/N] '; read -r a
    case "$a" in y|yes) npm install -g @fission-ai/openspec ;; *) exit 1 ;; esac
  else
    echo "skipped: set AGENTICAPPS_INSTALL_PREREQS=1 to install unattended"
    exit 1
  fi
fi
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/gate.sh"
echo "wrote $HOME/.agenticapps/bin/gate.sh"
EOF

fx mentionsflag <<'EOF'
#!/usr/bin/env bash
# Names the opt-in in its help text and installs regardless. The absence of
# the flag is being read as acceptance, which is what the row must catch —
# the string being present must not be mistaken for the string guarding
# anything.
set -euo pipefail
usage() { echo "usage: $0 [--install-prereqs]  (env: AGENTICAPPS_INSTALL_PREREQS=1)"; }
have() { command -v "$1" >/dev/null 2>&1; }
have npm || { echo "npm required"; exit 1; }
have openspec || npm install -g @fission-ai/openspec
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/gate.sh"
echo "wrote $HOME/.agenticapps/bin/gate.sh"
EOF

fx unchecked <<'EOF'
#!/usr/bin/env bash
# Invokes npx without ever checking for it. The prerequisite it silently
# depends on is the one it never declares.
set -euo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
have openspec || echo "missing: openspec — validation will not run."
npx some-generator --out .claude
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/gate.sh"
echo "wrote $HOME/.agenticapps/bin/gate.sh"
EOF

fx leaky <<'EOF'
#!/usr/bin/env bash
# Prints the exact command, credential and all, into whatever log is watching.
set -euo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
have npm || { echo "npm required"; exit 1; }
if ! have openspec; then
  echo "would run: npm install -g @fission-ai/openspec --//registry.npmjs.org/:_authToken=npm_s3cr3tt0ken"
  if [ -t 0 ]; then
    printf 'ok? [y/N] '; read -r a
    case "$a" in y|yes) npm install -g @fission-ai/openspec ;; esac
  else
    echo "skipped: set AGENTICAPPS_INSTALL_PREREQS=1 or pass --install-prereqs"
  fi
fi
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/gate.sh"
echo "wrote $HOME/.agenticapps/bin/gate.sh"
EOF

fx remover <<'EOF'
#!/usr/bin/env bash
# Uninstall path takes the prerequisite with it.
set -euo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
have npm || { echo "npm required"; exit 1; }
case "${1:-install}" in
  --uninstall)
    rm -rf "$HOME/.agenticapps/bin"
    npm rm -g @fission-ai/openspec
    echo "removed $HOME/.agenticapps/bin and openspec"
    exit 0
    ;;
esac
have openspec || echo "missing: openspec. Install: npm i -g @fission-ai/openspec"
mkdir -p "$HOME/.agenticapps/bin"
cp gate.sh "$HOME/.agenticapps/bin/gate.sh"
echo "wrote $HOME/.agenticapps/bin/gate.sh"
EOF

fx notaninstaller <<'EOF'
#!/usr/bin/env bash
echo "hello"
EOF

# A command substitution inside a string is CODE, and the quote strip must not
# take it with the string. If it does, the harness cannot see an install
# performed as `out="$(npm install -g pkg)"` — which is the consent row, its
# central job, defeated by a pair of quotes.
fx substituted <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
if ! command -v openspec >/dev/null 2>&1; then
  OUT="$(npm install -g @fission-ai/openspec)"
  echo "$OUT"
fi
mkdir -p "$ROOT/.claude/skills"
echo "provisioned $ROOT/.claude/skills"
EOF

# core's own `install-core-git-hooks.sh` shape: provisions a git hook into a
# resolved destination, checks nothing, installs nothing. It is unmistakably an
# installer, and the first draft of the recognisability screen called it
# UNSCOREABLE because it writes neither ~/.agenticapps/ nor a `.claude/`-shaped
# path. A screen that cannot see core's own installer would have let core ship
# a contract it never scored itself against — the failure this repo has had
# before.
fx hookish <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$(git rev-parse --git-path hooks)"
write_hook() {
  mkdir -p "$HOOKS_DIR" || return 1
  cat > "$HOOKS_DIR/pre-commit" <<'HOOK'
#!/usr/bin/env bash
exec bash tools/gate.sh --ci
HOOK
  chmod +x "$HOOKS_DIR/pre-commit"
}
write_hook || exit 1
printf 'installed: %s\n' "$HOOKS_DIR/pre-commit"
EOF

REFERENCE="$WORK/reference.sh"
CODEXISH="$WORK/codexish.sh"
CLAUDEISH="$WORK/claudeish.sh"
OWNEDONLY="$WORK/ownedonly.sh"
OWNEDSILENT="$WORK/ownedsilent.sh"
REPOLOCAL="$WORK/repolocal.sh"
FLAGONLY="$WORK/flagonly.sh"
MENTIONSFLAG="$WORK/mentionsflag.sh"
UNCHECKED="$WORK/unchecked.sh"
LEAKY="$WORK/leaky.sh"
REMOVER="$WORK/remover.sh"
NOTANINSTALLER="$WORK/notaninstaller.sh"
HOOKISH="$WORK/hookish.sh"
SUBSTITUTED="$WORK/substituted.sh"

echo "═══ installer-prereq-conformance.test.sh"
echo

# ── A. §20 target screening ─────────────────────────────────────────────────
if selected "screening"; then
  echo "── A. target screening (§20)"

  OUT="$("$HARNESS" 2>&1)"; CODE=$?
  want_code "no argument is a usage error" 2

  run "$WORK/nope.sh"
  want_code "absent target aborts" 2
  want_out  "absent target says why" "not found"

  mkdir -p "$WORK/adir.sh"
  run "$WORK/adir.sh"
  want_code "directory target aborts" 2
  want_out  "directory target says why" "not a regular file"

  : > "$WORK/empty.sh"
  run "$WORK/empty.sh"
  want_code "empty target aborts" 2
  want_out  "empty target says why" "empty"

  ln -sf "$WORK/gone.sh" "$WORK/dangling.sh"
  run "$WORK/dangling.sh"
  want_code "dangling symlink aborts" 2
  want_out  "dangling symlink is not reported as not-found" "not a regular file"

  # §20: the executable bit is not tested — targets are read, not executed.
  cp "$REFERENCE" "$WORK/nonexec.sh"; chmod 644 "$WORK/nonexec.sh"
  run "$WORK/nonexec.sh"
  want_code "a readable non-executable target is fully scoreable" 0

  run "$NOTANINSTALLER"
  want_code "an unrecognisable target aborts rather than scoring nothing" 2
  want_out  "and says it could not recognise an installer" "not recognisable as an installer"

  # The other side of that screen, and the one that costs something when it is
  # wrong: a hook installer provisions neither ~/.agenticapps/ nor `.claude/`,
  # and must still be recognised.
  run "$HOOKISH"
  want_not_out "a git-hook installer is recognised as an installer" "not recognisable as an installer"
  want_out     "and its rows are scored"                            "coverage: [1-9][0-9]* of [0-9]+ rows scored"
  echo
fi

# ── B. the conformant reference ─────────────────────────────────────────────
if selected "reference"; then
  echo "── B. the conformant reference installer"

  run "$REFERENCE"
  want_code "reference installer exits clean" 0
  want_not_out "reference installer fails no row" "^[[:space:]]*FAIL"
  want_row "reference: prerequisites declared"  "prereq-detection"           "PASS"
  want_row "reference: installs are guarded"    "consent-guard"              "PASS"
  want_row "reference: non-interactive handled" "non-interactive"            "PASS"
  want_row "reference: opt-in accepted"         "opt-in"                     "PASS"
  want_row "reference: owned writes reported"   "owned-writes-reported"      "PASS"
  want_row "reference: no credential printed"   "redaction"                  "PASS"
  want_row "reference: uninstall leaves it"     "uninstall-preserves-prereqs" "PASS"
  echo
fi

# ── C. the real fleet shapes ────────────────────────────────────────────────
if selected "fleet"; then
  echo "── C. the four shapes actually on disk"

  run "$CODEXISH"
  want_code "codexish is non-conformant" 1
  want_row  "codexish: the unguarded npm i -g is the finding" "consent-guard" "FAIL"
  want_out  "codexish names the command it caught" "npm i -g"
  want_out  "codexish names the line" "line [0-9]+"
  want_row  "codexish: no interactive path either" "non-interactive" "FAIL"
  want_row  "codexish: opt-in absent"              "opt-in"          "FAIL"
  want_row  "codexish: but its prerequisites ARE declared" "prereq-detection" "PASS"
  want_row  "codexish: and its owned write IS reported"    "owned-writes-reported" "PASS"

  run "$CLAUDEISH"
  want_code "claudeish exits clean" 0
  want_row  "claudeish: instructing without installing is conformant" "consent-guard" "PASS"
  want_row  "claudeish: nothing to gate, so not scored" "non-interactive" "INCONCLUSIVE"
  want_row  "claudeish: not required to accept the opt-in" "opt-in" "INCONCLUSIVE"
  want_not_out "claudeish is not reported as violating anything" "^[[:space:]]*FAIL"

  run "$OWNEDONLY"
  want_code "ownedonly exits clean" 0
  want_row  "ownedonly: the owned write needs no consent" "consent-guard" "PASS"
  want_row  "ownedonly: and it is reported"               "owned-writes-reported" "PASS"

  run "$OWNEDSILENT"
  want_code "ownedsilent is non-conformant" 1
  want_row  "ownedsilent: still needs no consent"    "consent-guard" "PASS"
  want_row  "ownedsilent: but the write is unreported" "owned-writes-reported" "FAIL"

  run "$REPOLOCAL"
  want_code "repolocal exits clean" 0
  want_row  "repolocal: repo writes need no prompt" "consent-guard" "PASS"
  echo
fi

# ── D. the opt-in ───────────────────────────────────────────────────────────
if selected "optin"; then
  echo "── D. the opt-in"

  run "$FLAGONLY"
  want_code "flag-guarded installer exits clean" 0
  want_row  "flagonly: the opt-in is a valid guard" "consent-guard" "PASS"
  want_row  "flagonly: both spellings accepted"     "opt-in"        "PASS"

  run "$MENTIONSFLAG"
  want_code "naming the flag is not guarding with it" 1
  want_row  "mentionsflag: the unguarded install is still the finding" "consent-guard" "FAIL"
  echo
fi

# ── E. the remaining rows ───────────────────────────────────────────────────
if selected "rows"; then
  echo "── E. the remaining rows, each failing alone"

  run "$SUBSTITUTED"
  want_code "an install hidden in a command substitution is still found" 1
  want_row  "substituted: the quote strip did not eat the install" "consent-guard" "FAIL"
  want_row  "substituted: and git, invoked only inside \$(), is seen" "prereq-detection" "FAIL"
  want_out  "substituted names git as the undeclared tool" "prereq-detection.*git"

  run "$UNCHECKED"
  want_code "an undeclared prerequisite is non-conformant" 1
  want_row  "unchecked: npx is invoked and never checked" "prereq-detection" "FAIL"
  want_out  "unchecked names the tool"                    "npx"
  want_row  "unchecked: consent row is unaffected"        "consent-guard" "PASS"

  run "$LEAKY"
  want_code "a printed credential is non-conformant" 1
  want_row  "leaky: the token is the finding" "redaction" "FAIL"
  want_not_out "leaky does not echo the secret it caught" "npm_s3cr3tt0ken"
  want_row  "leaky: its install IS guarded"   "consent-guard" "PASS"

  run "$REMOVER"
  want_code "removing the prerequisite is non-conformant" 1
  want_row  "remover: the uninstall row is the finding" "uninstall-preserves-prereqs" "FAIL"
  want_row  "remover: consent row is unaffected"        "consent-guard" "PASS"
  echo
fi

# ── F. §20 reporting obligations ────────────────────────────────────────────
if selected "coverage"; then
  echo "── F. coverage reporting (§20, task 3.6/3.7)"

  run "$REFERENCE"
  want_out "coverage line is emitted on a CLEAN run too" "coverage: [0-9]+ of [0-9]+ rows scored"
  want_out "and it names the inconclusive count"         "[0-9]+ inconclusive"

  run "$CLAUDEISH"
  want_out "coverage line is emitted on a mostly-inconclusive run" "coverage: [0-9]+ of [0-9]+ rows scored"
  # claudeish leaves non-interactive, opt-in and uninstall undecided — it
  # installs nothing and removes nothing, so three of the seven rows have no
  # subject. The scored total must exclude them, or "I could not tell" becomes
  # "I checked". 4 + 3 = 7 is the whole assertion: every row is accounted for,
  # and only four of them are evidence.
  want_out "inconclusive rows are excluded from the scored total" "coverage: 4 of 7 rows scored, 3 inconclusive"

  run "$REFERENCE"
  want_out "the total line names all three counts" "TOTAL: [0-9]+ passed, [0-9]+ failed, [0-9]+ inconclusive"

  # A path is attacker-influenceable; a forged newline must not print a
  # line that reads like a PASS.
  printf '#!/usr/bin/env bash\nhave() { command -v "$1"; }\nhave openspec || echo miss\nmkdir -p "$HOME/.agenticapps/bin"\necho "wrote $HOME/.agenticapps/bin/x"\n' > "$WORK/plain.sh"
  run "$WORK/plain.sh"
  want_code "a minimal but recognisable installer scores" 0
  echo
fi

echo "═══ TOTAL: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
[ "$pass" -gt 0 ] || { echo "scored nothing — that is not a pass"; exit 2; }
