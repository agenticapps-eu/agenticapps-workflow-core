## 1. The defect, RED first

- [ ] 1.1 Add a test to `tools/project-hook-shim.test.sh`: a second unresolvable
      call within the same hour exits 1 **and** writes a non-empty first stderr
      line. Run it and record it RED against today's shim — the RED is the
      evidence that the test sees the defect, not that it compiles.
- [ ] 1.2 Add the invariant test: for every shim file under
      `reference-implementations/project-hooks/`, no path exits non-zero with
      empty stderr. Enumerate the paths rather than testing the one that
      motivated this — an unresolvable override, an unresolvable shared install,
      and a suppressed repeat of each.
- [ ] 1.3 `tdd=true` — commit both as `test(RED): …` before any implementation
      edit.

## 2. The fix in core

- [ ] 2.1 `shim-template.sh`: `report_rate_limited` emits a single line on the
      suppressed path instead of returning silently. The line names the hook,
      states the condition is unchanged, states the call was allowed, and refers
      to the full notice already made this hour.
- [ ] 2.2 `openspec-change-gate.shim.sh`: the same change to its own copy, with
      wording matching what that shim's unsuppressed report says (the gate's
      cost sentence differs from the template's).
- [ ] 2.3 Bump `# shim-contract:` to `1.2.0` in both files, and update the two
      in-body references to `shim-contract 1.1.0` in the report text.
- [ ] 2.4 Update the comment block above `report_rate_limited` in both files: it
      currently justifies the interval policy as reducing how often the operator
      is told, which the exit code takes back. State verbosity.
- [ ] 2.5 Run 1.1 and 1.2 GREEN. Commit as `feat(GREEN): …`.

## 3. Live verification, not just tests

- [ ] 3.1 Rename `~/.agenticapps/bin/database-sentinel.sh` away, clear the
      rate-limit marker, and make three consecutive matched calls in a repo
      carrying a 1.2.0 shim. Record all three exit codes and stderr.
- [ ] 3.2 Confirm call 2 and 3 render a notice with content rather than
      `No stderr output`. This is the defect's own reproduction, re-run — the
      only evidence that the fix reaches the surface the defect appeared on.
- [ ] 3.3 Restore the implementation and re-verify: benign call exit 0,
      `DROP TABLE` exit 2. Restoring is part of the task, not cleanup after it.

## 4. Spec and documentation

- [ ] 4.1 `openspec validate --all` green on the delta.
- [ ] 4.2 Update the README's propagation note: it says three repos in one
      family; the instrument says five across two. Correct the claim and say why
      it was wrong — the count came from the family that was looked at, not from
      `FLEET`.
- [ ] 4.3 Update the README's rate-limit finding, which currently records the
      defect as open, to record it as fixed and name the version that fixes it.

## 5. Propagate — the two repos already carrying shims

- [ ] 5.1 `agenticapps-dashboard`: re-issue three shims at 1.2.0, own branch and
      PR. Verify with `project-hook-conformance.sh` against that repo alone.
- [ ] 5.2 `cparx`: the same. Note in the PR that this is cross-family work
      authorized for this change specifically.

## 6. Propagate — the five repos carrying inlined copies

Each repo: convert three hooks to 1.2.0 shims, update the `settings.json`
matcher to `Bash|Edit|Write|MultiEdit`, own branch and PR, and state in the PR
body that `migrations/*` edits stop being blocked and the
`Migration 0009 not yet applied` stub stops being injected.

- [ ] 6.1 `agenticapps-roadmap`
- [ ] 6.2 `callbot`
- [ ] 6.3 `fbc-platform`
- [ ] 6.4 `fx-signal-agent`
- [ ] 6.5 `agents-task-viewer` — `database-sentinel` and `openspec-change-gate`
      only.
- [ ] 6.6 `agents-task-viewer`: relocate the 26-line opt-out rationale from
      `normalize-claude-md.sh` into that repo's `CLAUDE.md`, preserving the
      2026-07-21 date and the warning against re-registering the hook.
- [ ] 6.7 `agents-task-viewer`: delete `normalize-claude-md.sh`. Depends on 6.6
      — the file is the only record of why the opt-out exists, so deleting it
      first destroys the reason and invites the next migration to undo it.

## 7. Verify the propagation as a whole

- [ ] 7.1 `tools/project-hook-conformance.sh --fleet ~/Sourcecode` reports 0
      findings, down from 30. Paste the output.
- [ ] 7.2 In each converted repo, show the hook resolving: one benign matched
      call, exit 0. The instrument proves propagation, not that anything works.
- [ ] 7.3 Record which binders implement which profile, as the modified
      requirement obliges — seven published-resolution, one self-hosting in core.

## 8. Close

- [ ] 8.1 Stage-2 independent code review in a cleared session.
- [ ] 8.2 `openspec archive shim-suppressed-report-and-fleet-propagation -y`,
      then ship. Two separate acts.
