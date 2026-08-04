# Session Handoff — 2026-08-03 (evening)

## Accomplished

- **The 28-branch reclaim is done.** 27 branches deleted, 16 worktrees removed,
  nothing lost. `brand-report/master` kept — default *and* only local branch.
  Recovery record with every tip SHA at
  `~/Sourcecode/.worktree-reclaim-2026-08-03/RECOVERY.md`, deliberately outside
  any repo and outside the session scratchpad.
- **The requirement-placement change shipped** — PR **#70**.
  `project-hook-binding` goes 15 → 17 requirements; the ~480-line shim
  requirement is split three ways, each heading naming what it governs. No
  normative text changed: 116 normative sentences before and after.
- **Two unignored secret-shaped files closed off** — PRs **api-docs #14** and
  **terraform #185**. `api-documentation` ignored `.env.local` and three
  variants but **not plain `.env`**; `terraform` held a file named
  `openssl rand -hex 32.txt`, a shell command captured as a filename. Neither
  file was read or moved.

## Open PRs — none merged yet

| PR | what |
|---|---|
| core **#69** | this handoff |
| core **#70** | the requirement split |
| api-docs **#14** | ignore plain `.env` |
| terraform **#185** | ignore stray secret output |

## Decisions

- **Re-derived merge status instead of inheriting yesterday's classification.**
  It paid: `ai-engineering-framework/fuchsia-rock`'s PR was **CLOSED, not
  merged**, though its content had reached main another way.
- **Moved the scenario, not the paragraph**, for the misfiled installer scenario.
  The `installer SHALL verify` sentence is load-bearing inside the shim
  requirement's absence-vs-misconfiguration carve-out.
- **Left one real defect unfixed, deliberately.** The axes table's Currency cell
  says an artifact the authority lacks is `stale`; the currency requirement says
  an artifact absent from the machine is not judged on that axis at all. Real,
  **pre-existing, byte-identical in `main`**. Fixing it is a normative change,
  and smuggling one into a no-semantic-change refactor is what the change
  promised not to do. **This is the next change.**
- **Reordered the spec by hand after the fold**, via a committed idempotent
  script, because `openspec archive` cannot express placement.

## Three tooling facts, none of them documented anywhere

Established by probing `openspec archive` and resetting:

1. **`MODIFIED` cannot shed scenarios** — archive aborts. So no `MODIFIED`-based
   delta can move a scenario between requirements.
2. **A requirement may not appear in both `ADDED` and `REMOVED`** — so splitting
   a requirement **forces a rename** of the surviving piece.
3. **`ADDED` requirements are appended at end-of-file.** The delta cannot express
   order at all.

## The theme, now at five instances

Every failure this session was a **check that lied**, not a broken artifact:

- `ancestor-of` / `tree-identical` both fail on squash merges — marked 8 of 27
  unmerged.
- 12 worktrees' `.git` pointers were stale from the family reorganization;
  `git status` **errored** and a `2>/dev/null` swallowed it into `"clean"`. Four
  were actually dirty.
- `git diff base..branch --stat` renders main's *forward progress* as branch
  deletions — made `claude-workflow` look like it deleted 91,655 lines.
- The normative-sentence check compared Python-sorted files with `comm`, which
  uses locale collation. Mismatched orders **invented six differences**.
- The line-multiset diff proved every line survived — and **cannot** detect a
  line filed under the wrong heading. Three real misfilings got through it.

**"Every line still exists" is a weaker property than "every line is in the right
place."** Only the independent reviewer, reading for sense, closed that gap.

## Files modified

- `openspec/specs/project-hook-binding/spec.md` — the split (PR #70)
- `openspec/changes/archive/2026-08-03-place-provisioning-requirements/` — incl.
  `REVIEW-RESPONSE.md` and `tools/reorder-requirements.py`
- `~/Sourcecode/.worktree-reclaim-2026-08-03/` — **new**, recovery record + 6 backups
- `neuroflash/api-documentation/.gitignore`, `neuroflash/terraform/.gitignore`

## Next session: start here

**Merge the four open PRs first** — nothing is merged, and #70's branch holds the
only copy of the split.

Then open the change for the **axes-table Currency contradiction** described
under Decisions. It is a better-formed defect than the placement complaint that
started this one: the spec says two different things about one condition
(an artifact declared, absent from the machine, and absent from the authority).
Reasoning is in `REVIEW-RESPONSE.md` round 2, which travels with the capability.

## Open questions

- **The axes-table Currency contradiction** — see above. The next change.
- **`provisioning-check.sh` is not published to the shared bin.** Currency works
  and defaults on, but only where core is checked out. Nothing prompts anyone on
  a machine without a core checkout to discover their install is stale.
- **The `cmp`-error branch is reasoned, not tested.** Negative evidence, not
  coverage.
- **The `PostToolUse` fail-open channel remains unverified** — eighth session.
- **27 branches carry genuinely unmerged content**, classified for reachability
  and **never for worth**. Nobody has judged whether any of it is wanted.
- The convergence rule is still unwritten — eighth session.
