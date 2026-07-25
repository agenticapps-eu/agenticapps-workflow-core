#!/usr/bin/env bash
# openspec-change-gate.sh — the AgenticApps enforcement gate (host-agnostic).
#
# THE REFERENCE IMPLEMENTATION of spec/18-retargeted-change-gate.md. Hosts
# vendor this file rather than maintaining their own copy; divergence between
# host copies is what issue #32 documented and this file exists to end.
# Conformance is executable: tools/change-gate-conformance.sh scores any copy
# against §18's truth table. Change behaviour here only with a matching row.
#
# Rule: you may not edit code while an OpenSpec change is active unless
#   (1) `openspec validate --all` is GREEN, and
#   (2) every active change carries REVIEWS.md with >= MIN_REVIEWERS
#       independent reviewers.
# This is the OpenSpec-era retarget of the ADR-0018 multi-AI plan-review gate.
#
# Three modes:
#   (default)      HOOK mode — reads a tool-call payload on stdin, decides for ONE edit.
#                  Exit 0 = allow, Exit 2 = block. FAIL-OPEN on a parse error.
#   --pre-commit   Staged-aware — blocks a commit only if it stages non-openspec files while
#                  the gate is unsatisfied. Exit 0 = allow commit, Exit 1 = block. FAIL-CLOSED.
#   --ci           Whole-repo — every active change must validate + have reviews. Exit 0/1.
#
# The per-agent hook is only fast feedback: a PreToolUse hook is loaded at session
# start and cannot gate the session that installed it (§18). The --pre-commit and
# --ci modes are the agent-agnostic enforcement floor — they catch edits from any
# agent, or a human, including that installing session. A hook-only build of this
# gate is not conformant to §18's "real enforcement surface" clause.
#
# Env:
#   GSD_SKIP_REVIEWS=1     bypass the review requirement (emergency escape; still needs validate).
#   OPENSPEC_GATE_STRICT=1 also block edits when there is NO active change ("no code without a change").
#   MIN_REVIEWERS=2        override the reviewer threshold.
#   OPENSPEC_BIN=openspec  override the openspec CLI name/path.
#   OPENSPEC_GATE_SELF     name of the implementing host; its own reviews do not count.
#
# Exit codes follow the Claude Code PreToolUse convention (2 = block) in hook mode.

set -uo pipefail
MIN_REVIEWERS="${MIN_REVIEWERS:-2}"
# Indirect the CLI so the conformance harness can stub `validate` and assert THIS
# script's logic hermetically, rather than testing OpenSpec. §18 requires the gate
# be "demonstrable by direct script invocation with simulated payloads"; a
# hardcoded binary makes the block/allow rows untestable without a real, populated
# OpenSpec repo — i.e. makes the contract unverifiable as written.
OPENSPEC_BIN="${OPENSPEC_BIN:-openspec}"
MODE="hook"
case "${1:-}" in
  --ci)         MODE="ci" ;;
  --pre-commit) MODE="pre-commit" ;;
esac

log(){ printf 'openspec-gate: %s\n' "$*" >&2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CHANGES_DIR="$ROOT/openspec/changes"

# --- helpers ---------------------------------------------------------------

active_changes(){                      # print each active (non-archived) change dir, one per line
  [ -d "$CHANGES_DIR" ] || return 0
  find "$CHANGES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name archive 2>/dev/null | sort
}

# Count INDEPENDENT reviewers in REVIEWS.md. Three properties matter, and a
# plain `grep -c` on the heading has none of them:
#
#   1. Fenced code blocks are skipped. A REVIEWS.md that shows reviewers the
#      heading format to copy would otherwise count its own template as a
#      reviewer — the file that documents the gate defeats it.
#   2. Names are deduplicated. Two "## Reviewer: claude" headings are one
#      reviewer with two comments, not the independent second opinion §07
#      requires. Counting lines lets one reviewer satisfy the threshold alone.
#   3. Self-review is excluded when OPENSPEC_GATE_SELF names the implementing
#      host. Without it the gate and the §02 evidence verifier DISAGREE about
#      who counts, and a gate that disagrees with its own verifier is the
#      ADR-0018 drift pattern reappearing inside the tooling. Anchored
#      (^self([-_ ].*)?$) so a reviewer whose name merely starts with the same
#      letters is not swallowed. Unset => no exclusion.
#
# OPENSPEC_GATE_SELF is interpolated into an awk regex, so a host name carrying
# regex metacharacters would not anchor as written. Host names are bare tokens
# (pi, claude, codex, opencode); this is a documented constraint, not a guard.
reviewer_count(){                      # $1 = change dir ; echo number of DISTINCT reviewers
  local f="$1/REVIEWS.md" n=0
  [ -f "$f" ] || { echo 0; return; }
  n=$(awk -v self="${OPENSPEC_GATE_SELF:-}" '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    /^##[[:space:]]*[Rr]eviewer[[:space:]]*:?[[:space:]]*[^[:space:]]/ {
      name = $0
      sub(/^##[[:space:]]*[Rr]eviewer[[:space:]]*:?[[:space:]]*/, "", name)
      sub(/[[:space:]]+$/, "", name)
      name = tolower(name)
      if (self != "" && name ~ ("^" tolower(self) "([-_ ].*)?$")) next
      seen[name] = 1
    }
    END { c = 0; for (k in seen) c++; print c }
  ' "$f" 2>/dev/null || echo 0)
  n="${n:-0}"
  if [ "$n" -lt "$MIN_REVIEWERS" ]; then
    # fallback: YAML frontmatter `reviewers: [a, b]` or a `- ` list under `reviewers:`
    local fm
    fm=$(awk '
      /^reviewers:[[:space:]]*\[/ { g=gsub(/,/,","); print g+1; found=1; exit }
      /^reviewers:[[:space:]]*$/  { inlist=1; next }
      inlist && /^[[:space:]]*-[[:space:]]/ { c++; next }
      inlist && /^[^[:space:]-]/ { inlist=0 }
      END { if(!found && c>0) print c }' "$f" 2>/dev/null || true)
    [ -n "${fm:-}" ] && [ "${fm:-0}" -gt "$n" ] && n="$fm"
  fi
  echo "${n:-0}"
}

validate_ok(){ ( cd "$ROOT" && "$OPENSPEC_BIN" validate --all >/dev/null 2>&1 ); }

# Core check. Returns: 0 = satisfied, 2 = blocked. Never errors out.
gate_check(){
  local changes; changes="$(active_changes)"
  if [ -z "$changes" ]; then
    if [ "${OPENSPEC_GATE_STRICT:-0}" = "1" ]; then log "no active change (strict mode) — blocked"; return 2; fi
    return 0                                   # permissive default: incidental edits are fine
  fi
  if ! command -v "$OPENSPEC_BIN" >/dev/null 2>&1; then
    log "openspec CLI not found — cannot verify; run 'npm i -g @fission-ai/openspec'"; return 2
  fi
  if ! validate_ok; then log "openspec validate --all FAILED — fix the spec delta first"; return 2; fi
  if [ "${GSD_SKIP_REVIEWS:-0}" = "1" ]; then log "GSD_SKIP_REVIEWS=1 — review requirement bypassed"; return 0; fi
  # EVERY active change must be reviewed, not merely the first one found. Stopping
  # at the first change lets directory order decide the verdict: with one reviewed
  # and one unreviewed change open, the gate would allow or block depending on
  # which sorts first.
  local blocked=0 d n
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    n="$(reviewer_count "$d")"
    if [ "$n" -lt "$MIN_REVIEWERS" ]; then
      log "change '${d#"$ROOT"/}' has $n/$MIN_REVIEWERS reviewers — run plan-review to write REVIEWS.md"
      blocked=1
    fi
  done <<< "$changes"
  [ "$blocked" -eq 0 ] && return 0 || return 2
}

# --- edit-path extraction (hook mode) --------------------------------------

# Every host runtime wraps the same two facts (tool name, target path) in its own
# envelope. A key this function does not know about yields an empty path, which
# fails OPEN below — i.e. the gate silently stops enforcing on that host. Adding a
# host means adding its key here AND a payload-shape row to the conformance
# harness; the harness drives a *code* edit precisely because an artifact write
# passes under fail-open whether or not the parser ran.
#
#   .tool_input.file_path / .tool_input.path / .tool_input.notebook_path
#                                    — Claude Code PreToolUse
#   .params.file_path                — generic JSON-RPC shape
#   .input.file_path / .input.path   — pi `tool_call` ({toolName, input:{path}};
#                                      verified against pi-coding-agent 0.80.10
#                                      editSchema/writeSchema)
#   .args.filePath / .args.path / .args.file
#                                    — opencode `tool.execute.before`
#   .file_path / .path               — bare fallback
edited_path_from_stdin(){
  local payload; payload="$(cat 2>/dev/null || true)"
  [ -n "$payload" ] || { echo ""; return; }
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r '
      (.tool_input.file_path // .tool_input.path // .tool_input.notebook_path //
       .params.file_path //
       .input.file_path // .input.path //
       .args.filePath // .args.path // .args.file //
       .file_path // .path // empty)' 2>/dev/null | head -n1
  else
    printf '%s' "$payload" | grep -oE '"(file_?[pP]ath|path|file)"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | head -n1 | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/'
  fi
}

is_openspec_artifact(){                # edits to the change itself must always be allowed
  case "$1" in
    */openspec/*|openspec/*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- modes -----------------------------------------------------------------

case "$MODE" in
  hook)
    path="$(edited_path_from_stdin || true)"

    # Fail OPEN when no path could be parsed. §18: "Malformed / unparseable
    # stdin -> allow (fail-open) -> 0". Falling through to gate_check here turns
    # a payload-shape mismatch into a hard block on every edit, indistinguishable
    # from a real policy block — and because the artifact exemption below never
    # fires either, it blocks the write of proposal.md itself: the change can
    # then never be authored, never reviewed, never unblocked. That is not a
    # strict gate, it is a gate that cannot be satisfied.
    #
    # Failing open on a PARSE error is deliberate. Failing open on POLICY (a
    # missing review) is non-conformant and is NOT what this does.
    if [ -z "$path" ]; then
      log "ALLOW (fail-open: no target path parsed from stdin)"
      exit 0
    fi

    if is_openspec_artifact "$path"; then exit 0; fi
    if gate_check; then exit 0; else
      log "BLOCKED — no code edits until validate is GREEN and every active change has >= $MIN_REVIEWERS reviewers."
      exit 2
    fi
    ;;

  pre-commit)
    # Only block if the commit stages non-openspec files while the gate is unsatisfied.
    staged="$(git diff --cached --name-only 2>/dev/null || true)"
    non_spec="$(printf '%s\n' "$staged" | grep -vE '(^|/)openspec/' | grep -v '^$' || true)"
    if [ -z "$non_spec" ]; then exit 0; fi          # only spec artifacts staged -> fine
    if gate_check; then exit 0; else
      log "commit BLOCKED — you are committing code while the change gate is unsatisfied."
      exit 1
    fi
    ;;

  ci)
    if gate_check; then log "OK — all active changes validate and are reviewed."; exit 0; else exit 1; fi
    ;;
esac
