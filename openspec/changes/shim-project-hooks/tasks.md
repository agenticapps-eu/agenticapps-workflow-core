## 1. Establish the two canonical implementations

- [ ] 1.1 Create `reference-implementations/project-hooks/` with a README stating the shim contract, the two-candidate resolution order, the fail-open-and-warn rule, and `database-sentinel`'s coverage boundary
- [ ] 1.2 Diff all three `normalize-claude-md.sh` variants; adopt `agenticapps-dashboard`'s as canonical and fold in any genuine addition from `agents-task-viewer`'s 314-line variant (resolves design open question 1)
- [ ] 1.3 Diff all three `database-sentinel.sh` variants and reconcile to the superset: `callbot`'s `.env` wildcard plus its `.env.example`/`.env.template` allowance, plus `MultiEdit` handling
- [ ] 1.4 **Drop the `migrations/` clause** (`callbot` lines 57–67) from the canonical implementation — it gates on `.planning/current-phase/migrations-approved` and prints a remedy naming `/gsd-discuss-phase`, removed 2026-07-28
- [ ] 1.5 Verify against `callbot` that a `migrations/` edit is blocked before the change and allowed after — the defect is live, so the fix is demonstrable, not theoretical
- [ ] 1.6 Verify the reconciled `database-sentinel` still blocks `DROP`/`TRUNCATE TABLE` and `DELETE FROM` without a `WHERE`, unchanged
- [ ] 1.7 Confirm no variant contained a protection the reconciled version drops — enumerate every matched path and tool across all three before finalising
- [ ] 1.8 Audit both canonical implementations for any **other** check whose precondition no surviving command can satisfy, the failure class 1.4 belongs to
- [ ] 1.9 Document `database-sentinel`'s coverage boundary in the README: `Bash` can write `.env` directly, `psql -f` bypasses the SQL patterns, and the shared implementation is user-writable by anything running as this user

## 2. Author the shims

- [ ] 2.1 Write the shim template following `openspec-change-gate.sh`: override → `~/.agenticapps/bin/`, then `exec`. **Two candidates only** — no `<repo>/bin/` fallback. **Do not carry host self-identification into these two shims**: neither `normalize-claude-md` nor `database-sentinel` uses it, and it imitates a mechanism the companion change is retiring
- [ ] 2.2 `tdd="true"` — failing test: an unresolvable shim exits **1** (non-blocking error), not 0, so the transcript surfaces the first line of stderr. Exit 0 discards it and warns nobody
- [ ] 2.3 `tdd="true"` — implement fail-open-and-report resolution; make the test pass for both hooks
- [ ] 2.3a Verify empirically on the host in use that the message is actually visible to the operator — the whole fail-open trade rests on this, and it was assumed rather than checked until round 5
- [ ] 2.4 `tdd="true"` — failing test: with `database-sentinel` unresolvable, an ordinary `Bash` command and an ordinary source-file edit both proceed. This is the regression the fail-closed design would have caused across `Bash|Edit|Write`
- [ ] 2.5 Test that an explicit override wins over the shared install for both hooks
- [ ] 2.6 `tdd="true"` — failing test: an override set to a missing or non-executable path reports that specifically, **allows the call, and exits 1** — it neither falls through to the shared install nor blocks
- [ ] 2.7 Document each hook's override variable name alongside the hook, and state that the override is for testing and staged rollout rather than a production configuration
- [ ] 2.8 Confirm each shim is behaviour-free beyond resolution, self-identification and `exec` — in particular that it inspects no tool payload, which is what makes narrow blocking impossible and fail-open necessary

## 3. Publish and verify before touching any project

- [ ] 3.1 Add a multi-artifact install step so both implementations can be provisioned in one invocation, rather than one artifact per call
- [ ] 3.2 `tdd="true"` — failing test: the installer reports failure when a shimmed implementation is absent or not executable. This verification is where the guarantee lives now that shims fail open
- [ ] 3.2a `tdd="true"` — failing test: the installer records provenance (version marker plus a content digest of what it published) and a later check reports an executed copy that has been hand-edited or replaced. "Present and executable" accepts stale and tampered code
- [ ] 3.2b Make multi-artifact publication atomic, or ordered so no intermediate state leaves a project binding a hook whose implementation is absent
- [ ] 3.3 Publish both to `~/.agenticapps/bin/` and confirm they are present and executable
- [ ] 3.4 Verify each published implementation behaves identically to the project copy it replaces, **apart from the dropped `migrations/` clause**, tested against the repo whose copy was canonical
- [ ] 3.5 Verify the reconciled `database-sentinel` against a repo that previously used the enumerated `.env` list, confirming it now catches a novel suffix

## 4. Roll out per project — one repo at a time, verified before the next

Each repo: replace two copies with shims, delete five hooks, remove all five from
`settings.json`, and **add `MultiEdit` to the `database-sentinel` matcher** —
required in every repo except `callbot`, which already has it.

- [ ] 4.1 `agenticapps-dashboard` — matcher `Bash|Edit|Write` → `Bash|Edit|Write|MultiEdit`
- [ ] 4.2 `agenticapps-roadmap` — same matcher change
- [ ] 4.3 `agents-task-viewer` — same matcher change. Decide and record: ship the `normalize-claude-md` shim unregistered, or ship no file at all. The 2026-07-21 opt-out says the hook must not be wired; it does not require an unwired file to exist, and a shim nothing invokes is a copy that can drift unnoticed. Preserve the opt-out either way
- [ ] 4.4 `callbot` — matcher already includes `MultiEdit`; confirm a `.tsx` edit is no longer blocked and that a `migrations/` edit now proceeds
- [ ] 4.5 `cparx` — same matcher change
- [ ] 4.6 `fbc-platform` — same matcher change; confirm a `.tsx` edit is no longer blocked
- [ ] 4.7 `fx-signal-agent` — same matcher change
- [ ] 4.8 Per repo, verify the matcher change actually delivers `MultiEdit` to the hook rather than assuming the edit took — and first confirm the host in use still provides a `MultiEdit` tool at all. It is absent from the current tool reference, so this coverage may be inert; if so, record it as inert rather than reporting a protection gained
- [ ] 4.9 Confirm no project references any deleted hook outside `settings.json`
- [ ] 4.10 Remove the deleted hooks' bats tests, after confirming they cover only the deleted features (resolves design open question 2)
- [ ] 4.11 Document where `skill-router-log`'s existing local logs live and offer an optional cleanup step. Deleting the writer does not delete what it wrote, and those files may hold repository paths and session activity

## 4b. Migrate the change-gate shim — it is not exempt

- [ ] 4b.1 Remove the `<repo>/bin/openspec-change-gate.sh` third resolution candidate from every project's shim
- [ ] 4b.2 `tdd="true"` — failing test: an unresolvable change-gate shim reports on stderr instead of exiting 0 silently
- [ ] 4b.3 Correct the `>= 2 independent reviewers` claim in the shim header, in all seven projects — sites the companion change's enumeration missed because this change had classified the file as untouched
- [ ] 4b.4 Leave `export OPENSPEC_GATE_SELF=...` alone: the companion change retires it as an identity source, and both changes editing that line would conflict. Confirm the two changes' edits to this file do not overlap before either lands
- [ ] 4b.5 Re-run the change-gate conformance harness after the shim edits
- [ ] 4b.6 Give each shim a contract version marker, so a project still running an older shim is detectable rather than discovered when it behaves unlike its siblings
- [ ] 4b.7 Record the residual non-conformance explicitly: until `track-and-conform-plan-review` lands, the gate shim still hardcodes an identity. This change fixes two of its three violations, not three

## 4c. Update the scaffolder, or the next project is born broken

- [ ] 4c.1 Update `claude-workflow/templates/.claude/hooks/` — delete the five, replace the two with shims, keep the migrated change-gate shim
- [ ] 4c.2 Update `claude-workflow/setup/snapshot/hooks/` identically
- [ ] 4c.3 Update `claude-workflow/setup/snapshot/claude-settings.json` — remove the five hooks' entries and add `MultiEdit` to the `database-sentinel` matcher
- [ ] 4c.4 Run `migrations/check-snapshot-parity.sh` and confirm it stays green
- [ ] 4c.5 Scaffold a throwaway project and verify it receives three hooks, current matchers, and none of the deleted five — the end-to-end check that this change is not undone by the next `/setup-agenticapps-workflow`
- [ ] 4c.6 Confirm the scaffolded project can edit a `.tsx` file and a `migrations/` file, the two defects a stale template would have reintroduced

## 5. Verify the change as a whole

- [ ] 5.0a For each of the five deletions, also record the **enforcement** check: confirm the hook neither checks a §02 gate's required evidence nor is depended on by anything that does. Binding, production and enforcement are three separate tests
- [ ] 5.0 For each of the five deletions, record the binding check that justifies it: name the §02 gates whose documented binding could plausibly be this hook, cite the host instruction file's actual binding, and confirm the hook writes none of that gate's required evidence. Filename absence is not the argument
- [ ] 5.1 Confirm each surviving hook is byte-identical across all seven projects
- [ ] 5.2 Confirm `~/.agenticapps/bin/` holds exactly one implementation per shimmed hook
- [ ] 5.3 Confirm every project now carries exactly three hooks
- [ ] 5.4 Confirm no hook writes to `.planning/` in any project
- [ ] 5.5 Measure the net line change and record it against the proposal's ~3,470-line estimate
- [ ] 5.6 Run `openspec validate --all` green
- [ ] 5.7 Run `openspec-change-gate.sh --ci` green
- [ ] 5.8 Stage-2 independent code review per §07

## 6. Record

- [ ] 6.1 Write the ADR: shim-vs-symlink-vs-package; why the fail-closed posture was adopted and then withdrawn once the matcher scope was measured; why a hook's filename is not evidence of a §02 binding **in either direction**; and why superset reconciliation must also test whether each inherited clause can still fire
- [ ] 6.2 Update `docs/PLAN-lightweight-fleet.md` marking step 3a done, and record that §02's GSD vocabulary is the step 5 root cause
- [ ] 6.3 Confirm the two deferred advisory prompts remain recorded in the proposal for future pickup
