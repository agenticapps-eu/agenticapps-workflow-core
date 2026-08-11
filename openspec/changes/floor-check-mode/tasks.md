# Tasks — the floor can be inspected

Carried out of `one-enforcement-floor`, which archived on 2026-08-11 with the
floor shipped and `--check` specified-but-unbuilt. Nothing here is new work
invented after the fact; it is the work that change did not do, given an honest
size.

**Sized to the diff.** One mode on one script, its tests, and one deletion. If
this list grows past what `--check` prints, something has been smuggled in.

Revised after step 2b. `REVIEWS.md` carries both reviews and every resolution;
the tasks that grew are §2's, and each of them is a condition `--check` prints.

## 1. Drop `--project` first, because it is subtraction

- [x] 1.1 Remove `--project` from the deferred-scope notes that name it.
      Nothing implements it and nothing calls it; a documented flag that does
      not exist advertises a capability the tool cannot provide, which is the
      same defect `GSD_SKIP_REVIEWS` was removed for.
      Both mentions are in `docs/HOW-IT-FITS-TOGETHER.md` and they contradict
      each other: line 160 says the gap "is why `--project` had to be deferred",
      line 229 says it "is dropped, not pending". A reader who stops at the
      first is waiting for something nobody is building.
- [x] 1.2 **Answered: say nothing.** Per-project binding is not durable
      behaviour owed a requirement — `one-enforcement-floor` superseded
      `--project` outright rather than deferring it, and that change is
      archived. No requirement is added. The task stays as the record of a fork
      that was closed, which is the only thing that distinguishes a decision
      from an omission.

## 2. `--check`, tests first

- [x] 2.1 RED: `bind-global-floor.sh --check` currently parses `--check` as a
      repository argument and refuses. Record that output; it is the baseline.
      **And record what the refusal does first**, which the plan did not
      anticipate: the run creates `~/.agenticapps/git-hooks` before it parses
      anything, so today's `--check` writes a directory on its way to refusing.
      That fixes where the mode goes — before the `mkdir -p`, not at any
      convenient point in the flow.
- [x] 2.2 RED for each reported machine condition, one assertion apiece:
      `core.hooksPath` unset; set and resolving to the published directory; set
      and dangling; set to a foreign directory; the published directory present
      with no dispatcher in it.
- [x] 2.3 RED for the dispatcher's currency states, which are seven and not two:
      absent, a symlink, not executable, current, modified (same version marker,
      different bytes), ahead (newer marker), not current (older marker).
      `ahead` is the one that must not read as `modified` — the publisher
      preserves a newer destination by design, so reporting correct state as
      drift is how a report loses its reader.
- [x] 2.4 RED: the gate executable the dispatcher invokes is absent, and the
      floor is reported as **not enforcing** despite a current, executable
      dispatcher. The dispatcher fails open on missing tooling by design; a
      report that stopped at the dispatcher would state the opposite of the
      truth about that machine. Found by the codex reviewer.
- [x] 2.5 RED: a repository carrying `openspec/` and no enrolment key is
      reported as ungated. This is the row the whole mode is for — the
      2026-08-08 measurement found five such repositories and nothing said so.
      Enrolment is read as the dispatcher reads it: `--local --type=bool`,
      normalising to `true`. `false`, a malformed value and a global-only key
      are each their own assertion, because each is a different way for the
      report to disagree with the hook.
- [x] 2.6 RED: a repository whose own hooks are displaced by the global binding
      is reported rather than silent.
- [x] 2.7 RED: core's local binding, declared, is reported as declared and not
      as redundant; undeclared, it is reported as at risk of being swept.
- [x] 2.8 RED for the grammar: `--check [repository ...]`, one section per named
      repository in the order given, and a name that is not a repository is
      reported and skipped rather than stopping the run. No search of the
      filesystem, ever — the migration set is named and never discovered, and
      inspection has no better claim to walk the machine than mutation does.
- [x] 2.9 Implement. GREEN, twice.

**Two defects the green suite did not catch, found by running the mode on the
real machine.** Both are recorded here rather than folded in silently, because
"the tests pass" and "the report is true" turned out to be different claims —
and the mode whose entire product is a sentence is exactly where that gap lives.

- [x] 2.10 RED then GREEN: a repository outside the floor is not therefore
      ungated. The first run reported **core** — the repository an operator runs
      this in most — as flatly `gated: no`, which is true about the floor and
      false about the repository: core binds locally by design so its commits
      are scored by the working-tree gate (ADR-0028), and that hook carries no
      enrolment predicate at all. The verdict now names the floor, and the
      surface that remains is named beside it.
- [x] 2.11 RED then GREEN: `.sample` hooks are not displaced, because git never
      runs one. The fleet measurement reported **537** displaced entries, of
      which **535 were git's stock samples** and 2 were real. A report whose true
      finding is 0.4% of its own output has buried it, which is the same defect
      as not reporting at all wearing a longer coat.
- [x] 2.12 RED then GREEN, from the security gate: the published directory is
      reported when it is group- or world-writable. The binder **refuses to
      publish** into one for exactly that reason, and the report was silent
      about it — so a machine already in that state read as perfectly healthy.
      Content comparison does catch a substituted hook; what it cannot show is
      that the machine is open to the substitution at all, which is the posture
      question this mode exists to answer. The gate found nothing else: the mode
      has no `eval`, no `exec`, sources nothing, executes nothing it reads, and
      reaches no repository it was not given.

- [x] 2.13 RED then GREEN, from reading the diff: `--path-format` arrived in git
      2.31, and the check path was written without the fallback the migration
      path already carries **twice**. Its absence is silent rather than loud —
      `--git-common-dir` returns nothing, the repository's own hooks directory
      resolves to `/hooks`, and displacement is then never reported for any
      repository on the machine. A report that answers "nothing is displaced"
      because it looked in the wrong place is worse than one that errors.
      Testable only because `run_binder_answering` already existed: no fixture
      can produce an old git, so the call is answered rather than the binary
      replaced. `shellcheck -S warning` is clean on everything added; its one
      warning is pre-existing and in the migration path.

## 3. It reports and repairs nothing

- [x] 3.1 Assert `--check` writes no file, creates no directory — including the
      published hooks directory 2.1 caught it creating — sets no git config at
      any scope, and exits 0 whatever it finds. A mode that can change state is
      one an operator has to think before running, and the value here is that
      asking is free.
- [x] 3.2 Assert the exit code does not encode the findings. A caller that
      branches on it turns a report into a gate, which is a different decision.

## 4. Close

- [x] 4.1 `openspec validate --all` green.
- [x] 4.2 Re-measured with the mode itself, 2026-08-11. **Named set: the 41
      repositories under `~/Sourcecode` at depth ≤ 3**, enumerated by the loop
      and handed to `--check` as arguments — the mode discovered nothing, and a
      count whose scope is not stated is not a measurement.

      | | |
      |---|---|
      | repositories named | 41 |
      | gated by the floor | **4** |
      | not gated by the floor | 37 |
      | carrying `openspec/` and not enrolled | **4** |
      | outside the floor by their own local binding | 2 |
      | carrying a hook the binding has displaced | 2 |

      The four gated are `callbot`, `cparx`, `fbc-platform` and
      `fx-signal-agent` — exactly the four the 2026-08-10 handoff recorded as
      enrolled, arrived at independently.

      **The four carrying `openspec/` unenrolled split two ways, and the mode is
      what separates them.** `agenticapps-workflow-core` and `claude-workflow`
      are outside the floor *by their own local binding* and each runs its own
      `pre-commit`; that is ADR-0028 working, not a gap. `codex-workflow` and
      `opencode-workflow` each carry a `pre-commit` — 5.8K and 2.3K, both from
      25 July — that the global binding **displaced**, and neither is enrolled.
      Both are therefore **completely ungated**: a hook on disk, nothing running
      it, and no marker. That is the condition the proposal describes, found by
      the surface built to find it, and nothing on either machine path said so
      before today. They are host repositories scheduled for deletion, so this
      is recorded and not repaired.
- [x] 4.3 ~~Bump `global-floor-version` and publish; the installer arbitrates on
      it.~~ **Wrong, and it would have caused the failure 2.3 exists to
      prevent.** `global-floor-version` marks the published *dispatcher*
      (`pre-commit`, at 1.1.0), which this change does not touch. The binder
      carries no version marker at all and is not a published artifact —
      `install.sh` runs it from the checkout, so `git pull` is its whole update
      path and nothing arbitrates on it. Bumping the marker would have told
      every machine its correct 1.1.0 dispatcher was stale, since `--check`
      judges currency by content against the checkout. Replaced by: assert the
      dispatcher is byte-unchanged by this diff, and publish nothing.
      **Asserted:** `git diff --quiet HEAD -- reference-implementations/global-floor/pre-commit`
      is clean, and the binder still carries no version marker of any kind.
