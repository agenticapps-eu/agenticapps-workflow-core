The step-by-step detail — exact file contents, test code, and expected output at
each RED and GREEN point — is in
`docs/superpowers/plans/2026-08-04-executable-migration-format.md`. Its eight
tasks map one-to-one onto the eight groups below. Every group is `tdd="true"`:
the failing test is written and observed failing before implementation, per §17.

## 1. Extractor

- [ ] 1.1 Write `test-fixtures/conformant.md` — two steps, all five roles on step 1, and one un-annotated `bash` fence as a tripwire that must never execute
- [ ] 1.2 Write `tools/migration-runner.test.sh` with the 8 extractor assertions
- [ ] 1.3 Run it and observe all 8 fail (`extract.sh` does not exist)
- [ ] 1.4 Write `reference-implementations/migration-runner/extract.sh` — `mr_steps`, `mr_roles`, `mr_block`, plus the CLI; port the delimiter guard and literal-prefix matching from codex's `extract_step_block()`
- [ ] 1.5 Run and observe `TOTAL: 8 passed, 0 failed`
- [ ] 1.6 Commit

## 2. Linter — structural rules L1, L3, L5

- [ ] 2.1 Build `bad-l1-missing-rollback.md`, `bad-l3-duplicate-apply.md`, `bad-l5-role-on-yaml.md` per the plan's fixture table — one stated delta each from `conformant.md`, nothing else varied
- [ ] 2.2 Append the 8 structural-rule assertions to the test file
- [ ] 2.3 Run and observe the 8 new ones fail
- [ ] 2.4 Write `lint-migration.sh` implementing L1 (required roles present), L3 (no duplicates), L5 (`role=` only on `bash` fences)
- [ ] 2.5 Run and observe `TOTAL: 16 passed, 0 failed`
- [ ] 2.6 Commit

## 3. Linter — L2 agreement, L4 unknown roles, ID threshold

- [ ] 3.1 Build `bad-l2-wrong-heading.md`, `bad-l4-typo-role.md`, `bad-threshold-no-frontmatter.md`
- [ ] 3.2 Append the 9 assertions covering L2, L4, and the threshold gate
- [ ] 3.3 Run and observe them fail — **confirm `bad-l4-typo-role.md` currently exits 0**, since a misspelled role is indistinguishable from illustration until L4 exists. That observation is the justification for the rule
- [ ] 3.4 Add `--threshold N` argument parsing, the below-threshold skip, and the `migration_format` cross-check
- [ ] 3.5 Add the single-pass L2/L4 scan that tracks the most recent `**Label:**` heading
- [ ] 3.6 Run and observe `TOTAL: 25 passed, 0 failed`
- [ ] 3.7 Commit

## 4. Runner — happy path and dry-run

- [ ] 4.1 Append the 8 happy-path assertions (applies in order, tripwire never executes, second run reports skipped and changes nothing) and the 3 dry-run assertions (prints apply source, writes nothing, exits 0)
- [ ] 4.2 Run and observe the 11 new ones fail
- [ ] 4.3 Write `run-migration.sh` — argument parsing, TTY-derived default policy, `run_block`, `has_role`, the per-step check/precondition/apply/verify loop, and the dry-run branch
- [ ] 4.4 Run and observe `TOTAL: 36 passed, 0 failed`
- [ ] 4.5 Commit

## 5. Runner — A2 failure policy and verbatim pre-condition stderr

- [ ] 5.1 Build `failing-apply.md` (step 2's apply exits 7) and `failing-precondition.md` (a two-option remediation message on stderr, exit 3)
- [ ] 5.2 Append the 9 assertions — the load-bearing one being that step 1's `fixture.txt` **survives** a step 2 failure
- [ ] 5.3 Run and observe them fail
- [ ] 5.4 Implement `fail_policy()` so the `abort` arm's output matches the assertions exactly, including the literal sentence about nothing being rolled back
- [ ] 5.5 Run and observe `TOTAL: 45 passed, 0 failed`
- [ ] 5.6 Commit

## 6. Rollback fixtures — the blocks the runner never reaches

- [ ] 6.1 Append the 6 assertions that execute each `rollback` block directly against its own step's post-apply state, including that step 2's rollback is surgical and leaves step 1 intact
- [ ] 6.2 Run and observe `TOTAL: 51 passed, 0 failed` — these should pass immediately; a failure means a fixture's rollback is wrong, which is the rot this group exists to catch
- [ ] 6.3 Commit

## 7. Revise spec §08

- [ ] 7.1 Bump `spec_version` 0.9.1 → 0.10.0
- [ ] 7.2 Add the "Executable form" subsection — the role/heading table, un-annotated fences as illustration, unrecognised roles rejected, the threshold declaration, `role=` only on `bash`
- [ ] 7.3 Amend the atomicity contract per A2 — TTY prompts, non-TTY aborts and rolls back nothing, consent defined, `--on-failure` as a SHOULD
- [ ] 7.4 Correct the dry-run promise from "prints the diff" to "prints the source"
- [ ] 7.5 Add the Conformance MUST that a host runs the format linter
- [ ] 7.6 Run `openspec validate --all` and commit

## 8. CI and documentation

- [ ] 8.1 Write `reference-implementations/migration-runner/README.md` — the role table, why L4 exists, the A2 policy and its rollback consequence, the four per-host thresholds, and the note that the installer will publish these under `# migration-runner-version:` arbitration
- [ ] 8.2 Add the `Test the migration runner` step to `.github/workflows/openspec-gate.yml`
- [ ] 8.3 Run the full local suite — test file, linter against the conformant fixture, `openspec validate --all`, and the change gate `--ci`
- [ ] 8.4 Commit
