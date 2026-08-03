# Session Handoff — 2026-08-03

## Accomplished — the later half first, it is where the open work is

- **`shim-project-hooks` is ARCHIVED** (PR #65). `project-hook-binding` is now
  durable truth in `openspec/specs/` — a new capability, +14 requirements.
  Archiving had to come first: the capability existed *only* in the open delta,
  so nothing could amend it until it was folded.
- **This machine's implementations were STALE and are now current.**
  `database-sentinel` 1.0.0 → 1.1.0, `normalize-claude-md` 1.0.0 → 1.0.1, by
  re-running `install-project-hooks.sh`. Verified behaviourally, not by version
  string: `CLAUDE.md` now 644 in → **644** out (was 644 → 600), and
  `DELETE FROM public.users` now **exits 2** (was unmatched).
- **New change proposed: `check-implementation-currency`**, branch
  `feat/check-implementation-currency`, commit `cf85572`. All four artifacts
  complete, `openspec validate --all` **6/6**. No code written yet.

## The defect that change exists for

`provisioning-check.sh` reported this machine `COMPLETENESS complete`,
`INTEGRITY attested`, "This machine is provisioned. The shims will resolve." —
while running two implementations three landed fixes behind. It printed
`attested v1.0.0` while doing it; the number was on screen and **nothing compared
it to anything**.

`attested` compares each published file to the **manifest row written when it was
installed** — what *was* published, never what core *now* ships. So a machine can
be attested against a stale build indefinitely.

**The sharper shape:** the capability defines TWO version markers and built a
comparison for ONE. `# shim-contract:` got `project-hook-conformance.sh`.
`# <hook>-version:` was defined in the same change (task 3.2a-iv) and nothing has
ever read it against core. That is "a marker with no check makes nothing
detectable" left unapplied to its own second marker.

The delta is a **MODIFIED** requirement, not only an ADDED one, because this
sentence was false and had to go rather than be contradicted:

> **`attested`** — … This is the only value on either axis under which the
> fleet's protections may be described as running as documented.

It held here for fifteen hours. The licence now needs
`complete` + `attested` + `current`.

## Earlier the same session — shim-contract 1.1.0, all merged

- **Discharged task 7.6 — the last open box on `shim-project-hooks`.** The
  operator decided *fix and propagate*, and *record the empty-override
  behaviour as intended*. `tasks.md` now has **0** unchecked items.
- **shim-contract 1.0.0 → 1.1.0.** An override is honoured only when it names an
  executable **regular file**. Branch `fix/shim-contract-1.1.0`, core PR
  **#63**, plus seven fleet PRs.
- **Suites 155 → 190**, all green. Gate conformance 355/355, harness reporting
  36 passed / 5 skipped, `openspec validate --all` 5/5, gate `--ci` OK.
- **CodeRabbit reviewed #63 and posted four findings. Three are fixed** in
  `8c5c749`, one is declined on the thread — see Decisions.

## What the fix actually was

`[ -x "$OVERRIDE" ]` tests the search bit, which every ordinary directory has,
so a directory override was `exec`'d: bash exited **126** with its own "is a
directory" message, the invalid-override report never fired, and the exit code
was not the 1 the contract states. Now `[ -f ] && [ -x ]` in all three binders.

**Three corrections to what the deferral said**, all recorded in `CODE-REVIEW.md`:

1. **21 binders, not eight.** "Eight files" counted `openspec-change-gate`
   binders only (seven projects + core), but the fix is in the *template*, which
   also renders `database-sentinel` and `normalize-claude-md`. The re-render
   reached **20 project shims across seven repositories** plus core's
   self-hosting binder. Still seven fleet PRs; wider diff in each.
2. **Core's own binder had the same defect** and the deferral did not name it.
   `.claude/hooks/openspec-change-gate.sh` tested `-x` on `$OPENSPEC_GATE` too.
   Fixed per its own profile — it resolves one candidate, not two, so its answer
   is warn-name-and-fail-open rather than the shim's exit 1. Exempting the
   repository that defines the contract is finding 12 exactly.
3. **The gate shim had no test coverage of any kind.** It is a hand-maintained
   sibling of the template, so every existing assertion reached the template
   only — which is precisely why finding 6 sat in both files and was caught in
   neither. It now has the full override matrix plus both resolution candidates.

## Decisions

- **Empty override recorded, not changed.** `FOO=` still falls through, because
  it is how an operator says "no override", not how they name a broken one. So
  "set" in the requirement reads as *set to a non-empty value*. The requirement
  text was **not** amended — the operator chose recording over a spec edit — so
  the README and an assertion in `project-hook-shim.test.sh` are where the
  reading lives. **If a future reviewer reads "set" literally, this is the
  tension to point them at.**
- The directory fixture in the suite is deliberately **not** named
  `override-dir`. It was, and the "reports the override, naming the path"
  assertion passed against the broken shim — bash's own `.../override-dir: is a
  directory` contains both the word and the path.
- Per-project verification is behavioural, not just byte-identity: each
  installed shim is driven with its override pointed at a directory. The check
  fails 3/3 at exit 126 against a 1.0.0 repo, so it discriminates.
- **CodeRabbit's "make the empty-override exception normative" is DECLINED**,
  because it asks for the option you explicitly did not choose. Recorded on the
  thread rather than silently skipped. **This is now the second independent
  reviewer pointing at the same tension** — Stage-2 finding 6 was the first. If
  it is ever to be settled by amending the requirement, that is a fresh
  decision, and the case for it is stronger than it was this morning.
- **`--fleet` scores the working tree**, which is a real limitation discovered
  the hard way: a concurrent session switched `agenticapps-dashboard`'s checkout
  to `chore/retire-v1-surfaces-review-fixes` mid-rollout, and the next run
  reported it stale while the propagated shims sat safely on the pushed branch.
  The durable check is a byte-comparison against the pushed refs — that is what
  the 20/20 figure below rests on, not on anyone's checkout.

## Files modified

- `reference-implementations/project-hooks/shim-template.sh` — `-f` guard, 1.1.0
- `reference-implementations/project-hooks/openspec-change-gate.shim.sh` — same
- `.claude/hooks/openspec-change-gate.sh` — same, self-hosting profile
- `reference-implementations/project-hooks/README.md` — contract revisions
  table, the binders named per profile, the empty-override decision
- `reference-implementations/project-hooks/FLEET` — **new.** The seven consuming
  repositories, declared by name. Removes a third enumeration rather than adding
  one: the test file's hardcoded absolute paths are gone
- `tools/project-hook-conformance.sh` — `--fleet <root>` resolves the declaration
  and reports a declared repo that resolves nowhere as a finding
- `tools/project-hook-shim.test.sh` — +24 assertions
- `tools/project-hook-conformance.test.sh` — +11, fleet declaration and `--fleet`
- `openspec/changes/shim-project-hooks/{tasks.md,CODE-REVIEW.md}` — 7.6 closed

## All eight PRs are MERGED — core first

| repo | PR | | repo | PR |
|---|---|---|---|---|
| agenticapps-workflow-core | **#63** → `d225954` | | callbot | #99 |
| agenticapps-dashboard | #94 | | cparx | #120 |
| agenticapps-roadmap | #12 | | fbc-platform | #104 |
| agents-task-viewer | #17 | | fx-signal-agent | #119 |

Core landed first: the fleet shims are byte-compared against its template, so a
fleet PR ahead of it would leave main disagreeing with its own authority.
All squash-merged. **`--admin` was not used anywhere** — `fx-signal-agent` #119
merged normally over its pre-existing red `gitleaks` / `pnpm-audit`.

**Verified on `origin/main`, not on any working tree: 20/20 project shims
byte-identical to core's authority at 1.1.0, 0 drifted**, plus core's
self-hosting binder — 21. Suites 190/190 on merged main, `openspec validate
--all` 5/5, gate `--ci` OK.

## Next session: start here

**`check-implementation-currency` is proposed and unimplemented.** Stage 2 of the
lifecycle is where it sits: `openspec validate --all` is green (6/6), and
`run-plan-review.sh check-implementation-currency --implementing-host claude` was
started this session — **check whether `REVIEWS.md` landed** before writing any
code, and read it. That review is the cheapest point to find out the design is
wrong, and the gate will not make you run it.

Then `/opsx:apply check-implementation-currency`. Task 1.1 is a RED test that
must fail today by reporting `complete` + `attested` on a synthetic stale
install — if it passes on first run, the fixture is wrong, not the defect absent.

Design open question 1 is unresolved and is a task-2.1 decision: does
`provisioning-check.sh` locate the authority automatically from its own location
(the gate hook's fixed-point argument) or take `--authority DIR`? Proposed: both,
automatic by default.

**Archive with the residual named, not silently.** Every task is checked, but
task 2.3a's empirical leg is recorded with *negative* evidence: the fail-open
report's channel for `PostToolUse` was never verified, and the README's "The
empirical leg (task 2.3a)" section is where that is written down. Archiving is
correct — the change does not claim the channel is proven — but the archive note
should carry the residual forward rather than let "0 open boxes" read as "no open
questions". CodeRabbit raised exactly this on #63, and it is a fair reading of an
unqualified "next session: archive".

## Open questions

- **No third-party review ran on this work.** As on #62, that is a discipline
  question, not a gate one: since gate 2.0.0 nothing blocks on reviewer
  evidence. Consider `run-plan-review.sh` before merging #63.
- Six repos still have local `chore/shim-project-hooks*` branches, 3–4 commits
  ahead of `origin/main` and **content-identical** to it — the pre-squash
  originals. Safe to delete; not deleted, since they are not mine to discard.
- **Every machine is still unprovisioned until it runs
  `install-project-hooks.sh`** — unchanged, and now the shims on main expect a
  newer contract than any older published implementation knows about. Nothing
  prompts anyone to notice.
- **`agenticapps-dashboard`'s local checkout is on another session's branch**,
  `chore/retire-v1-surfaces-review-fixes`, which predates the merge — so its
  working tree still holds 1.0.0 shims and `--fleet` reports it stale. `origin/main`
  is correct; that branch picks up 1.1.0 when it merges main. **Deliberately not
  touched** — it is not this session's branch to move.
- `agenticapps-dashboard`'s `feat/close-readiness-spec-gaps` still carries the
  other session's two stray commits. Untouched this session — #94 branched from
  `origin/main` and is unaffected.
  (The `fix/shim-contract-1.1.0` branches were deleted on merge; the older
  `chore/shim-project-hooks*` ones above were not.)
- The fail-open report's channel for `PostToolUse` remains unverified.
- The convergence rule is still unwritten — sixth session.
