#!/usr/bin/env bash
# run-plan-review.sh — drive >=2 other-vendor agent CLIs to adversarially review an
# active OpenSpec change and write changes/<slug>/REVIEWS.md. Retarget of ADR-0018.
#
# Usage: run-plan-review.sh <change-slug> [reviewer1 reviewer2 ...]
#   default reviewers tried (any that are installed, excluding the current session's agent):
#     gemini, codex, claude, opencode
#
# Fixes pilot friction #3: every reviewer CLI is fed </dev/null and time-limited so a
# hanging/prompting CLI can never stall the gate.

set -uo pipefail
SLUG="${1:-}"; shift || true
[ -n "$SLUG" ] || { echo "usage: run-plan-review.sh <change-slug> [reviewers...]" >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CHANGE_DIR="$ROOT/openspec/changes/$SLUG"
[ -d "$CHANGE_DIR" ] || { echo "no such active change: $SLUG" >&2; exit 2; }

TIMEOUT="${REVIEW_TIMEOUT:-180}"                 # seconds per reviewer
SELF="${AGENT_SELF:-}"                            # name of the implementing agent to exclude
REVIEWERS=("$@"); [ ${#REVIEWERS[@]} -gt 0 ] || REVIEWERS=(gemini codex claude opencode)

# Assemble the review prompt from the change artifacts.
read -r -d '' INSTRUCT <<EOF || true
You are an adversarial reviewer. Review this OpenSpec change for correctness, missing
scenarios, wrong assumptions, security/PII issues, and whether the spec delta actually
captures the intent. Reply with a verdict line "VERDICT: APPROVE" or
"VERDICT: REQUEST-CHANGES", then a short bullet list of concrete issues.
EOF
CONTEXT="$(cat "$CHANGE_DIR"/proposal.md "$CHANGE_DIR"/design.md \
             "$CHANGE_DIR"/specs/*/spec.md 2>/dev/null)"
PROMPT="$INSTRUCT

--- CHANGE: $SLUG ---
$CONTEXT"

OUT="$CHANGE_DIR/REVIEWS.md"
: > "$OUT"
count=0
for r in "${REVIEWERS[@]}"; do
  [ "$r" = "$SELF" ] && continue
  command -v "$r" >/dev/null 2>&1 || continue
  echo "· running reviewer: $r" >&2
  case "$r" in
    codex)    resp="$(printf '%s' "$PROMPT" | timeout "$TIMEOUT" codex exec - </dev/null 2>/dev/null || true)" ;;
    gemini)   resp="$(timeout "$TIMEOUT" gemini -p "$PROMPT" </dev/null 2>/dev/null || true)" ;;
    claude)   resp="$(timeout "$TIMEOUT" claude -p "$PROMPT" </dev/null 2>/dev/null || true)" ;;
    opencode) resp="$(timeout "$TIMEOUT" opencode run "$PROMPT" </dev/null 2>/dev/null || true)" ;;
    *)        resp="$(printf '%s' "$PROMPT" | timeout "$TIMEOUT" "$r" </dev/null 2>/dev/null || true)" ;;
  esac
  [ -n "$resp" ] || { echo "  (no output from $r — skipped)" >&2; continue; }
  {
    echo "## Reviewer: $r"
    echo "_generated $(date -u +%Y-%m-%dT%H:%M:%SZ) · timeout ${TIMEOUT}s_"
    echo
    printf '%s\n\n' "$resp"
  } >> "$OUT"
  count=$((count+1))
done

echo "wrote $count reviewer section(s) to ${OUT#"$ROOT"/}" >&2
if [ "$count" -lt "${MIN_REVIEWERS:-2}" ]; then
  echo "WARNING: only $count reviewer(s) available (need ${MIN_REVIEWERS:-2}). Install another agent CLI or use GSD_SKIP_REVIEWS=1 for an emergency." >&2
  exit 1
fi
