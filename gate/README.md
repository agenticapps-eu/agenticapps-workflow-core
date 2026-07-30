# The AgenticApps change gate (agent-agnostic)

The enforcement teeth for the OpenSpec + Superpowers workflow: **no code edit lands while
an OpenSpec change is active unless `openspec validate --all` is GREEN and every active
change carries `REVIEWS.md` with ≥2 reviewers.** One host-agnostic shell script, wired two
ways — per-agent hooks (fast feedback) + a git/CI backstop (the reliable, agent-agnostic
floor). This is the OpenSpec-era retarget of your ADR-0018 multi-AI plan-review gate.

## Files
| File | What it is |
|---|---|
| `openspec-change-gate.sh` | the gate — `hook` (default), `--pre-commit`, `--ci` modes |
| `run-plan-review.sh` | reviewer wrapper: drives ≥2 agent CLIs → `REVIEWS.md` (with the `codex … </dev/null` + timeout fix) |
| `pre-commit` | git pre-commit hook that calls the gate `--pre-commit` |
| `hooks/openspec-gate.ci.yml` | GitHub Actions workflow running the gate `--ci` |
| `hooks/wiring.md` | how to wire claude / codex / opencode / pi at the same script |

## Install (global once)
```bash
mkdir -p ~/.agenticapps/bin
install -m 0755 gate/openspec-change-gate.sh ~/.agenticapps/bin/
# run-plan-review.sh now ships from reference-implementations/run-plan-review/
```
Per repo: drop in the pre-commit hook + CI workflow (see `hooks/wiring.md`), then add the
per-agent PreToolUse hook for whichever agents that repo uses.

## Contract (what it enforces)
1. **No active change** → allow (incidental edits aren't blocked). Set `OPENSPEC_GATE_STRICT=1`
   for a strict "no code without a change" posture.
2. **Active change present** → `openspec validate --all` must pass, else block.
3. Then each active change must have `REVIEWS.md` with ≥`MIN_REVIEWERS` (default 2) reviewers
   (`## Reviewer:` headings, or a `reviewers:` frontmatter list).
4. Edits to `openspec/**` artifacts are always allowed (you must be able to author the change).
5. `GSD_SKIP_REVIEWS=1` bypasses the review clause (emergency; validate still required).

## Exit codes
- **hook mode:** `0` allow · `2` block (Claude/Codex PreToolUse convention). **Fail-open** —
  any unexpected error allows the edit, so it never bricks a live session.
- **--pre-commit:** `0` allow commit · `1` block. Only blocks when non-`openspec/` files are
  staged while the gate is unsatisfied. **Fail-closed.**
- **--ci:** `0` pass · `1` fail. Whole-repo; every active change must validate + be reviewed.

## Reviewer wrapper
```bash
run-plan-review.sh <change-slug>            # tries gemini, codex, claude, opencode (installed ones)
AGENT_SELF=codex run-plan-review.sh <slug>  # exclude the implementing agent
```
Writes `openspec/changes/<slug>/REVIEWS.md` with one `## Reviewer:` section each. Every CLI is
fed `</dev/null` and a `${REVIEW_TIMEOUT:-180}`s timeout so a hanging reviewer can't stall.

## Test it (local, no repo changes)
```bash
bash gate/openspec-change-gate.sh --ci        # in a repo with openspec/ — prints OK or the blocker
echo '{"tool_input":{"file_path":"src/x.go"}}' | bash gate/openspec-change-gate.sh; echo "exit=$?"
```

## Notes for the host rollout
- opencode + pi hook surfaces are **unconfirmed** — wire them during their host steps; until
  then the pre-commit + CI floor already enforces their edits.
- Keep the script in `~/.agenticapps/bin` (global) so every repo/agent shares one gate; repos
  only carry the thin wiring.
