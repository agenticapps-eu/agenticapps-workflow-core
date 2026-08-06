# Session Handoff — 2026-08-06 (seventh session)

**Next action: decide between re-running the plan reviewers and doing the real
`--host auto` run.** Both are described at the bottom. Nothing is blocked.

Phase 3 is built, committed (`a0a0264`, branch `feat/one-skills-payload`) and
green. It has not been run for real on this machine.

## Accomplished

- **Scope split, on Donald's decision.** `core-installer-one-entry-point` is now
  the host side only. `--project` is deferred to its own change: two review
  rounds established it is a project-shim installer *plus* an instruction-file
  provisioner core does not have. `install-core-git-hooks.sh` is core-only by
  design (ADR-0028, it resolves `<repo>/reference-implementations/…`), and
  nothing in this repo writes the canonical instruction-file markers —
  `tools/agents-md-conformance.sh` checks them and writes nothing. Both verified,
  not taken on the reviewers' word.
- **All four planning artifacts revised** to the split scope, and every accepted
  round-two finding applied.
- **`install.sh` written** — 249 executable lines, four modes.
- **`tools/install.test.sh`** — 57 cases, all green. Per-case temp `HOME` and git
  repo, plus a canary over the real home.
- **`hosts/codex/openspec-change-gate-adapter.sh`** and
  **`hosts/opencode/openspec-change-gate.ts`** — carried forward and corrected.
- **`docs/evidence/install-check-before.md`** — the before state (task 8.3).
- Memory written: `workflow-runs-on-one-machine`.

## Decisions

- **`--project` deferred** — it is not one flag; see above. It also opens a
  capability window: this change removes the `setup-agenticapps-workflow`
  binding whose replacement is `--project`. Accepted deliberately; the
  alternative is keeping a binding into an archived checkout, which is the exact
  condition the change exists to end. **Consequence: `--project` must land before
  the archived checkouts are deleted in Phase 5b** — alongside the codex adapter
  and opencode plugin, which were also sourced from them.
- **Line budget 200 → 250, by spec amendment**, with the accounting recorded in
  the requirement: round two added 57 lines of behaviour the 200 predates
  (byte-wise currency 13, the archived sweep 14, `wire_opencode` 10,
  preserved-copy rules 8, the second opt-in 12). Without them it measures ~189.
  The budget worked — it forced the accounting instead of letting the file grow.
- **Two opt-ins, not one** — `--accept-host-config` and `--replace-unrecognised`.
  One grants "edit the JSON your editor reads", the other "delete a directory
  that may hold work". A single flag collects both on one keystroke.
- **Discovery now acts, not just detects.** The design originally said the
  manifest acts and discovery detects, because discovery "cannot decide between
  replace and remove". `--check` on the real machine found **26 archived
  bindings; the hand-written manifest named 8.** The 18 missed are host-prefixed
  copies of upstream skills (`codex-cso`, `opencode-qa`, …) — the vendoring the
  workflow itself forbids. The objection is answered by *the presence of a
  host-neutral equivalent*: strip the host prefix and any `-audit` suffix, rebind
  if such a skill is installed, remove if not. The named manifest shrank to one
  entry: `agenticapps-workflow`, a copied **directory** a symlink sweep cannot
  see (and the second of the two files that both claimed to be the trigger skill).
- **Removal is scoped to what this workflow installed.** `is_archived` matches
  only the four workflow repos, so an independently installed binding is
  invisible to the sweep. Proof on this machine: `observability` sits in
  `~/.codex/skills` beside twelve workflow bindings and is untouched. There is a
  test for this because nothing else enforces it.
- **A directory-level symlink was rejected** (Donald's suggestion, and a good
  one). `~/.claude/skills` holds 98 entries and core owns 2; linking the
  directory would delete the other 96. Per-entry links also buy per-entry consent
  and recovery.
- Both carried-forward host artefacts claimed the gate requires "REVIEWS.md >= 2
  reviewers" — untrue since gate 2.0.0, and the opencode one said it in the
  message thrown at a **blocked operator**. Both corrected; a test greps for the
  claim in executable text (comments may quote it to correct it).

## Files modified

- `install.sh` — new, 249 executable lines
- `hosts/codex/openspec-change-gate-adapter.sh`, `hosts/opencode/openspec-change-gate.ts` — new
- `tools/install.test.sh` — new, 57 cases
- `docs/evidence/install-check-before.md` — new
- `openspec/changes/core-installer-one-entry-point/{proposal,design,tasks}.md` and
  `specs/workflow-installation/spec.md` — all revised

## Next session: start here

Read `openspec/changes/core-installer-one-entry-point/tasks.md` — 65 of 69 done.
Then pick one of two: **(a)** re-run the plan reviewers, because `REVIEWS.md`
describes artifacts that have changed substantially since it was written (a spec
amendment and the sweep redesign) and its `reviewed_artifacts_sha` matches
nothing on disk; or **(b)** do the real run — tasks 8.4–8.6. That is
`./install.sh --host auto --accept-host-config --replace-unrecognised`, which
rebinds 13 bindings, removes 7, and edits `~/.claude/settings.json` and
`~/.codex/hooks.json`. Everything it replaces is preserved at
`<path>.pre-install.<n>` and the run prints the restore command. (a) is the
smaller risk and the workflow's own discipline; (b) is what unblocks Phase 5b.
Remaining after that: 8.7 code review on the diff, 8.8 `cso`, 9.1 open the
`--project` follow-up change.

## Open questions

1. **`codex-design-critique` and `codex-spec-review` get removed, not rebound** —
   no host-neutral equivalent is installed. Their content survives in the
   archived checkout until Phase 5b. If either should keep working on codex it
   needs an explicit alias or a move into `core/skills/`. **No mapping was
   guessed**: binding `design-critique` to `design-review` because the names
   rhyme is how a skill silently does the wrong thing.
2. **`.planning/` is back** — untracked, holding `skill-observations/*.jsonl`,
   written per session by something. The global CLAUDE.md says the directory was
   deleted fleet-wide on 2026-08-05, so either a hook needs updating or the rule
   does. Left uncommitted; `.gitignore` untouched.
3. **`~/.agenticapps/manifest.tsv` still carries a `normalize-claude-md.sh` row**
   for an artifact retired in PR #87. **The claim that the first real run drops
   it was wrong** — corrected 2026-08-06 after round three (codex, confirmed by
   reading the code, not taken on the reviewer's word).
   `install-project-hooks.sh:216` builds a `KEEP` list from every manifest row
   whose artifact is *not* in the run's declared set and re-emits those rows
   first in the full rewrite, with a comment saying it is deliberate: "Dropping
   them would make every partial run look like a fresh install of a smaller
   set." `normalize-claude-md.sh` is not in the declared set, so its row
   survives every run. Removing it needs explicit pruning, which is a change to
   the attesting installer and therefore its own decision — this change removes
   no software it did not install, and that rule is why the row is still there.
4. **Phase 5b cannot be a wholesale `tools/` delete.** Its 7,765-line figure is
   the current total of `tools/*.sh`, which includes `install-core-git-hooks.sh`
   (238 lines) — a delegation target of this change — and now `install.test.sh`.
5. **PRs #87 and #88 are still open and unmerged**, as are the five fleet PRs
   listed in the previous handoff. This work sits on top of them.
6. The gate prints a non-blocking `NOTE` that it cannot verify this change's
   `REVIEWS.md` (trailer-absent). Expected; resolved by (a) above.
