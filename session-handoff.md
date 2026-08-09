# Session Handoff — 2026-08-09 (twenty-fifth session)

Both core PRs are merged, `init-project.sh` 1.1.0 is published, and the
retirement question 3.9b left open has an answer with a reviewed plan behind it.
No code was deleted — the session ends at the gate, deliberately.

## Accomplished

- **#93 and #94 merged.** #94 was stacked on #93, so squashing #93 made #94
  conflict; rebased with `--onto origin/main 084638b` to replay only its own two
  commits. `check-shims.test.sh` 9/9 after the rebase.
- **`init-project.sh` 1.1.0 published.** `~/.agenticapps/bin/` held 1.0.0, so
  anyone running the published copy got an unenrolled project. `install.sh
  --check` now reports all four artifacts current.
- **`projects-bind-not-copy` gained the retirement decision**, folded into all
  four planning artifacts plus a `workflow-installation` delta. `openspec
  validate --all` green.
- **Step 2b run, two vendors, both REQUEST-CHANGES.** `REVIEWS-2.md`. The round
  falsified two of the eight removals and one of the design's risk claims.
- **fbc-platform diagnosed but not touched** — another session is live in it.

## Decisions

- **The publish half retires; the bind half stays.** Only one lost its subject.
  `install-project-hooks.sh` with an empty `ARTIFACTS` dies at line 122 — verified
  by running it against a comments-only declaration in a scratch HOME, publishing
  nothing. `check-shims.sh` reads four declaration files and exits 65 without the
  template.
- **Six requirements retire, two relocate — corrected mid-session.** I had all
  eight retiring. Codex showed `install.sh:check_artifact()` *is* "currency judged
  against an authority checkout" and `install-shared-artifact.sh`'s downgrade
  refusal *is* "the version marker is compared". Their subject stopped being a
  project hook; their behaviour did not. Moved to `workflow-installation` — deleting
  them would have unspecified working code.
- **The manifest is deleted, not repaired.** Its only reader is
  `tools/install.test.sh`; `install-shared-artifact.sh` writes none for the four
  surviving artifacts; and it never expires rows, so after a full rewrite at 22:58
  on 08-08 it attested `normalize-claude-md.sh 1.0.1`, with a digest, for a path
  holding no file.
- **What retiring it costs is durable attestation, NOT drift detection.** My risk
  paragraph said a hand-edited artifact would become undetectable. False —
  `check_artifact()` runs `cmp -s` before any version comparison and names the
  same-version-different-bytes case. Gemini asserted the opposite of codex here and
  the code settled it against gemini.
- **Tombstones withdrawn.** The delta required `SHIMMED-HOOKS` to be empty *and*
  to carry machine-readable tombstones. Nothing implemented them, `decl()` strips
  comments so it already parses to zero entries, and the resolution discriminator
  suffices because `openspec-change-gate.sh` survives in `~/.agenticapps/bin/`.
- **`install.sh` is no longer a non-goal.** `proposal.md:251` and `design.md:33`
  promised it would not change while 3.13d–e change it.

## Files modified

- `openspec/changes/projects-bind-not-copy/proposal.md` — "Retired Capability
  surface"; the install.sh non-goal reversed
- `openspec/changes/projects-bind-not-copy/design.md` — the publisher/checker
  decision, three manifest measurements, two corrected risks
- `openspec/changes/projects-bind-not-copy/tasks.md` — group 3.13 (eleven tasks),
  3.9b answered
- `.../specs/project-hook-binding/spec.md` — 8 REMOVED (2 marked relocated), 2
  MODIFIED, tombstones withdrawn, the "reassigned" contradiction fixed
- `.../specs/workflow-installation/spec.md` — the two relocated requirements
- `.../REVIEWS-2.md` — new, round 2
- `~/.agenticapps/bin/init-project.sh` — 1.0.0 → 1.1.0 (machine, not repo)

## Next session: start here

Execute **group 3.13** on `feat/retire-the-project-hook-publisher` (pushed, two
commits, no PR yet). Start with **3.13a**, and start with it RED: assert that
`install.sh` carries no `PROJHOOKS` delegation, that a run writes no manifest
under `$HOME/.agenticapps/`, and that it prints no *"published and attested the
project-hook set"* line — all three fail against today's tree, unlike the
`--check` assertion the task originally named, which was already true and could
never have failed. Then 3.13b–e delete and unwire, 3.13f rewrites
`shim-template.sh:8-9` (it still tells readers the implementation is published by
the installer being deleted) and bumps its `# shim-contract:` marker, and 3.13g
removes the machine copies after grepping `~/Sourcecode` and `~/.agenticapps` for
readers of `manifest.tsv` outside this repo. The bind-half suites passing at 3.13f
is the proof the split was drawn in the right place.

## Open questions

1. **`check-shims.sh` has no reverse pass at all** — its only loop iterates the
   declaration, so over an empty one it examines nothing. Tasks 2b.1–2b.5 are all
   open. Keeping the bind half is a bet on those landing; if they are not going to
   land, the split's justification weakens and the whole capability is worth
   re-examining. Neither reviewer found this.
2. **fbc-platform #143 is red and the fix belongs to the other session.** Root
   `deno.lock` still records `husky@9.1.7` and `lint-staged@17.3.0` after
   `package.json` dropped them; CI runs `deno test --frozen`. Fix is
   `deno install --frozen=false` committed to `chore/drop-vendored-workflow-copies`.
   Its working tree also holds nineteen deletions already committed on #143 —
   they should be restored, not committed onto the AGE-507 branch. **Two lockfiles
   in that repo; only `pnpm-lock.yaml` was regenerated on 08-08.**
3. **An ADR accepting the unmitigated destructive-SQL loss** — codex asked for one
   with an owner. The decision is recorded on 3.9d but an ADR is its right home.
4. Nothing intercepts destructive SQL, in any repository, on any host. Unchanged.
5. **`normalize-claude-md` still has no implementation anywhere** while
   `project-hook-binding/spec.md` names it as a live shim in seven places. The
   phantom manifest row was its only trace on the machine and goes at 3.13g.
6. `.planning/` survives in cparx, fbc-platform, fx-signal-agent (task 6.2).
7. callbot and fx-signal-agent instruction files collapsed but not thinned (~24k).
8. Tasks 3.1 / 3b.1 / 3b.4 of `one-enforcement-floor` satisfied but unticked;
   3.0a–3.0g describe a mechanism with no reason to exist.
9. `fleet-carries-only-current` task 0.1 gated on `projects-bind-not-copy` being
   archived — implemented, not archived. Recheck.
10. Delete the transitional binder: `reference-implementations/global-floor/` and
    `tools/global-floor-bind.test.sh`. Its finding worth keeping first: a repository
    refused at the preflight is never enrolled, so binding the floor silences the
    hook the refusal said it was keeping.
11. Three credentials outlived their file in `agenticapps-roadmap`'s `.env`.
12. `claude-workflow` cannot be deleted safely — 11 commits on no remote.

## Mistakes worth not repeating

- **I offered a file list that would have deleted the checker.** The first
  retirement option I put up included `SHIMMED-HOOKS`, `FLEET`, `OPT-OUTS` and
  `shim-template.sh` — all four read by `check-shims.sh`, merged hours earlier in
  #94. Caught before anything was deleted, by reading the checker instead of
  trusting the category "the subsystem".
- **Two reviewers made opposite claims about the same function and I nearly took
  the wrong one.** Gemini's finding arrived first and read as plausible. Reading
  `check_artifact()` was eight seconds of work and reversed it.
- **A category is not a subject.** "The publish/shim/check subsystem" was one
  phrase covering two things with different fates, and it was mine — from the
  previous handoff. The phrase survived four sessions before anyone asked which
  half had a reader.
