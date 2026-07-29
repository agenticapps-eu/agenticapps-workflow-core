## 1. Establish the two canonical implementations

- [ ] 1.1 Create `reference-implementations/project-hooks/` with a README stating the shim contract, resolution order, and the fail-posture-by-class rule
- [ ] 1.2 Diff all three `normalize-claude-md.sh` variants; adopt `agenticapps-dashboard`'s as canonical and fold in any genuine addition from `agents-task-viewer`'s 314-line variant (resolves design open question 1)
- [ ] 1.3 Diff all three `database-sentinel.sh` variants and reconcile to the superset: `callbot`'s `.env` wildcard plus its `.env.example`/`.env.template` allowance, plus `MultiEdit` handling
- [ ] 1.4 Verify the reconciled `database-sentinel` still blocks `DROP`/`TRUNCATE TABLE` and `DELETE FROM` without a `WHERE`, unchanged
- [ ] 1.5 Confirm no variant contained a protection the reconciled version drops — enumerate every matched path and tool across all three before finalising

## 2. Author the shims

- [ ] 2.1 Write the shim template following `openspec-change-gate.sh`: override → `~/.agenticapps/bin/` → `<repo>/bin/`, host self-identification, `exec`
- [ ] 2.2 `tdd="true"` — failing test: an unresolvable `database-sentinel` shim blocks and names the installer in its message
- [ ] 2.3 `tdd="true"` — implement fail-closed resolution for the security class; make the test pass
- [ ] 2.4 `tdd="true"` — failing test: an unresolvable `normalize-claude-md` shim exits 0
- [ ] 2.5 `tdd="true"` — implement fail-open resolution for the cosmetic class; make the test pass
- [ ] 2.6 Test that an explicit override wins over the shared install for both hooks
- [ ] 2.7 Confirm each shim is behaviour-free beyond resolution, self-identification and `exec`

## 3. Publish and verify before touching any project

- [ ] 3.1 Add a multi-artifact install step so both implementations can be provisioned in one invocation, rather than one artifact per call
- [ ] 3.2 Publish both to `~/.agenticapps/bin/` and confirm they are present and executable
- [ ] 3.3 Verify each published implementation behaves identically to the project copy it replaces, tested against the repo whose copy was canonical
- [ ] 3.4 Verify the reconciled `database-sentinel` against a repo that previously used the enumerated `.env` list, confirming it now catches a novel suffix

## 4. Roll out per project — one repo at a time, verified before the next

Each repo: replace two copies with shims, delete five hooks, remove all five from `settings.json`.

- [ ] 4.1 `agenticapps-dashboard`
- [ ] 4.2 `agenticapps-roadmap`
- [ ] 4.3 `agents-task-viewer` — shim `normalize-claude-md` but leave it **unregistered**, preserving the deliberate 2026-07-21 opt-out
- [ ] 4.4 `callbot` — confirm a `.tsx` edit is no longer blocked
- [ ] 4.5 `cparx`
- [ ] 4.6 `fbc-platform` — confirm a `.tsx` edit is no longer blocked
- [ ] 4.7 `fx-signal-agent`
- [ ] 4.8 Confirm no project references any deleted hook outside `settings.json`
- [ ] 4.9 Remove the deleted hooks' bats tests, after confirming they cover only the deleted features (resolves design open question 2)

## 5. Verify the change as a whole

- [ ] 5.1 Confirm each surviving hook is byte-identical across all seven projects
- [ ] 5.2 Confirm `~/.agenticapps/bin/` holds exactly one implementation per shimmed hook
- [ ] 5.3 Confirm every project now carries exactly three hooks
- [ ] 5.4 Confirm no hook writes to `.planning/` in any project
- [ ] 5.5 Measure the net line change and record it against the proposal's ~3,470-line estimate
- [ ] 5.6 Run `openspec validate --all` green
- [ ] 5.7 Run `openspec-change-gate.sh --ci` green
- [ ] 5.8 Stage-2 independent code review per §07

## 6. Record

- [ ] 6.1 Write the ADR: shim-vs-symlink-vs-package, the fail-posture split and its cost, and why a hook's filename is not evidence of a §02 binding
- [ ] 6.2 Update `docs/PLAN-lightweight-fleet.md` marking step 3a done, and record that §02's GSD vocabulary is the step 5 root cause
- [ ] 6.3 Confirm the two deferred advisory prompts remain recorded in the proposal for future pickup
