# Session Handoff — 2026-08-04 (eighth session of the day)

## Accomplished

**The conformance instrument is retired.** PR #77 opened, all suites green.

The session began as task 6.1 — the Stage-2 review of
`instrument-counts-what-it-names` — and ended by deleting the thing under review.

1. **The review ran and found a real regression (F1).** The change's new
   classifier reads shell assignment syntax, while the corpus deliberately
   includes `Makefile`, `*.mk`, `justfile` and `Taskfile.yml`. Four files each
   setting the override, all reported `OK — no known vector found`. Confirmed by
   execution, not by reading. Also F3: one unparseable settings file reported as
   "5 settings file(s)", because the counter incremented per (hook, variable,
   file). Full review at
   `openspec/changes/instrument-counts-what-it-names/CODE-REVIEW.md` on that
   branch.
2. **Donald asked what problem any of this was solving.** The answer, from the
   history rather than from memory: the migration he asked for — hooks published
   once, bound through shims — shipped 2026-08-02 (PR #61). Everything in the six
   days since has been repairs to the instrument built alongside it, each found
   by reading the previous repair's output. 1,962 lines of instrument against the
   320 it measured; six of eight archived changes were self-repairs.
3. **He chose to shrink it.** `tools/project-hook-conformance.sh` and its
   1,000-line suite deleted; `tools/check-shims.sh` (96 lines) replaces them.
   Two requirements removed from `project-hook-binding`, one modified to stop
   mandating the scan. Change archived as
   `2026-08-04-retire-the-conformance-instrument`.

## Decisions

- **The instrument was never requested.** It came from a task inside PR #61's own
  plan ("a version marker with no check makes nothing detectable"). Recorded in
  the proposal because the same reasoning will regenerate it otherwise.
- **Core is in `check-shims.sh`'s target list, not excluded from it.** That is
  what discharges the removed "authority's own binder is scored" requirement —
  the tool's shape rather than prose.
- **`MATCHERS` is deleted, and so is the check its requirement mandated.** Keeping
  it was the one decision Donald pushed back on, and he was right: it had been
  kept, not needed. Checking turned up worse — "Registration matches the
  implementation's tool coverage" still required "a conformance tool SHALL
  evaluate every declared hook in every scanned project", with no tool left to do
  it. The first change removed two requirements specifying the deleted
  instrument and missed this third. Fixed in
  `2026-08-04-retire-the-matcher-check`: the three matcher sets moved into the
  requirement as a table, the file deleted, the mandate withdrawn with its cost
  stated, five scenarios reworded from what a check reports into what is true of
  the project. Reinstatement is conditioned — a check inside an existing script,
  never a capability of its own.
- **`OPT-OUTS` is kept**, read by `check-shims.sh` in three lines. Core's two
  rows were ported from the abandoned branch; ADR-0030 (94 lines arguing them)
  was not. `OPT-OUTS`' header was amended so a self-contained row is sufficient
  and an ADR is not compulsory — requiring one for a one-sentence fact is what
  produced the 94 lines.
- **What is lost is stated, not argued away:** nothing now detects a project
  setting an override variable in its own files. That scan ran seven times, found
  nothing, and never covered the operator's own shell.
- **`feat/instrument-counts-what-it-names` is deleted** (was `bd77916`,
  recoverable from the reflog for ~90 days). It was never pushed, so "preserved"
  had meant "on one laptop"; and after #77 merges it could not have been merged
  anyway — it modifies two files `main` no longer has, and resolving that in its
  favour would resurrect the instrument. Donald called it: we don't need it.
- **Untouched deliberately:** `tools/provisioning-check.sh` and its four
  requirements (a different question — is *this machine* provisioned), and
  `openspec/specs/conformance-harness-reporting/` (governs the harnesses that
  measure *host* implementations).

## Files modified

- `tools/project-hook-conformance.sh`, `tools/project-hook-conformance.test.sh` — **deleted**
- `tools/check-shims.sh` — new, 96 lines, with a header arguing against its own growth
- `openspec/specs/project-hook-binding/spec.md` — 1,961 → 1,898 lines via the archived delta
- `reference-implementations/project-hooks/MATCHERS` — **deleted**, its three rows now a table in the requirement
- `reference-implementations/project-hooks/{OPT-OUTS,FLEET,SHIMMED-HOOKS,README.md}` — core's two opt-out rows; comments corrected where they described what runs
- `tools/lib/semver.sh`, `tools/provisioning-check.sh` — comment corrections (one caller now, not two)

## Next session: start here

**Merge PR #77, then stop.** The migration is done, the check is 96 lines, and
the loop is closed by deletion rather than by intention.

If `check-shims.sh` ever reports something, **fix the shim it names — not the
script.** That sentence is task 4.4 of the archived change and it is the whole
point of this session. Do not open a change against `check-shims.sh`. Do not add
an axis to it. Do not rebuild the matcher check, the override scan, or the
checkout provenance report; if one of them seems necessary, the argument to beat
is in
`openspec/changes/archive/2026-08-04-retire-the-conformance-instrument/proposal.md`.

The real backlog, if work is wanted: `agenticapps-dashboard` is on a branch with
no upstream, and two local merge commits sit unpushed on `main` in `callbot` and
`fbc-platform`. Those are actual repository states, not instrument output.

## Open questions

- **Something is still writing `.planning/skill-observations/*`** into these
  repositories, despite the global rule that `.planning/` is frozen history. It
  swept 29 files into a branch two sessions ago. Worth finding the writer, or
  gitignoring the directory.
- **Nothing verifies that a project's `settings.json` registers each hook on the
  tools its implementation handles.** That has gone wrong once, across five
  repositories, and was caught by a person noticing a hook had not fired. The
  obligation now sits on whoever edits a `settings.json`. If it goes wrong twice,
  that is the argument for a fifteen-line comparison inside `check-shims.sh` —
  and for nothing larger.
- The convergence rule is still unwritten — sixteenth session. It may have just
  written itself: *stop when the thing you are fixing is the thing you built to
  find things to fix.*
