# Session Handoff — 2026-08-03 (evening)

## Accomplished

- **The 28-branch inspection is done and the reclaim is executed.** All 27
  eligible branches deleted, 16 worktrees removed, nothing lost.
  `brand-report/master` kept — default branch, only local branch, deleting it
  leaves a detached HEAD.
- **Merge status was re-derived, not inherited from the last handoff.** All 27
  confirmed merged in substance, including three that the cheap checks called
  unmerged.
- **Two unignored secret-shaped files closed off** (gitignore only, files
  untouched and unread): `neuroflash/api-documentation/.env` — that repo ignored
  `.env.local` and three variants but **not plain `.env`** — and
  `neuroflash/terraform/openssl rand -hex 32.txt`, a shell command captured as a
  filename. Both were previously stageable by `git add -A`.
- **Recovery record at `~/Sourcecode/.worktree-reclaim-2026-08-03/RECOVERY.md`**
  — every deleted tip SHA plus the six preserved dirty worktrees. Deliberately
  outside any repo and outside the session scratchpad, which does not survive
  `/clear`.

## Decisions

- **Re-verified merge status at deletion time rather than trusting yesterday's
  classification** — the prior handoff's own lesson about dated claims. This
  paid: `ai-engineering-framework/fuchsia-rock`'s PR was **CLOSED, not merged**,
  which the inherited list recorded as merged.
- **`brand-report/master` excluded** from an otherwise full sweep.
- **`git worktree repair` before removal**, not `--force` through the error.
  That is what exposed 4 genuinely dirty worktrees that had read as clean.
- **Dirty worktrees backed up before removal even though all of it was tool
  scratch** — copied rather than assumed worthless.
- **`.gitignore` edits left uncommitted.** Never-commit-to-main applies; a
  working-tree `.gitignore` already blocks `git add -A`, so the protection is
  live without a commit. Committing them needs a branch + PR per repo — not done.

## The two measurement bugs, which is the reusable part

1. **`ancestor-of` and `tree-identical` both fail on squash merges.** They
   marked 8 of 27 unmerged. Only the merged PR's **head SHA** resolved them.
   Three had real commits past their PR head; all three had landed anyway.
2. **12 worktrees' `.git` files still pointed at pre-reorganization paths**
   (`~/Sourcecode/<repo>`, not `~/Sourcecode/<family>/<repo>`). `git status`
   there **errored**, and my `2>/dev/null` swallowed the error into `"clean"`.
   `git worktree repair` fixed the pointers and revealed 4 dirty worktrees.

Also worth keeping: `git diff base..branch --stat` renders **main's forward
progress as branch deletions**. It made `claude-workflow` look like it deleted
91,655 lines it never touched. Diff from the **merge-base** to see what a branch
actually contributes.

Same shape as last session's `IFS=` leak and its fixture-naming bug:
**an error silently rendered as a passing observation.** Third instance.

## Files modified

- `~/Sourcecode/.worktree-reclaim-2026-08-03/` — **new**, recovery record + 6 backups
- `neuroflash/api-documentation/.gitignore` — added `.env` (uncommitted)
- `neuroflash/terraform/.gitignore` — added `openssl rand -hex *.txt` (uncommitted)
- This repo: **untouched**. No code, spec or tool changes.

## Next session: start here

**Nothing is in flight.** `main` clean and level with `origin/main`, no active
OpenSpec change. The branch work is finished.

The highest-value remaining work is the **requirement-placement change**,
unchanged from the last handoff: the entire three-axis state model, every
currency invariant and all six currency scenarios live under a requirement
titled *"An unresolvable shim allows, and the operator sees it"* — two headings
above one literally called *"Provisioning is checked per machine"*. opencode
raised it as non-blocking; it is correct, pre-existing, and the currency change
made it materially worse by adding ~200 lines under the wrong heading. Start
with `/opsx:propose`; the reasoning is in
`openspec/changes/archive/2026-08-03-check-implementation-currency/ARCHIVE-NOTE.md`.

## Open questions

- **Uncommitted `.gitignore` fixes in two neuroflash repos** need a branch + PR
  each to become durable. Until then they protect this machine only.
- **`provisioning-check.sh` is not published to the shared bin.** Currency works
  and defaults on, but only where core is checked out. Nothing prompts anyone on
  a machine without a core checkout to discover their install is stale.
- **The `cmp`-error branch is reasoned, not tested.** `cmp` exit 2 reports
  `unknown`, not `stale`; the path *reaching* it is not portably constructible.
  Negative evidence, not coverage.
- **The `PostToolUse` fail-open channel remains unverified** — eighth session;
  `normalize-claude-md` is the live instance.
- **27 branches carry genuinely unmerged content** (the separate set the prior
  sweep kept). Classified for reachability, **never for worth** — nobody has
  judged whether any of it is wanted. `terraform` 6, `cparx` 5, `mcp-server` 6,
  rest scattered.
- The convergence rule is still unwritten — eighth session.
