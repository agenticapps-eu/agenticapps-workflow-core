The step-by-step detail — exact file contents, test code, and expected output at
each RED and GREEN point — is in
`docs/superpowers/plans/2026-08-04-executable-migration-format.md`. Every group
is `tdd="true"`: the failing test is written and observed failing before
implementation, per §17.

Groups 3 and 5 exist because the Stage 2 review found the first draft's
threshold read frontmatter rather than the filename, and its runner never
linted. Both undermined the design's central claim. See `design.md`, "What the
Stage 2 review changed".

## 1. Extractor

- [ ] 1.1 Write `test-fixtures/conformant.md` — two steps, all five roles on step 1, and one un-annotated `bash` fence as a tripwire that must never execute
- [ ] 1.2 Write `tools/migration-runner.test.sh` with the extractor assertions, including that step 1 is not confused with a step 10 and that a numbering gap does not merge steps
- [ ] 1.3 Run it and observe the assertions fail (`extract.sh` does not exist)
- [ ] 1.4 Write `extract.sh` — `mr_steps`, `mr_roles`, `mr_block`, plus the CLI. Bound each step at **the next `### Step ` heading of any number**, never at `N+1`. Enforce the exact info-string grammar: literal `bash`, whitespace, `role=`, role name, optional trailing whitespace, nothing else
- [ ] 1.5 Port the delimiter guard and literal-prefix matching from codex's `extract_step_block()`
- [ ] 1.6 Run, observe green, commit

## 2. Linter — structural rules L1, L3, L5

- [ ] 2.1 Build `bad-l1-missing-rollback.md`, `bad-l3-duplicate-apply.md`, `bad-l5-role-on-yaml.md`, and `bad-infostring-extra-key.md` per the plan's fixture table
- [ ] 2.2 Append the structural-rule assertions, including that a step with no `verify` passes
- [ ] 2.3 Run and observe them fail
- [ ] 2.4 Write `lint-migration.sh` implementing L1 (exactly one each of check/precondition/apply/rollback, at most one verify), L3 (no duplicates), L5 (`role=` only on `bash` fences, and only in the exact grammar)
- [ ] 2.5 Run, observe green, commit

## 3. Linter — L2, L4, and the filename-keyed threshold

- [ ] 3.1 Write `reference-implementations/migration-runner/THRESHOLDS` — one row per host: claude-workflow 0035, codex-workflow 0016, opencode-workflow 0012, pi-agentic-apps-workflow 0011
- [ ] 3.2 Build `bad-l2-wrong-heading.md`, `bad-l4-typo-role.md`, `bad-threshold-no-frontmatter.md`, `bad-no-frontmatter-id.md` (in scope by filename, no `id:` line at all), `bad-optin-below-threshold.md` (below threshold, declares `migration_format: executable`, omits a role), and `bad-nonconsecutive-steps.md`
- [ ] 3.3 Append the assertions for L2, L4, and the threshold gate
- [ ] 3.4 Run and observe them fail — **confirm `bad-l4-typo-role.md` currently exits 0**, since a misspelled role is indistinguishable from illustration until L4 exists. That observation is the justification for the rule
- [ ] 3.5 Derive the migration ID **from the filename basename**, never from frontmatter. `bad-no-frontmatter-id.md` is the regression guard: deleting the `id:` line must not evade the linter
- [ ] 3.6 Cross-check the filename ID against frontmatter `migration_format`: at or above threshold without the declaration is a violation; below threshold *with* it is judged anyway; any other value is a violation
- [ ] 3.7 Add the consecutive-numbering check and the single-pass L2/L4 scan that tracks the most recent `**Label:**` heading
- [ ] 3.8 Run, observe green, commit

## 4. Runner — dispatch, dry-run, and exit-code semantics

- [ ] 4.1 Append assertions for the happy path, the second run reporting skipped, dry-run printing apply source and writing nothing, a `check` exiting 2 aborting rather than re-applying, and a failing `precondition` aborting even with a terminal attached
- [ ] 4.2 Run and observe them fail
- [ ] 4.3 Write `run-migration.sh` — argument parsing, TTY-derived default policy, the per-step check/precondition/apply/verify loop, and the dry-run branch
- [ ] 4.4 Implement the three-valued `check` contract: 0 applied, 1 not applied, anything else aborts
- [ ] 4.5 Make a `precondition` failure hard-abort regardless of TTY, reproducing its stderr verbatim
- [ ] 4.6 Run, observe green, commit

## 5. Runner — refuse a migration that would do nothing

- [ ] 5.1 Build `all-illustration.md` — in scope by filename, `migration_format: executable`, one step whose only fences carry no `role=`
- [ ] 5.2 Append assertions: the runner exits non-zero on a migration that fails the linter, exits non-zero on `all-illustration.md`, exits non-zero on a zero-step document, and in every case executes nothing
- [ ] 5.3 Run and observe them fail — the runner currently exits 0 on all three, which is the defect the Stage 2 review found
- [ ] 5.4 Make the runner lint before executing and abort on any violation, on zero steps, and on any step yielding no `apply` block
- [ ] 5.5 Run, observe green, commit

## 6. Runner — A2 failure policy

- [ ] 6.1 Build `failing-apply.md` (step 2's apply exits 7), `failing-verify.md` (apply succeeds, verify exits 1), and `failing-precondition.md` (two-option remediation on stderr, exit 3)
- [ ] 6.2 Append assertions — the load-bearing ones being that step 1's work **survives** a step 2 failure, that a failing `verify` does not mark its step applied, and that skip **continues to the next step** rather than exiting
- [ ] 6.3 Run and observe them fail
- [ ] 6.4 Implement `fail_policy()` for `apply` and `verify` failures only: TTY prompts; non-TTY aborts reporting which steps applied and rolling back nothing; skip continues and records partial; rollback runs applied steps in **reverse** document order and never rolls back the failed step
- [ ] 6.5 Run, observe green, commit

## 7. Rollback fixtures — the blocks the runner never reaches

- [ ] 7.1 Append assertions that execute each `rollback` block directly against its own step's post-apply state, including that step 2's rollback is surgical and leaves step 1 intact
- [ ] 7.2 Run — these should pass immediately; a failure means a fixture's rollback is wrong, which is the rot this group exists to catch
- [ ] 7.3 Commit

## 8. Revise spec §08

- [x] 8.1 Bump `spec_version` 0.9.1 → 0.10.0
- [x] 8.2 Add the "Executable form" subsection — role/heading table, exact info-string grammar, un-annotated fences as illustration, unrecognised roles rejected, `role=` only on `bash`, consecutive step numbering and the next-step-heading boundary
- [x] 8.3 Add the threshold rules — ID from filename, frontmatter cross-check, declaration may add to scope but never remove
- [x] 8.4 Add the requirement that a runner lints first and refuses a migration yielding no executable work
- [x] 8.5 Amend the atomicity contract — `precondition` always hard-aborts; the policy governs `apply` and `verify`; TTY prompts; non-TTY aborts and rolls back nothing; the override is a SHALL, not a SHOULD; rollback runs in reverse order and excludes the failed step
- [x] 8.6 Add the `check`/`precondition` non-mutation obligation, and correct the dry-run promise from "prints the diff" to "prints the source"
- [x] 8.7 Add the diagnostics warning — verbatim stderr reaches CI logs, so blocks must not emit secrets or personal data
- [x] 8.8 Add the Conformance MUST that a host runs the format linter
- [x] 8.9 Run `openspec validate --all` and commit

## 9. CI and documentation

- [ ] 9.1 Write `reference-implementations/migration-runner/README.md` — the role table, why L4 exists, why the runner lints first, the A2 policy and its rollback consequence, the THRESHOLDS file, and the note that the installer will publish these under `# migration-runner-version:` arbitration
- [ ] 9.2 Add the `Test the migration runner` step to `.github/workflows/openspec-gate.yml`. It runs the **test suite**, which drives the linter against fixtures and asserts their expected verdicts. It MUST NOT lint `test-fixtures/` broadly — most of those files fail the linter by design, so a broad scan would make the gate self-fail
- [ ] 9.3 Note in the README that dry-run is **not** a safe preview of an untrusted migration: it still executes `check` and `precondition`, and the non-mutation rule binds honest authors, not hostile ones
- [ ] 9.4 Run the full local suite — test file, linter against the conformant fixture, `openspec validate --all`, and the change gate `--ci`
- [ ] 9.5 Commit
