# Session Handoff — 2026-08-05

## Accomplished

**PR #78 is open: the executable migration format.** Core spec §08 gains a
machine-runnable form; spec 1.5.0 → 2.0.0. 34 commits, 567 assertions, all
suites green.

Migration steps keep their prose `**Label:**` headings and gain `role=` tags on
executable fences, so a bash runner applies a migration with no agent, no API
key and no Node. Ships `reference-implementations/migration-runner/` (extract,
lint, run, THRESHOLDS, README), a ten-rule linter plus five whole-document
checks, 60 fixtures, and a CI step.

The OpenSpec change is archived as `2026-08-05-executable-migration-format`
with three other-vendor reviewers recorded in `REVIEWS.md` before any code.

## Decisions

- **The format is greenfield; retrofit scope is zero.** Every one of the 73
  existing migrations sits below its host's threshold, and fresh setup snapshots
  rather than replays (ADR-0036), so none ever needs to run again. This was the
  session's largest simplification and it came from Donald asking whether cparx
  could just be migrated — investigation showed it was already current and its
  two lagging stamps are vestigial (`.codex/` never committed, `.opencode/` has
  no skills). **Those two stale 0.5.0 stamps in `factiv/cparx` are still there**
  and are the only thing in the fleet that makes historic migrations look live.
- **No npm package, no TUI.** Donald killed `@agenticapps/workflow` in favour of
  a bash installer fetched by curl. The runner is bash for the same reason:
  migrations stay runnable on a machine without Node.
- **Unattended failure aborts and rolls back nothing** (A2). Absence of anyone
  to ask is not consent, and a half-applied tree is evidence an auto-rollback
  destroys.
- **The linter keys on the filename ID, cross-checked against frontmatter** (B3),
  because a filename cannot be forgotten.
- **`apply-agent` and `answers:` frontmatter dropped** — both lost their only
  users when the format went greenfield.
- **Review stopped by Donald's instruction** ("no no reviews anymore") after two
  spec rounds, not because the list was empty. Four findings were recorded as
  known gaps at that point.

## Files modified

- `spec/08-migration-format.md` — 231 → 540 lines, spec_version 2.0.0
- `spec/00-overview.md`, `CHANGELOG.md` — 2.0.0 entry and narrative
- `reference-implementations/migration-runner/` — new: 3 scripts, THRESHOLDS, README, 60 fixtures
- `tools/migration-runner.test.sh` — new, 567 assertions
- `.github/workflows/openspec-gate.yml` — new test step
- `openspec/specs/executable-migration-format/` — 21 requirements, folded on archive

## Next session: start here

**Review and merge PR #78.** Nothing is blocked on it. If CI is red, the most
likely cause is the new test step — it needs no special checkout (the
git-history-dependent assertions were deleted precisely so it wouldn't).

The natural next piece is **the bash installer** — the brief's Part 2, now much
smaller than originally scoped: one curl-able script generalising the four
hosts' `install.sh` (1,544 lines total), with detect-then-ask multi-select host
detection. The Docker smoke run (Part 3) follows it. Neither was started.

## Open questions

- **Three of this session's defects were mine and all propagated unchallenged:**
  I got the spec version scheme wrong (section stamps carry the whole-spec
  version, not a per-section counter) and it went through the design note, plan
  and task list; I made the same awk fence-ordering error three separate times;
  and I relayed a fabricated "6 of 73" fleet statistic from one reviewer into a
  fix prompt as fact, where it was written into five files as a rule's
  justification before anyone measured it (the true figure is 0 of 73). Each was
  caught by a different reader. Worth remembering that a confident number from a
  review is not a measured one.
- **The linter can prove a migration body is inert but not that it does
  anything** — `true; true` passes. Undecidable; documented as a limit.
- **No test covers the `[ -t 0 ]` terminal-detection path.** A reviewer proved
  the code correct by driving a real pty; the suite doesn't.
- **`grep -q` as an idempotency check exits 2 on a not-yet-existing file** and
  aborts. Spec-correct, undocumented, one paragraph to fix.
- `.planning/skill-observations/*` is *still* being written into these repos
  despite the global rule that `.planning/` is frozen. Unchanged from the
  previous handoff; worth finding the writer or gitignoring it.
