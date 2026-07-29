## 1. Establish canonical implementations in core

- [ ] 1.1 Create `reference-implementations/project-hooks/` with a README stating the shim contract, the resolution order, and the fail-open rule
- [ ] 1.2 Diff `normalize-claude-md.sh` across all three variants; adopt `agenticapps-dashboard`'s as canonical and fold in any genuine addition from `agents-task-viewer`'s 314-line variant (resolves design open question 1)
- [ ] 1.3 Diff and reconcile the three `database-sentinel.sh` variants into one canonical implementation, preserving the `DROP`/`TRUNCATE`, `DELETE`-without-`WHERE` and `.env` protections unchanged
- [ ] 1.4 Reconcile the two `skill-router-log.sh` variants into one canonical implementation
- [ ] 1.5 Adopt `session-bootstrap.sh` as canonical (single existing version)
- [ ] 1.6 `tdd="true"` — write the failing test for `design-shotgun-gate`'s three-state behaviour: allow when `.planning/current-phase/` is absent, block when the directory exists without the sentinel, allow when the sentinel exists
- [ ] 1.7 `tdd="true"` — implement the fail-open fix in canonical `design-shotgun-gate.sh` and make the test pass
- [ ] 1.8 Add a harness covering all five implementations, including a fail-open case per hook (no override, no shared bin, no repo `bin/` → exit 0)

## 2. Publish and verify before touching any project

- [ ] 2.1 Extend `install-shared-artifact.sh` to publish the five implementations to `~/.agenticapps/bin/`, respecting the existing version arbiter
- [ ] 2.2 Publish and confirm all five are present and executable in `~/.agenticapps/bin/`
- [ ] 2.3 Verify each published implementation behaves identically to the project copy it replaces, tested against the repo whose copy was canonical
- [ ] 2.4 Verify the `design-shotgun-gate` fix specifically against `callbot` (no `current-phase` dir → allow) and `cparx` (sentinel present → allow, unchanged)

## 3. Author the shim

- [ ] 3.1 Write a shim template following `openspec-change-gate.sh`: override → `~/.agenticapps/bin/` → `<repo>/bin/`, fail open, `exec`
- [ ] 3.2 Confirm the shim is behaviour-free beyond resolution, host self-identification and `exec`
- [ ] 3.3 Verify shims are byte-identical across projects for a given hook, so the spec's comparison scenario holds

## 4. Roll out per project — one repo at a time, verified before the next

- [ ] 4.1 `agenticapps-dashboard` — replace five copies with shims, delete `phase-sentinel.sh` and `architecture-audit-check.sh`, remove both from `settings.json`
- [ ] 4.2 `agenticapps-roadmap` — same
- [ ] 4.3 `agents-task-viewer` — same
- [ ] 4.4 `callbot` — same; confirm a `.tsx` edit is no longer blocked
- [ ] 4.5 `cparx` — same; confirm `design-shotgun-passed` still gates as before
- [ ] 4.6 `fbc-platform` — same; confirm a `.tsx` edit is no longer blocked
- [ ] 4.7 `fx-signal-agent` — same
- [ ] 4.8 Confirm no project references the two deleted hooks anywhere outside `settings.json` (resolves design open question 2)

## 5. Verify the change as a whole

- [ ] 5.1 Confirm each of the five hooks is byte-identical across all seven projects
- [ ] 5.2 Confirm `~/.agenticapps/bin/` holds exactly one implementation per hook
- [ ] 5.3 Measure the net line change across the seven projects and record it against the proposal's ~2,500-line estimate
- [ ] 5.4 Run `openspec validate --all` green
- [ ] 5.5 Run `openspec-change-gate.sh --ci` green
- [ ] 5.6 Stage-2 independent code review per §07 and the workflow's `requesting-code-review` gate

## 6. Record

- [ ] 6.1 Write the ADR covering the shim-vs-symlink-vs-package decision and the fail-open posture trade-off
- [ ] 6.2 Update `docs/PLAN-lightweight-fleet.md` marking step 3a done and noting that §02's GSD vocabulary is the step 5 root cause
- [ ] 6.3 Confirm the two deferred advisory prompts are recorded in the proposal for future pickup
