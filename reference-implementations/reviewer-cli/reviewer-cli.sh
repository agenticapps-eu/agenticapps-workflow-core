#!/usr/bin/env bash
# reviewer-cli-version: 1.2.0
#
# VERSION MARKER — read by every host installer before writing this file to the
# SHARED path ~/.agenticapps/bin/. That path is written by claude / codex /
# opencode / pi installers alike, so without arbitration it is last-writer-wins:
# a host still vendoring an older copy silently republishes it over a newer one
# and drops capability for every agent on the machine. Installers MUST refuse to
# overwrite a higher version (treat an unmarked file as 0.0.0). Bump this
# whenever behaviour changes.
#
# This is not hypothetical. Before 1.0.0 there was no marker and nobody
# arbitrated: a host installer delivered the correctly-arbitrated 1.2.2 change
# gate and, in the same run, blind-installed a 3-arm reviewer-cli over a 4-arm
# one. The `opencode` arm vanished and the next review that asked for it got
# `unknown vendor` mid-run. Core#41.
#   1.0.0 — first published canonical. Merges the three divergent host copies:
#           pi's structure (stdin pinned inside run_bounded, explicit usage
#           checks, unbounded-run warning) with codex's coverage (four vendor
#           arms and the opencode model-provenance note).
#   1.1.0 — split the single `exit 3` into 3 unavailable / 4 timed out /
#           5 unknown vendor. A live opencode that timed out was being reported
#           to the operator as "unavailable", sending them to check PATH for a
#           CLI that was present and working.
#
# reviewer-cli.sh — defensive wrapper for an external-vendor reviewer CLI (§18).
#
# The §18 change-gate requires the active change to carry independent multi-AI
# review (>= 1 counted external vendor; 2 preferred) in REVIEWS.md before any code edit.
# The review *producer* — each host's `openspec-change-review` skill — calls
# this wrapper once per vendor to run the actual CLI.
#
# This wrapper exists because of cParX pilot friction #3: `codex exec "<prompt>"`
# reads stdin and HANGS without `</dev/null` (a 4-minute stall on first attempt).
# A hanging reviewer must never be able to stall an edit indefinitely, so every
# reviewer invocation here is:
#   - fed `</dev/null` on stdin, and
#   - bounded by a hard wall-clock `timeout`.
#
# Usage:
#   reviewer-cli.sh <vendor> <prompt-file>
#     <vendor>       claude | gemini | opencode | codex
#                    (>= 1 counted vendor required by §18; 2 preferred)
#     <prompt-file>  path to a file holding the full review prompt
#
# Env:
#   REVIEWER_TIMEOUT   hard wall-clock cap in seconds (default 300)
#
# Output: the reviewer's raw verdict text on stdout. NOTE the producer must not
#         assume this is review prose only — vendor CLIs print banners and
#         session-hook logs to stdout, and that chatter reaches the producer
#         inline with the review. Sanitising it is the PRODUCER's job (it knows
#         the artifact format); this wrapper stays vendor-dispatch-only.
# Exit:   0 on a completed review; 3 unavailable (CLI absent / usage error);
#         4 timed out; 5 unknown vendor; otherwise the vendor CLI's own code.
#         The producer MUST treat ANY non-zero as "not counted" and say so in
#         REVIEWS.md — it must NEVER be silently counted as a passing reviewer,
#         because that would let one reachable vendor satisfy a rule whose whole
#         purpose is two independent ones. It SHOULD distinguish 3/4/5 in what it
#         tells the operator: they have different fixes.
#
# VENDOR EXCLUSION IS THE PRODUCER'S JOB, NOT THE WRAPPER'S. A host must never
# review its own change, but the arm for a host's own vendor still ships here:
# this file is installed at ONE global path shared by every host, so the codex
# arm exists for the sibling hosts that call it, and so on. Removing an arm
# because "this host would never use it" is what caused core#41 — the wrapper is
# fleet-wide, the exclusion is per-producer.
#
# PROMPT DELIVERY: the prompt is passed as an ARGUMENT, never on stdin, because
# stdin is pinned to /dev/null by the hardening above. Very large prompts are
# bounded by ARG_MAX; a bundle that exceeds it must be trimmed by the producer.

set -u

vendor="${1:-}"
prompt_file="${2:-}"
TIMEOUT="${REVIEWER_TIMEOUT:-300}"

# EXIT CODES — distinct per failure kind, because the producer reports them to a
# human who has to act on the difference.
#
#   3  unavailable    — CLI not on PATH, or the wrapper was called wrong
#   4  timed out      — the vendor was reachable and ran, but exceeded TIMEOUT
#   5  unknown vendor — not one of claude | gemini | opencode | codex
#
# Before 1.1.0 all three were `exit 3` and the producer printed one string,
# "reviewer unavailable". A live `opencode` that timed out at the default bound
# was therefore reported as absent; the operator checked PATH, found the CLI
# present and working, and the actionable signal (raise REVIEWER_TIMEOUT) was
# gone. Not counting a failed reviewer is correct; misdiagnosing WHY is not.
#
# Keep 3 as the unavailable code so an installer mid-fleet-upgrade that still
# reads "non-zero means don't count" is unaffected — every code here is non-zero
# and none may ever be 0.
die()         { printf 'reviewer-cli: %s\n' "$*" >&2; exit 3; }
die_timeout() { printf 'reviewer-cli: %s\n' "$*" >&2; exit 4; }
die_vendor()  { printf 'reviewer-cli: %s\n' "$*" >&2; exit 5; }

# Both arguments are checked explicitly. Letting an empty prompt_file fall
# through to `[ -f "" ]` reports `prompt file not found: ` with nothing after the
# colon, which reads like a corrupted path rather than a missing argument.
[ -n "$vendor" ] || die "usage: reviewer-cli.sh <vendor> <prompt-file>"
[ -n "$prompt_file" ] || die "usage: reviewer-cli.sh <vendor> <prompt-file>"
[ -f "$prompt_file" ] || die "prompt file not found: $prompt_file"

# Resolve a `timeout` binary. macOS ships neither by default; coreutils installs
# `gtimeout`. If neither exists we still run (unbounded) rather than refuse —
# but we say so, because an unbounded reviewer is the exact failure this wraps.
TIMEOUT_BIN=""
if   command -v timeout  >/dev/null 2>&1; then TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout"
else
  printf 'reviewer-cli: WARNING no timeout(1)/gtimeout(1) on PATH — running %s unbounded.\n' "$vendor" >&2
  printf 'reviewer-cli:   install coreutils (brew install coreutils) to bound reviewer CLIs.\n' >&2
fi

# stdin is bound HERE, in one place, covering both branches — not at each call
# site. Repeating the redirect per arm is one forgotten redirect away from
# reintroducing the hang this wrapper exists to prevent, and the omission is
# invisible until that specific vendor is next called.
#
# THE PROMPT IS NEVER AN ARGUMENT. Every arm previously passed the full prompt
# as argv — `claude -p "$prompt"`, `codex exec "$prompt"` — which put the entire
# change (proposal, design note and every spec delta) in the process table,
# readable by any local user for as long as the reviewer ran. The producer had
# always passed a file; the exposure was entirely here.
#
# stdin, not /dev/null, is now the delivery channel, and the never-blocks
# property is preserved for the same reason it held before: the wrapper always
# redirects stdin from something that reaches EOF. A regular file EOFs exactly
# like /dev/null does. Pilot friction #3 — `codex exec` hanging — was an empty
# TTY, not an inability to read stdin; `codex exec --help` documents that
# instructions are read from stdin when no PROMPT argument is given.
# A short, fixed instruction for arms that need a prompt argument to select
# non-interactive mode. It is a constant carrying no change content, so it is
# safe in argv — and it refers to the change POSITIONALLY, never by channel
# name, because a vendor told its input is "on stdin" may try to open that as a
# file instead of reading what it was already given.
HEADLESS_HINT="Follow the review instructions given above."

run_bounded() {   # stdin arrives already redirected by the caller
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$TIMEOUT" "$@"
  else
    "$@"
  fi
}


case "$vendor" in
  claude)
    command -v claude >/dev/null 2>&1 || die "claude CLI not found on PATH"
    # See HEADLESS_HINT: these arms deliver on stdin.
    # `-p/--print` selects non-interactive; the prompt itself arrives on stdin.
    run_bounded claude -p < "$prompt_file"
    ;;
  gemini)
    command -v gemini >/dev/null 2>&1 || die "gemini CLI not found on PATH"
    # `-p` selects headless mode and its value is appended to stdin, so the
    # change arrives on stdin and only the fixed hint is in argv.
    #
    # THE HINT'S WORDING IS LOAD-BEARING, which cost two smoke tests to learn.
    # An earlier hint said the change was "supplied on stdin"; gemini — an
    # agentic CLI, not a text filter — read that as an instruction to go and
    # open something called stdin, replied "I cannot directly read from
    # `stdin`", and reviewed nothing. The content had been there all along.
    # Referring to it positionally ("above") rather than by channel name works.
    #
    # `@<path>` was tried as the alternative and is not viable: gemini refuses
    # paths outside the workspace, and the producer writes its prompt to
    # $TMPDIR. It appeared to work only because the first smoke test ran from
    # /tmp with the file in /tmp.
    run_bounded gemini -p "$HEADLESS_HINT" < "$prompt_file"
    ;;
  opencode)
    command -v opencode >/dev/null 2>&1 || die "opencode CLI not found on PATH"
    # `opencode` is a client, not a provider — the producer records the MODEL it
    # resolved to (e.g. glm-5.2), not just the CLI name, so "distinct vendor" is
    # judged on the model behind the client. Without this, two arms pointed at
    # the same underlying model would count as two independent reviewers and
    # §18's threshold would be satisfied by one opinion wearing two names.
    # stdin. `--file` was tried first and is wrong twice over: it is an ARRAY
    # option, so it greedily consumed the message positional as a second
    # filename ("Error: File not found: <message>"), and even correctly formed
    # it returned no review. Smoke-tested: `opencode run < file` answers.
    run_bounded opencode run < "$prompt_file"
    ;;
  codex)
    command -v codex >/dev/null 2>&1 || die "codex CLI not found on PATH"
    # `codex exec` with no PROMPT argument reads instructions from stdin —
    # documented in `codex exec --help`. Friction #3 was an empty TTY, not an
    # inability to read stdin: a regular file EOFs and the hang does not recur.
    run_bounded codex exec < "$prompt_file"
    ;;
  *)
    die_vendor "unknown vendor '$vendor' (expected: claude | gemini | opencode | codex)"
    ;;
esac
rc=$?

# `timeout(1)` returns 124 on expiry. Map it to the dedicated timeout code and
# name the bound that was exceeded — the producer surfaces this verbatim, and
# "after 180s" is what tells the operator to raise REVIEWER_TIMEOUT rather than
# go hunting for a missing binary.
[ "$rc" -eq 124 ] && die_timeout "$vendor timed out after ${TIMEOUT}s"
exit "$rc"
