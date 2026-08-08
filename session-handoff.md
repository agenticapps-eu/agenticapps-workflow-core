# Session Handoff — 2026-08-08 (twenty-fourth session)

**PR #92 is open** on `feat/run-the-global-floor-migration`. The migration was
supposed to run this session and could not: the binder cannot act on a single
repository in the migration set, and behind that sat a second defect that would
have left one of them with no enforcement at all.

Nothing on the machine was mutated. `core.hooksPath` is still unset globally and
in core, the published hook is still the stale 2270-byte opencode copy, and all
three repositories still carry their hooks and are unenrolled.

## Accomplished

- **Ran the binder against the real three for the first time and declined the
  preflight.** It refused all three: their `pre-commit` carries no ownership
  marker. All three are byte-identical to
  `claude-workflow/bin/git-hooks/pre-commit` (md5 `3c871ab3…`, 1201 bytes),
  installed by a **host** repository's installer and absent from core's history.
  `install-core-git-hooks.sh` refuses to overwrite them by the same rule, so no
  tool this change ships could reach any repository it exists for.
- **0.3a measured the wrong property.** It classified nine copies by byte size
  and never asked about the predicate the code tests. The four sizes are four
  installers — 1201 claude-workflow, 2270 opencode-workflow, 5844
  codex-workflow, 1376 core — and only core's is marked.
- **Decision 8: the repository adopts its own hook**, `agenticapps.hooksadopt`
  set to the SHA-256 of the hook being adopted.
- **Round 3 plan review** (gemini APPROVE, codex REQUEST-CHANGES), folded in.
  Codex found the displacement below and the boolean-vs-digest hole.
- **Built it: 79 → 94 cases, RED before GREEN.** All 12 suites green,
  `openspec validate --all` 14/14.

## Decisions

- **The digest, not a boolean.** `hooksadopt=true` is a standing licence to
  delete whatever occupies that path whenever the migration next runs, including
  a hook written after the operator adopted. A digest asserts about the file they
  read and expires when it changes — which also closes the substitution window
  between the preflight and the delete. Both file and config are re-read
  immediately before removal.
- **In the repository, not a flag — and the first argument for that was wrong.**
  The draft argued "a command line can be globbed"; codex correctly noted path
  arguments are shell-expanded too and the `GLOBAL_FLOOR_ACCEPT='*'` incident was
  unquoted expansion *inside* the script. The surviving argument is scope: an
  assertion that lives with its subject outlives the command and can be audited
  later by reading that repository.
- **A refusal that the binding would displace stops the run.** Refusal happens
  before the enrolment pass, so a refused repository is never enrolled — and one
  with no local `core.hooksPath` has its own hook silenced the instant the
  binding lands. It ended with neither surface while the run reported it as
  keeping the hook it had. **This is #91's blind spot one set out**: that fix
  answered the displacement for repositories the run migrates and never asked
  about the ones it declines. A refusal *with* a local binding does not stop the
  run, because git prefers it.
- **The unnamed half is a corrected claim, not new behaviour.** The delta said an
  unnamed repository "remains gated by the hook it already carries" — false for
  any with no local binding. Enumerating them needs the search Decision 7
  removed, so the claim is corrected and `--check` (9.10) is named as where that
  report belongs.
- **Adoption widens exactly one predicate.** It does not enrol, sweep, replace
  the acceptance, travel between repositories, or relax the symlink and
  missing-file refusals — those are about the delete landing where the report
  could not name it.

## Files modified

- `reference-implementations/global-floor/bind-global-floor.sh` — `hook_digest`,
  `ADOPT_KEY`, the adoption branch in classification (symlinked hook split out of
  the marker test so adoption cannot reach it), `refuse_repo` recording which
  refusals the binding would displace, the abort before publish/bind, the
  distinct preflight line, and the digest re-check before removal. Plan record is
  now five lines, not four
- `tools/global-floor-bind.test.sh` — 15 new cases in two sections, plus
  `run_binder_after` (pass through, then mutate once). **The fixture is
  `foreign` on purpose**: an unmarked host copy and a stranger's hook are the
  same file to the binder, which is why the consent has to come from the operator
- `.../one-enforcement-floor/specs/workflow-installation/spec.md` — the adoption
  requirement with six scenarios, the displacement paragraph in "No repository is
  left with neither surface", and four scenarios around naming/refusal
- `.../one-enforcement-floor/design.md` — Decision 8
- `.../one-enforcement-floor/tasks.md` — 3.0a–3.0h; 0.3a and 3.1 annotated
- `.../one-enforcement-floor/REVIEWS.md` — round 3

## Next session: start here

**Stage 2 on #92, in this cleared session, per §07** — read the diff, not this
file's account of it. The thing to push on: `refuse_repo` decides displacement by
reading `core.hooksPath` at *refusal* time, while the classification reads `lhp`
later with `--type=path`; check the two cannot disagree, and check a repository
refused for a *declared* binding is correctly treated as undisplaced. Then
whether `hook_digest` returning empty on a machine with neither `shasum` nor
`sha256sum` is refused everywhere it is consumed.

Then **3.0h**, the thing this session set out to do: adopt in the three, run the
binder, read the preflight before answering y. The adopting commands are printed
by the refusal itself — the digest is
`9fb16d0eb9791e308b27c574731cedfc9fe89e1e0634df345b1095bc6722bca6` for all three,
because the files are identical. **Capture the before-state first**: each
repository's local `core.hooksPath`, its hook file, core's binding, the published
hook. Recovery is not one command — `git config --global --unset core.hooksPath`
recovers a bad *bind* only while no hook has been removed; after removal it takes
away the only surface the migrated repositories have.

## Open questions

1. **Binding silences unnamed repositories too**, and this is now written down
   rather than fixed. `codex-workflow` and `opencode-workflow` carry live
   unmarked hooks with no local binding and are archived checkouts pending
   Phase 5b — so the practical harm is small on *this* machine and the gap is
   real on any other. It belongs to `--check`, 9.10, still open.
2. **gemini's two findings are unaddressed and recorded**: Decision 1's "what is
   actually lost" omits that the surviving hook is `--no-verify`-bypassable
   (9.8 already says so); and whether the enrolment predicate precedes `hooks.d`
   dispatch is an implementation accident rather than a guarantee (9.7).
3. The census inconsistencies CodeRabbit found on #90 are still unfixed —
   `fleet-carries-only-current/proposal.md:71` ten/six against eleven/seven,
   `planning-removal-inventory.md` 48/6 against 50/4, GSD tree counts in
   `proposal.md:27` and `tasks.md:206`. Three inventory docs want ` ```text `
   fences (MD040).
4. `--check`'s half of 9.10 is open, and so are 9.5, 9.7, 9.8, 9.9, 9.12.
5. **2.6a**: `.planning/` was one name doing two jobs; the split is unrecorded.
6. **`fx-signal-agent` has no `packageManager` pin** — it is in the migration
   set, so it lands with 3.0h.
7. Six `~/.claude/projects/*/memory/*gsd*` files left alone — records about GSD.
8. The four host repos still carry `.planning/` by 1.2, pending Phase 5b.
9. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
   held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
   Operator action, still outstanding.
10. `claude-workflow` cannot be deleted safely — 11 commits on no remote,
    `plan/28-split-01` 9 ahead of `origin/main`, 1 stash. **Note it is also the
    provenance of every hook in the migration set**, so it is worth reading
    before it goes.
11. `fleet-carries-only-current` task 0.1 is breached: gated on
    `projects-bind-not-copy` being archived, which has not happened.
12. Spec drift on `main`: `openspec/specs/project-hook-binding/spec.md` names
    `normalize-claude-md` as a live shim in seven places; the implementation is
    gone. Planned in `diagram-is-the-surface`, 0/46.

## Mistakes worth not repeating

- **A measurement can be precise and about the wrong property.** 0.3a recorded
  nine hook sizes to the byte, spotted that five were identical, and drew a
  correct conclusion about drive-by installs — while never checking the one
  attribute the removal code tests. Precision is not relevance. When a census
  exists to decide whether code can act, measure *what the code branches on*.
- **My own first check reproduced the error it was looking for.** I grepped for
  the marker using `$(git -C "$p" rev-parse --git-common-dir)/hooks/pre-commit`
  — and `--git-common-dir` returns a **relative** `.git`, so all three greps read
  core's hook from the current directory and reported PRESENT three times. It
  agreed with the census, which is what made it convincing. **Resolve paths
  absolutely before asserting about files in another repository.**
- **The fix for a displacement was scoped to the set that was in hand.** #91
  moved enrolment ahead of the binding for the repositories the run migrates and
  never asked the same question about the ones it refuses — even though the
  refusal path is three lines away and leaves them equally unenrolled. When a
  fix answers "at this instant, what is displaced", enumerate every set that
  reaches the instant, not the one the bug arrived through.
