# Session Handoff — 2026-08-03 (afternoon)

## Accomplished

- **`check-implementation-currency` is implemented, merged and archived.**
  PR **#66 → `db02493`**, archive PR **#67 → `09f829e`**. `openspec list` reports
  **no active changes**; the delta is folded into `openspec/specs/`.
- **`project-hook-binding` lost a sentence that was observed false**, not merely
  imprecise: *"`attested` … is the only value on either axis under which the
  fleet's protections may be described as running as documented."* It gained a
  third axis, `currency ∈ {current, stale, unknown}`, and the licence now
  requires **`complete` + `attested` + `current`**. Plus a new requirement,
  *"The implementation version marker is compared, not merely carried."*
- **Project-hook suites 190 → 243**, all green. Validate 5/5 (change no longer
  active), gate `--ci` OK, gate conformance **355/355**, harness 36/5.
- **Branch sweep across the family.** 257 non-default local branches existed at
  the start of the sweep. **202 deleted**, all verified merged; **28 skipped**
  (merged but checked out in a worktree); **27 kept** (genuinely unmerged).

## The defect this change existed for, and what it actually was

The comparison **already existed** as `--source-check`, worked, and reported
`DIFFERS` on both artifacts — while the summary printed *"This machine is
provisioned. The shims will resolve."* anyway. The finding fed a separate block
and no verdict. So this was never "build a check"; it was three narrower things:
the summary ignored it, it was opt-in and its absence undisclosed, and the spec
vocabulary could not express the result.

The first draft of the change proposed building the comparison. Round 1 of plan
review caught that and the change was rewritten (`bc1411a`, before this session).

## Decisions

- **`--no-source-check --strict` exits 1 unconditionally.** Kept deliberately;
  the Migration Plan's claim that the flag "restores the old default" was false
  and was corrected. Carving the opt-out out of `--strict` would restore, in one
  flag, the silent pass this change removes. **If a future reviewer reads this as
  a bug, that is the paragraph to point them at.**
- **`--source-check` with `--no-source-check` is a usage error (exit 64)**, not
  last-one-wins — which silently did the opposite of half the instruction.
- **`semver_cmp` was EXTRACTED** to `tools/lib/semver.sh`, not copied. This gives
  `project-hook-conformance.sh` a failure mode it lacked (refuses without the
  lib). Accepted: a divergent copy fails *silently* — a lexical compare puts
  `1.10.0` below `1.9.0` and hands the operator the opposite remedy.
- **Currency judges the `ARTIFACTS` declaration only.** An earlier revision made
  an absent authority file `stale` without scoping it; running it flagged the
  three artifacts published by `install-shared-artifact.sh`.
- **Synced the delta without prompting** at archive time. Not syncing would have
  folded the known-false sentence into durable truth.
- **Branch deletions re-verified at deletion time**, not on the classification.
  Checked-out branches skipped rather than forcing anyone's working state.

## Files modified

- `tools/provisioning-check.sh` — default-on authority resolution, the `CURRENCY`
  verdict, per-condition remedies, corrected summary, `--no-source-check`
- `tools/lib/semver.sh` — **new**, sourced by both callers
- `tools/project-hook-conformance.sh` — sources the lib; refuses without it
- `tools/project-hook-provisioning.test.sh` — 56 → 109 assertions
- `reference-implementations/project-hooks/README.md` — the triple, the dated
  counter-example, the per-condition remedy table
- `openspec/specs/project-hook-binding/spec.md` — the delta, synced
- `openspec/changes/archive/2026-08-03-check-implementation-currency/` — incl.
  `ARCHIVE-NOTE.md` and `CODE-REVIEW.md`

## Next session: start here

**Nothing is in flight.** No active OpenSpec change, no open PR, `main` clean and
level with `origin/main`. The highest-value next piece of work is the
**requirement-placement change**: the entire three-axis state model, every
currency invariant and all six currency scenarios now live under a requirement
titled *"An unresolvable shim allows, and the operator sees it"* — two headings
above one literally called *"Provisioning is checked per machine"*. opencode
raised it as non-blocking; it is correct, pre-existing, and **this change made it
materially worse** by adding ~200 lines under the wrong heading. Start with
`/opsx:propose` for that move. The reasoning is in the archive note.

If instead you want to finish the sweep: 28 verified-merged branches remain only
because they are checked out. Clearing them means switching ~15 repos to their
default branch — check each for uncommitted work first; several are linked
worktrees under `~/.config/superpowers/worktrees/`.

## Open questions

- **The `cmp`-error branch is reasoned, not tested.** `cmp` exit 2 (*could not
  compare*) reports `unknown` rather than `stale`. Exit 2 is verified against a
  real invocation; the path that *reaches* it — a mid-read I/O error on a file
  that passed `-r` a microsecond earlier — cannot be constructed portably here.
  Negative evidence, deliberately not counted as coverage.
- **The `PostToolUse` fail-open channel remains unverified.** Seventh session.
  `normalize-claude-md` is still the live instance.
- **`provisioning-check.sh` is not published to the shared bin.** Currency works
  and defaults on, but only where core is checked out. **Nothing prompts anyone
  on a machine without a core checkout to discover their install is stale.** The
  change states this honestly; it does not fix it.
- **27 branches carry unmerged content** — `terraform` 6 (all MCP-related,
  1 ahead / 200+ behind), `cparx` 5 (two are explicit `backup/*` safety copies),
  `mcp-server` 6, rest scattered. Classified for reachability, **not for worth**.
  Full data in this session's scratchpad `verdicts.tsv` / `deleted.tsv`; if that
  is gone, the classification is reproducible from the two scripts' method:
  ancestor → tree-identical → merged-PR-head-SHA → post-merge-commits-in-main.
- The convergence rule is still unwritten — seventh session.

## Two corrections to the previous handoff, and why they matter

1. It said the `chore/shim-project-hooks*` branches were "content-identical to
   `origin/main` — safe to delete." **True when written, false by the time it was
   read**: main moved to shim-contract 1.1.0 afterwards. It stayed safe for 12 of
   16 and would have destroyed unmerged work in the rest.
2. It described `check-implementation-currency` as "proposed and unimplemented",
   which was two commits stale on arrival.

**A dated claim about a moving tree is a claim with a shelf life.** Prefer
recording *how to re-derive* a fact over recording the fact.

## The methodological lesson, which cost the most time today

Three separate wrong conclusions, all pointing the same way — toward keeping
branches that were merged, and toward a fleet "finding" that did not exist:

- **`git cherry` cannot see squash merges.** It marked 10 merged commits as
  unique; the reliable signal is the merged PR's **head SHA == branch tip**.
- **A stale `origin/main` ref** made `claude-workflow` look like 49 unmerged
  files when its tree was byte-identical. Always `git fetch` first.
- **`IFS=` leaked** out of a `while IFS= read` into a later `for`, so nothing
  word-split and every branch classified as "keep".

And in the test suite: **five fixtures were named for the words their own
assertions grep for**, so `has "$OUT" "behind"` matched the directory
`…/auth-behind` against the *unfixed* tool — six assertions green on a broken
build. That is the `override-dir` defect from the previous change, on the same
suite, four days later. It was caught only by re-running the whole suite against
the pre-change tool instead of trusting it to be red.

**A test never observed failing is not evidence of anything.** This suite has
now produced that error twice.
