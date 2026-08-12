# Session Handoff — 2026-08-12 (thirtieth session)

`trim-stale-fleet-rosters` is **implemented and open as PR #114**, not yet
merged and not yet archived. Branch `chore/trim-stale-fleet-rosters`, three
commits, 22 files, +1053/−1044.

## Accomplished

The two open fleet issues from the last handoff (#5 stale conformance rosters,
#6 `FLEET` naming `agents-task-viewer`), plus three more found on the way.

- **`FLEET` drops `agents-task-viewer`.** `check-shims.sh` had printed
  `MISSING REPO` every run since 2026-08-10; it prints none now.
- **Both conformance rosters trimmed 6 → 2** (`core`, `shared-install`).
  Totals unchanged at 162/0 and 38/0 — the four host repos were already scoring
  nothing, so no coverage was lost.
- **`tools/drift-report.sh` + its test retired.** The third roster, which the
  last handoff did not carry: its `HOSTS` array was exactly the four dead host
  repositories, so it scored `OK: 0 · DRIFT: 0 · SKIP: 60`.
- **Pin-and-resolve withdrawn whole** — the reporting branch, `--resolve`,
  `resolve-core-artifact.sh` and `resolve-core-artifact-conformance.sh`.
- **Prose corrected** in `spec/09`, `spec/20`, `README.md`,
  `reference-implementations/README.md`, `GATE-INVENTORY.md` and the CI
  workflow comment, each reference classified as record-or-instruction first.
- **Step 2b run properly**: gemini and codex, both REQUEST-CHANGES, one finding
  reached independently by both. Step 4: gemini only — codex timed out twice.

## Decisions

- **The resolver is retired here, not deferred.** The first draft kept
  `resolve-core-artifact.sh` published as a Non-goal. Both plan reviewers
  refused that independently: deleting its only harness integration and its
  path-confinement security contract while leaving it published would make a
  future adopter reconstruct the safety rules from an old commit.
- **`vestigial-surface-removal` gets a narrow carve-out rather than being
  ignored.** It exempts `tools/` and every test harness from deletion, which
  forbade three of these retirements — and the proposal had cited that same
  capability as its warrant. A **record** documents what was true; an
  **instrument** measures a subject it declares; one whose declared subject is
  entirely retired does neither. Three conditions, all required, so "nobody runs
  it" does not qualify and neither does an empty roster on an instrument that
  also takes arguments (`check-shims.sh` is the case that protects).
- **`--family` keeps its name; what it claims is corrected.** Renaming churns
  every caller. Two entries measure *publish drift* — shipped bytes against
  installed bytes — and the harnesses now say so in their own comments.
- **One proposed assertion was dropped for being vacuous.** Asserting that
  output lacks the resolvable-but-not-attempted string would have passed before
  the change too, since no host directory holds a resolver. The delta argues
  against exactly that shape for J3 and the task had then proposed it.
- **Archiving is a separate PR after merge**, matching `#107 → #108`.

## Files modified

`reference-implementations/project-hooks/FLEET` (one name out, tombstone in) ·
`tools/change-gate-conformance.sh` (roster, `--resolve`, pin branch) ·
`tools/reviewer-cli-conformance.sh` (roster, pin probe, orphaned `root`) ·
`tools/conformance-harness-reporting.test.sh` (J3 out, K + L in, harness list) ·
`spec/09-conformance.md` (`## Drift` rewritten) ·
`spec/20-conformance-harness-reporting.md` (pin rules + out-of-scope withdrawn) ·
`README.md` · `reference-implementations/README.md` · `GATE-INVENTORY.md` ·
`.github/workflows/openspec-gate.yml` · `CHANGELOG.md` ·
`openspec/changes/trim-stale-fleet-rosters/**` (proposal, tasks, REVIEWS, three
spec deltas).
**Deleted:** `tools/drift-report.sh`, `tools/drift-report.test.sh`,
`tools/resolve-core-artifact-conformance.sh`,
`reference-implementations/shared-install/resolve-core-artifact.sh`.

## Next session: start here

**Merge PR #114, then archive in its own PR.** The delta touches three
capabilities — `conformance-harness-reporting` (one REMOVED, one MODIFIED, one
ADDED), `vestigial-surface-removal` (two MODIFIED) and `change-gate-enforcement`
(one MODIFIED) — so the archive is the largest fold this repo has done. Check
the MODIFIED blocks are supersets before assuming `openspec archive` takes them
on the first attempt.

## Open questions

1. **Step 4 had one reviewer, not two.** codex timed out at 300s and again at
   550s on a 1,503-line diff prompt, having reviewed the same change's *plan*
   fine at 2b. Worth establishing whether `reviewer-cli.sh` needs a larger
   default `REVIEWER_TIMEOUT` for diff-sized prompts, or whether diffs should be
   chunked. Recorded in `REVIEWS.md` under *Not counted*.
2. **`tools/drift-report.test.sh` was deleted with its tool, and it was this
   repo's first test of any kind** (ADR-0019). Nothing is lost that the archive
   does not hold, but the ADR still describes it in the present tense. ADRs are
   append-only, so correcting it means a new ADR — worth one for the
   record/instrument distinction anyway, which currently lives only in a spec
   delta.
3. Carried over and unchanged: the `openspec-change-review` skill and the gate
   still disagree about `REVIEWS.md` (skill documents YAML frontmatter, gate
   parses a trailer only `run-plan-review.sh` emits, so every hand-written file
   is `trailer-absent`); `GLOBAL_FLOOR_BIND_BIN=/usr/bin/true` still does not
   reach the end of `global-floor-bind.test.sh`; `workflow-installation` still
   says a reporting surface "is owed"; AGE-510, AGE-509, no interception of
   destructive SQL, `normalize-claude-md` has no implementation, the installer
   has no retired-artifact sweep.
