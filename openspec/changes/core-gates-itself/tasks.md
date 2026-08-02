## 1. Establish the RED baseline

- [ ] 1.1 Build a throwaway fixture under `$TMPDIR` containing a change whose spec delta does not parse, and confirm `openspec validate --all` goes red on it. This is the only condition gate 2.0.0 blocks on, so it is the only condition worth testing.
- [ ] 1.2 With that fixture in place, run the gate three ways — a `PreToolUse` payload, `--pre-commit`, and `--ci` — and record the exit codes. Expect non-zero from each.
- [ ] 1.3 Prove the baseline is genuinely RED for *core*: with the fixture in place, confirm no surface in core reacts. No `.claude/hooks/`, no `.git/hooks/pre-commit`, no gate job in `.github/workflows/`. Record the three absences as the starting evidence.
- [ ] 1.4 Record the four fail-open exits already measured on the real repo (malformed stdin, missing gate, no active change, edit to an `openspec/` artifact) so a regression in any of them is detectable later.

## 2. The CI floor

- [ ] 2.1 Copy `reference-implementations/openspec-change-gate/hooks/openspec-gate.ci.yml` to `.github/workflows/openspec-gate.yml`, changing only the two artifact paths: score and run `reference-implementations/openspec-change-gate/openspec-change-gate.sh` instead of `bin/openspec-change-gate.sh`.
- [ ] 2.2 Diff the result against the template and confirm the two path substitutions are the *only* divergence. Any third difference is either a template bug to fix upstream or an unjustified fork.
- [ ] 2.3 Add a comment in the workflow naming Decision 1 and why core's resolution is inverted relative to every consuming project. A reader who knows the shim will otherwise read this as a mistake.
- [ ] 2.4 Verify the two steps locally before pushing: `tools/change-gate-conformance.sh` against the reference implementation (expect 71/71, exit 0), then the gate with `--ci` (expect exit 0).

## 3. The PreToolUse hook

- [ ] 3.1 Write `.claude/hooks/openspec-change-gate.sh` resolving core's working-tree reference implementation. Do not copy the project shim — its resolution order is the one Decision 1 rejects.
- [ ] 3.2 Preserve the shim's two non-obvious behaviours: `exec` the gate rather than sourcing it, and export `OPENSPEC_GATE_SELF=claude` so core's own reviews do not count toward the independence floor.
- [ ] 3.3 Keep the fail-open guard — if the resolved path is not executable, report on stderr and exit 0. A gate that hard-fails when tooling is absent brings every edit in the session down with it.
- [ ] 3.4 Create `.claude/settings.json` registering the hook on `PreToolUse` matcher `Edit|Write|MultiEdit|NotebookEdit`. Confirm it does not disturb the existing `settings.local.json` permissions block.
- [ ] 3.5 Re-run the section 1 fixture against the installed hook and confirm it now blocks (exit 2) where step 1.3 recorded no reaction at all.
- [ ] 3.6 Re-run the four fail-open cases from 1.4 against the installed hook and confirm every one still exits 0.

## 4. The pre-commit floor

- [ ] 4.1 Write `tools/install-core-git-hooks.sh`, which writes `.git/hooks/pre-commit` resolving core's working-tree gate and `exec`ing it with `--pre-commit`.
- [ ] 4.2 Make it idempotent: running it twice leaves the same file, and the second run says so rather than reporting a fresh install.
- [ ] 4.3 Make it refuse rather than overwrite when it finds a `pre-commit` hook it did not write, reporting what it found and exiting non-zero. Detect authorship by a marker line the installer writes, not by comparing whole-file bytes, so a hook edited by hand is still recognised as core's and still refused.
- [ ] 4.4 Run it in this checkout and confirm `.git/hooks/pre-commit` is executable.
- [ ] 4.5 Test all three installer paths: fresh clone, second run, and foreign hook present. Use a throwaway clone under `$TMPDIR` — do not test the refusal path by planting a foreign hook in the real checkout.
- [ ] 4.6 Confirm the installed hook blocks a commit under the section 1 fixture and allows one on the clean tree.

## 5. Record

- [ ] 5.1 Write `adrs/0028-core-gates-itself.md` in core's existing ADR format, carrying Decision 1 (resolve own source), Decision 3 (installer over `core.hooksPath`) and the alternatives rejected for each.
- [ ] 5.2 Document core's inverted resolution order where core's other gate behaviour is documented, per the spec delta's requirement that the inversion be recorded. Check `docs/WORKFLOW.md` for the right slot.
- [ ] 5.3 State the disclosed limits in the same place: the `PreToolUse` self-gating property, the ungated-clone case, and the accepted fleet divergence.

## 6. Verify the change as a whole

- [ ] 6.1 Run `openspec validate --all` and confirm it stays green with this change open.
- [ ] 6.2 Confirm the seven artifacts named in the hosts' `core-vendor.manifest` are byte-identical to `main` — this change must not invalidate any host pin. Compare against the four manifests, not just one.
- [ ] 6.3 Confirm nothing under `reference-implementations/` was modified. It is consumed by this change, never edited.
- [ ] 6.4 Open the pull request and confirm the new CI job runs and passes on it — the first live proof the floor works.
- [ ] 6.5 Request the §07 Stage-2 independent code review. `openspec validate` is a spec check and does not discharge it.
- [ ] 6.6 Confirm no report of this change claims core is now fully self-gating: this installs the change gate only, and core still carries no other project hook.
