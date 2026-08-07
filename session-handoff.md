# Session Handoff — 2026-08-07 (thirteenth session)

`fresh-clone-needs-nothing` is **decided and reviewed once**. Both blocking
questions answered, three vendors reviewed it, findings folded, `validate --all`
green. PR #89, 20 commits. **Still no code written in any of the five changes.**

| Change | Reviews | State |
|---|---|---|
| `projects-bind-not-copy` | 2 rounds × 3 vendors | repaired; measurement folded in |
| `one-enforcement-floor` | 2 rounds × 3 vendors | repaired, artifact-complete |
| `diagram-is-the-surface` | 2 rounds × 3 vendors | repaired (1 approve, 2 request-changes) |
| `fresh-clone-needs-nothing` | **1 round × 3 vendors** | **folded; ready to implement** |
| `fleet-carries-only-current` | **none** | still never reviewed |

## Accomplished

- **Answered both open questions.** The initializer is `init-project.sh`,
  published by `install.sh` into `~/.agenticapps/bin`. No CI workflow file.
- **Reviewed once** — gemini, codex, opencode, all three REQUEST-CHANGES. Verified
  each claim against the working tree, folded what was real, recorded what wasn't.
- Two commits: `48ae3b0` (decisions), `45a2b3f` (review fold). Pushed.

## Decisions

- **The initializer is a published executable, not a subcommand or a skill step.**
  The design's premise — "core has no project-side surface, so no precedent" — was
  false: the gate, `reviewer-cli.sh` and `run-plan-review.sh` are all
  machine-installed and repository-invoked. The stronger argument is that it
  *cannot* live in the repo: this capability holds a repo to two artifacts and no
  executables, so a repo-carried initializer is the first thing the sweep deletes.
- **No CI workflow file.** "A fresh clone needs nothing" now states its scope —
  the two surfaces `install.sh` establishes. CI stays the repository's own choice.
- **`~/.agenticapps/bin` is not on `PATH` and will not be put there** — that means
  writing shell configuration, which `install.sh` refuses. Absolute path, and the
  four artifacts already there have the same property.
- **pi is corrected but *unconfirmed*, not fixed.** Its evidence was that
  `~/.pi/agent/skills` holds symlinks — directory presence, which this change's own
  new requirement refuses as evidence. Confirming it needs pi observed resolving
  the skill (task 8.2a). opencode caught this; it was circular.

## What the reviewers changed

1. **The change contradicted a landed spec.** `host-neutral-instruction-files`
   exempts `CLAUDE.md` from its marker rules because "Claude is its only reader, so
   there is nothing to deduplicate" — a symlink *inverts* that premise. New
   MODIFIED delta narrows the exemption to a separate regular file, and binds the
   initializer to that capability's normative markers rather than inventing a
   second provenance convention.
2. **The target shape contradicted itself** — spec said no repository skills while
   tasks kept six `openspec-*` skills. Tasks were right; prohibition is now scoped
   by *publisher*, not file type.
3. **The `CLAUDE.md`-only case produced two real files** — the exact failure the
   rule prevents. Its content now moves to `AGENTS.md`. Plus identical-content,
   symlink-elsewhere, directory and dangling-link states.
4. **The sweeper is now its own artifact**, refusing on a dirty worktree and
   removing only from an owned manifest — `git revert` restores nothing untracked.
   Precondition checked by *effect on this machine*, not by core's merge history.

Declined with reasons in `design.md`: a Windows symlink fallback (reintroduces the
two-file defect for a platform with no user here), a second exit-code contract
(`workflow-installation` already has one), a "dangling" flag reference that is
named in the landed spec.

**Pattern worth keeping:** three findings were all cases where `tasks.md` was right
and the spec delta was wrong. Tasks are discarded at archive; the spec survives.

## Files modified

- `openspec/changes/fresh-clone-needs-nothing/design.md` — both decisions with
  rejected alternatives; a "findings not adopted" section; 4 open questions → 2
- `.../proposal.md` — initializer named and published; pi downgraded to unconfirmed
- `.../tasks.md` — 4.1a–4.1c, 3.7–3.11, 6.0–6.1c, 8.2a–8.2b
- `.../specs/project-onboarding/spec.md` — two new requirements, ~10 new scenarios
- `.../specs/workflow-installation/spec.md` — unconfirmed-mapping and co-tenancy
- `.../specs/host-neutral-instruction-files/spec.md` — **new**, the MODIFIED delta
- `session-handoff.md` — this file

## Next session: start here

**Write code.** Five changes are planned and four are reviewed; nothing has been
implemented, and that is now the whole risk — the plans have been revised four
times against each other rather than against a running thing. Start with
`fresh-clone-needs-nothing` §3 (RED for the initializer) since it is the only one
whose artifact does not yet exist, and its tests are fully specified. But note the
sequencing: its **sweep** is blocked on `projects-bind-not-copy` and
`one-enforcement-floor` being *effective on this machine*, so the initializer and
its tests come first, the sweep last.

## Open questions

1. **`fleet-carries-only-current` has never been reviewed** — five sessions old.
2. **§18's version number** — still blocking one task in `diagram-is-the-surface`.
3. **Is omp's skill directory ever establishable?** If omp reads no skills, remove
   the mapping rather than correct it.
4. **`agenticapps-dashboard-add-agent-board`** — stray worktree, still undecided.
   The sweep now refuses globs, which contains the hazard but does not decide it.
5. **CodeRabbit still has not reviewed anything here** — its check state is not
   evidence. Unchanged from yesterday.
6. Reported paths still carry `/Users/donald` unescaped — deferred a sixth time.
7. The gitnexus skills still load in this repo until `diagram-is-the-surface` lands.
