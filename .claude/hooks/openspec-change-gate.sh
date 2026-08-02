#!/usr/bin/env bash
# Hook — OpenSpec Change Gate (PreToolUse), core's own copy.
#
# This is NOT the shim consuming projects install. Theirs resolves
# ~/.agenticapps/bin/openspec-change-gate.sh — the published copy. Core resolves
# its OWN working-tree reference implementation, which is the exact inverse.
#
# Why the inversion. Core is the source of truth for that file. Gating core with
# the published copy tests whichever host's installer ran last on this machine
# (the issue #32 race) and proves nothing about the bytes core ships. Scoring and
# running the working-tree copy is what makes core's own pull request the
# earliest place gate drift can be detected. See ADR-0028 and docs/WORKFLOW.md.
#
# Fires on PreToolUse matcher: Edit|Write|MultiEdit|NotebookEdit
# Exit 2 = BLOCK; Exit 0 = ALLOW.
#
# LIMITS, because three interposition points are not complete coverage:
#   - The matcher does not see Bash. `sed -i`, `tee` and redirects bypass this
#     hook entirely. CI is what catches those.
#   - A PreToolUse hook is loaded at session start and cannot gate the session
#     that installs it (§18 names this inherent, not a defect).
#   - A missing `openspec` CLI is fail-CLOSED: the gate returns 2 while any
#     change is active. Core almost always has a change open, so without the CLI
#     every non-exempt edit is blocked. That is inherited §18 behaviour, and it
#     is stated here because the gate's fail-open reputation makes it surprising.
#
# Override (emergency, logged):  export GSD_SKIP_REVIEWS=1
# Stricter posture (opt-in):     export OPENSPEC_GATE_STRICT=1

# ROOT MUST NOT come from the working directory. Hooks run in whatever
# directory the session currently has, and that changes during a session — one
# `cd` outside the repo and `git rev-parse` fails, ROOT goes empty, GATE
# resolves to the absolute `/reference-implementations/...`, the not-executable
# branch below fires and the edit proceeds UNGATED with only a warning.
# Reproduced. Silent ungating is the one failure this hook cannot have.
#
# This file's own location is the fixed point: it is always
# <root>/.claude/hooks/, so the root is two levels up regardless of cwd, and
# regardless of whether the host exported anything. CLAUDE_PROJECT_DIR is
# preferred when present because it is what the host says the project is.
SELF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd -P)"
ROOT="${CLAUDE_PROJECT_DIR:-$SELF_ROOT}"
GATE="${OPENSPEC_GATE:-$ROOT/reference-implementations/openspec-change-gate/openspec-change-gate.sh}"

# FAIL OPEN if the gate cannot be located. A hook that hard-fails because
# tooling is absent takes every edit in the session with it, and trains people
# to disable the hook permanently. CI fails CLOSED on the same condition, which
# is where an unanswerable question should be treated as a defect.
if [ ! -x "$GATE" ]; then
  printf 'openspec-gate: WARNING — gate not found at %s; this edit is not gated.\n' "$GATE" >&2
  exit 0
fi

# NO OPENSPEC_GATE_SELF EXPORT. An earlier revision set it here and claimed it
# kept claude's own reviews from counting toward the independence floor. The
# gate has IGNORED that variable since 1.5.0 — it reads the implementing host
# from the REVIEWS.md trailer, because the host that produced the evidence is
# not necessarily the host evaluating it. Exporting it did nothing; the comment
# asserting otherwise was the actual defect, and the gate's own header names
# that hazard by name: the conformance harness once set this in every
# self-exclusion row and those rows passed on an unrelated mechanism.
exec "$GATE"
