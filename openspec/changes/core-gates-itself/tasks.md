## 1. Establish the RED baseline

- [ ] 1.1 Build a throwaway fixture under `$TMPDIR` containing a change whose spec delta does not parse, and confirm `openspec validate --all` goes red on it. This is the only condition gate 2.0.0 blocks on, so it is the only condition worth testing.
- [ ] 1.2 With that fixture in place, run the gate three ways — a `PreToolUse` payload, `--pre-commit`, and `--ci` — and record the exit codes. Expect non-zero from each.
- [ ] 1.3 Prove the baseline is genuinely RED for *core*: with the fixture in place, confirm no surface in core reacts. No `.claude/hooks/`, no `.git/hooks/pre-commit`, no gate job in `.github/workflows/`. Record the three absences as the starting evidence.
- [ ] 1.4 Record the four fail-open exits already measured on the real repo (malformed stdin, missing gate, no active change, edit to an `openspec/` artifact) so a regression in any of them is detectable later.

## 2. The CI floor

- [ ] 2.1 Copy `reference-implementations/openspec-change-gate/hooks/openspec-gate.ci.yml` to `.github/workflows/openspec-gate.yml`, changing only the two artifact paths: score and run `reference-implementations/openspec-change-gate/openspec-change-gate.sh` instead of `bin/openspec-change-gate.sh`.
- [ ] 2.2 Diff the result against the template and confirm the two path substitutions are the *only* divergence. Any third difference is either a template bug to fix upstream or an unjustified fork.
- [ ] 2.3 Add a comment in the workflow naming Decision 1 and why core's resolution is inverted relative to every consuming project. A reader who knows the shim will otherwise read this as a mistake.
- [ ] 2.4 Assert a minimum scored-row count in the job and fail below it (floor: 71 today). Without this a PR that guts the harness yields a green job while certifying a drifting gate — the missing-target check only covers zero-of-zero, not a row count falling from 71 to 3.
- [ ] 2.5 Constrain what the job executes: declare read-only `contents` permission, set `persist-credentials: false` on checkout, and pin `@fission-ai/openspec` to 1.6.0 — the version core validated against. An unpinned global install lets an upstream release change the verdict for an unchanged revision.
- [ ] 2.6 Verify the steps locally before pushing: `tools/change-gate-conformance.sh` against the reference implementation (expect 71/71, exit 0), then the gate with `--ci` (expect exit 0).
- [ ] 2.7 Confirm the job fails closed where CI must: point it at an absent gate and an absent harness and confirm non-zero. CI fail-closed is the deliberate inverse of the hook's fail-open, and the two are easy to conflate.
- [ ] 2.8 Record — do not fix — that core's published template at `reference-implementations/openspec-change-gate/hooks/openspec-gate.ci.yml` carries the same three supply-chain weaknesses. No host pins it (verified against all four manifests), so it is safely fixable, but editing it changes what every host scaffolds and belongs in its own change.

## 3. The PreToolUse hook

- [ ] 3.1 Write `.claude/hooks/openspec-change-gate.sh` resolving core's working-tree reference implementation. Do not copy the project shim — its resolution order is the one Decision 1 rejects.
- [ ] 3.2 Preserve the shim's two non-obvious behaviours: `exec` the gate rather than sourcing it, and export `OPENSPEC_GATE_SELF=claude` so core's own reviews do not count toward the independence floor.
- [ ] 3.3 Keep the fail-open guard — if the resolved path is not executable, report on stderr and exit 0. A gate that hard-fails when tooling is absent brings every edit in the session down with it.
- [ ] 3.4 Create `.claude/settings.json` registering the hook on `PreToolUse` matcher `Edit|Write|MultiEdit|NotebookEdit`. Confirm it does not disturb the existing `settings.local.json` permissions block.
- [ ] 3.5 Re-run the section 1 fixture against the installed hook and confirm it now blocks (exit 2) where step 1.3 recorded no reaction at all.
- [ ] 3.6 Re-run the four fail-open cases from 1.4 against the installed hook and confirm every one still exits 0.
- [ ] 3.7 Prove the resolution *preference*, not merely that resolution works. Place an executable gate at `~/.agenticapps/bin/openspec-change-gate.sh` that behaves differently — have it write a sentinel — and confirm neither the hook nor the pre-commit hook executes it. Absence of the shared install does not test preference order, which is the whole of Decision 1. Restore the real shared install afterwards.
- [ ] 3.8 Confirm and record the missing-`openspec`-CLI case is fail-CLOSED: with a change active and the binary off `PATH`, the gate returns 2. Do not "fix" it — it is inherited §18 behaviour — but confirm the documented limits say so, since core almost always has a change open.
- [ ] 3.9 Confirm the `Bash` bypass concretely: modify a file with `sed -i` and verify the hook never fires. Record it as a boundary of the matcher, not a defect.

## 4. The pre-commit floor

- [ ] 4.1 Write `tools/install-core-git-hooks.sh`, resolving the destination with `git rev-parse --git-path hooks` and writing a `pre-commit` that `exec`s core's working-tree gate with `--pre-commit`. Never write a literal `.git/hooks/` path: in a linked worktree `.git` is a file and that path does not exist.
- [ ] 4.2 Detect `core.hooksPath`. When it is set, report the conflict and exit non-zero rather than writing a hook git will silently ignore — an ignored hook is worse than none, because it looks installed.
- [ ] 4.3 Implement the four marker outcomes explicitly: absent → install; marked and current → no-op, reported as such; marked and stale → update in place, reported as an upgrade; unmarked → refuse, report what was found, exit non-zero. Byte equality is deliberately not the test — it would make every revised hook permanently foreign and the gate unadvanceable.
- [ ] 4.4 Run it in this checkout and confirm the resolved hooks path now holds an executable `pre-commit`.
- [ ] 4.5 Test all five installer paths in throwaway clones under `$TMPDIR`: fresh, second run, stale-marked, foreign-unmarked, and `core.hooksPath` set. Do not plant a foreign hook in the real checkout.
- [ ] 4.6 Test the worktree path for real: `git worktree add` a throwaway, run the installer inside it, and confirm it resolves to the main checkout's hooks directory and says so. This is the case that would have shipped broken.
- [ ] 4.7 Confirm the installed hook blocks a commit under the section 1 fixture and allows one on the clean tree.

## 5. Record

- [ ] 5.1 Write `adrs/0028-core-gates-itself.md` in core's existing ADR format, carrying Decision 1 (resolve own source), Decision 3 (installer over `core.hooksPath`) and the alternatives rejected for each.
- [ ] 5.2 Document core's inverted resolution order where core's other gate behaviour is documented, per the spec delta's requirement that the inversion be recorded. Check `docs/WORKFLOW.md` for the right slot.
- [ ] 5.3 State the disclosed limits in the same place: the `PreToolUse` self-gating property, the ungated-clone case, and the accepted fleet divergence.

## 6. Verify the change as a whole

- [ ] 6.1 Run `openspec validate --all` and confirm it stays green with this change open.
- [ ] 6.2 Confirm this change modifies none of the files any host pins. Read all four manifests, which do not agree: `claude-workflow` pins seven, the other three pin five each (no `run-plan-review.sh`, no `install-shared-artifact.sh`). Assert what is checkable from inside core — that none of them is edited here — not a claim about host pin state, which core cannot verify.
- [ ] 6.3 Confirm nothing under `reference-implementations/` was modified. It is consumed by this change, never edited.
- [ ] 6.4 Open the pull request and confirm the new CI job runs and passes on it — the first live proof the floor works.
- [ ] 6.5 Request the §07 Stage-2 independent code review. `openspec validate` is a spec check and does not discharge it.
- [ ] 6.6 Confirm no report of this change claims core is now fully self-gating: this installs the change gate only, and core still carries no other project hook.
- [ ] 6.7 Confirm no surface — spec, ADR, workflow comment, PR body or handoff — calls the CI job an enforced floor. Core's `main` has no branch protection and no rulesets, so a failing check does not prevent a merge. The job reports.
- [ ] 6.8 Re-run the plan review after these revisions. The three REQUEST-CHANGES verdicts describe the pre-revision text, and the gate reports a review as stale once the artifacts change. Whatever the new verdicts are, record them rather than merging on a stale green.
