# Session Handoff — 2026-08-02 (night)

## Accomplished

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

## Next session: start here

**Merge the eight PRs, core first** (the fleet shims are byte-compared against
core's template, so landing a fleet PR before core would make main disagree with
its own authority for as long as the gap lasts):

| repo | PR |
|---|---|
| agenticapps-workflow-core | **#63** |
| agenticapps-dashboard | #94 |
| agenticapps-roadmap | #12 |
| agents-task-viewer | #17 |
| callbot | #99 |
| cparx | #120 |
| fbc-platform | #104 |
| fx-signal-agent | #119 |

Then **archive the change** — `/opsx:archive shim-project-hooks`. It is the only
open change and every box is checked.

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
- `agenticapps-dashboard`'s `feat/close-readiness-spec-gaps` still carries the
  other session's two stray commits. Untouched this session — #94 branches from
  `origin/main` and is unaffected.
- The fail-open report's channel for `PostToolUse` remains unverified.
- The convergence rule is still unwritten — sixth session.
