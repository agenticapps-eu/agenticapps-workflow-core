## 1. The defect, RED first

- [x] 1.1 Add a test to `tools/project-hook-shim.test.sh`: a second unresolvable
      call within the same hour exits 1 **and** writes a non-empty first stderr
      line. Run it and record it RED against today's shim — the RED is the
      evidence that the test sees the defect, not that it compiles.
- [x] 1.2 Add the invariant test: for every shim file under
      `reference-implementations/project-hooks/`, no **pre-`exec`** path exits
      non-zero with empty stderr. Enumerate the paths rather than testing the one
      that motivated this — an unresolvable override, an unresolvable shared
      install, and a suppressed repeat of each. Post-`exec` exits belong to the
      implementation and are out of scope (codex 3).
- [x] 1.3 Add the marker-failure test: with the state directory unwritable, every
      call reports in full and none is suppressed (opencode 4).
- [x] 1.4 Add the ordering test: the report is written before the marker, so a
      run that dies after reporting leaves a marker consistent with a notice that
      was actually emitted (codex 4).
- [x] 1.5 Extend the invariant test to core's own binder,
      `.claude/hooks/openspec-change-gate.sh`. It is excluded from `--fleet` by
      design, so it must be named explicitly or it is tested by nothing (codex 1).
      Expect RED: it exits 0 today.
- [x] 1.6 Add the inverse anti-pattern test: no shim path exits **0** having
      written to stderr. Exit 0 discards stderr, so that shape warns nobody — it
      is the defect found in core's binder, and only a test keeps it from
      returning (gemini round 2).
- [x] 1.7 Assert the suppressed line's **content**, not merely its existence: the
      four mandatory fields, and that it differs from the full report's first
      line. A test satisfied by any non-empty string would pass a materially
      non-conformant message (codex round 2).
- [x] 1.8 `tdd=true` — commit all of the above as `test(RED): …` before any
      implementation edit.

## 2. The fix in core

- [x] 2.1 `shim-template.sh`: `report_rate_limited` emits a single line on the
      suppressed path instead of returning silently. The line names the hook,
      states the condition is unchanged, states the call was allowed, and refers
      to the full notice already made this hour.
- [x] 2.2 `openspec-change-gate.shim.sh`: the same change to its own copy, with
      wording matching what that shim's unsuppressed report says (the gate's
      cost sentence differs from the template's).
- [x] 2.3 Bump `# shim-contract:` to `1.2.0` in both files, and update the two
      in-body references to `shim-contract 1.1.0` in the report text.
- [x] 2.4 Update the comment block above `report_rate_limited` in both files: it
      currently justifies the interval policy as reducing how often the operator
      is told, which the exit code takes back. State verbosity.
- [x] 2.5 Reorder `report_rate_limited` to report **then** write the marker, and
      make a failed marker write leave the next call reporting in full.
- [x] 2.6 Core's self-hosting binder, `.claude/hooks/openspec-change-gate.sh`:
      replace `printf … >&2; exit 0` with a report and a non-blocking error code.
      This is a live violation of the fail-open-and-report rule in the repository
      that publishes it — `spec.md:611-615` calls exit 0 with a stderr warning
      "warns nobody", and `spec.md:251-253` puts core's copy in scope for that
      rule while exempting it only from the resolution-order clauses.
- [x] 2.7 Bump core's binder marker to 1.2.0.
- [x] 2.8 Run 1.1–1.5 GREEN. Commit as `feat(GREEN): …`.

## 2b. The instrument, because it cannot currently see two of this change's claims

- [x] 2b.1 RED first, in `tools/project-hook-conformance.test.sh`: a project
      missing a declared hook's shim entirely is reported. Today
      `project-hook-conformance.sh:195` and `:265` are `[ -f "$shim" ] || continue`
      on both axes, so an absent shim contributes nothing and the total reads
      clean (codex round 2). Same `|| continue` shape as the currency defect
      repaired on 2026-08-04 — second occurrence, so fix the shape here rather
      than only the instance.
- [x] 2b.2 Report the absence on both axes, and add a declaration so a deliberate
      opt-out is distinguishable from a deletion. `agents-task-viewer` /
      `normalize-claude-md` is the live opt-out and is the test case.
- [x] 2b.3 RED first: the check reads each project's `settings.json` matcher for
      each shimmed hook and reports a mismatch against the implementation's
      declared tool coverage. Verified absent today — `:306-309` opens
      `settings.json` only for override env vectors (gemini + opencode).
- [x] 2b.4 Make 2b.3 GREEN, and confirm it catches a `database-sentinel` entry
      missing `MultiEdit` **and** a gate entry missing `NotebookEdit`. Without
      the second case the check would license the regression codex found in the
      rollout instruction.
- [x] 2b.5 Re-run `--fleet` and record the new finding count. It will rise before
      it falls: the instrument now sees absences it previously skipped.

## 3. Live verification, not just tests

- [x] 3.1 Rename `~/.agenticapps/bin/database-sentinel.sh` away, clear the
      rate-limit marker, and make three consecutive matched calls in a repo
      carrying a 1.2.0 shim. Record all three exit codes and stderr.
      **Done with one stated deviation**: the implementation was NOT renamed —
      a second session was live in `agenticapps-dashboard` and would have been
      put on the fail-open path for the duration. `HOME` was pointed at a tree
      of the same shape with an empty `.agenticapps/bin/` instead, which reaches
      the identical branch (`SHARED="$HOME/.agenticapps/bin/$HOOK.sh"`) and
      clears the marker by construction. Recorded in `PROPAGATION-EVIDENCE.md`
      with what it does not cover.
- [x] 3.2 Confirm call 2 and 3 render a notice with content rather than
      `No stderr output`. This is the defect's own reproduction, re-run — the
      only evidence that the fix reaches the surface the defect appeared on.
      Both render one line saying the failure is a repeat; the 1.1.0 render
      under the same conditions produces zero stderr on calls 2 and 3 at the
      same exit code, which is the defect itself.
- [x] 3.3 Restore the implementation and re-verify: benign call exit 0,
      `DROP TABLE` exit 2. Restoring is part of the task, not cleanup after it.
      Nothing was renamed, so the real environment was re-checked rather than
      restored: shared bin present, benign call exit 0, `DROP TABLE` exit 2.

## 4. Spec and documentation

- [x] 4.1 `openspec validate --all` green on the delta.
- [x] 4.2 Update the README's propagation note: it says three repos in one
      family; the instrument says five across two. Correct the claim and say why
      it was wrong — the count came from the family that was looked at, not from
      `FLEET`.
- [x] 4.3 Update the README's rate-limit finding, which currently records the
      defect as open, to record it as fixed and name the version that fixes it.
- [x] 4.4 **Close the contract table's open row.** 4.1–4.3 shipped in core PR 1,
      while 1.2.0 was genuinely still in flight, so the revision table recorded
      its own row as `in progress` — true when written, fiction the moment the
      seventh fleet PR merged. Now 21, and the profile split 1.2.0 is required to
      state is stated per hook rather than inherited from 1.1.0's paragraph.
      The twenty were **counted out of the checkouts** after the merges, not
      carried forward: three each in six repos, two in `agents-task-viewer`,
      plus core's own binder read from core. Assuming the count is the specific
      mistake this change spent a session finding.

## 5. Propagate — the two repos already carrying shims

- [x] 5.1 `agenticapps-dashboard`: re-issue three shims at 1.2.0, own branch and
      PR. Verify with `project-hook-conformance.sh` against that repo alone.
      PR #99. Six findings against that repo → zero.
- [x] 5.2 `cparx`: the same. Note in the PR that this is cross-family work
      authorized for this change specifically. PR #124, and the PR body says so
      in its first line.

Both repos' shims were compared against a clean 1.1.0 render before being
replaced and were byte-identical to it, so neither PR carried away local
behaviour — the check that makes a blind re-render safe. Neither `settings.json`
was touched: all six registrations already covered their declared matcher sets.

## 6. Propagate — the five repos carrying inlined copies

> **This heading is wrong, and finding out how was the most useful thing in the
> group.** None of the five carried inlined copies. All seven repos were already
> at 1.1.0 shims with correct matcher coverage on `origin/main`; the inlined
> copies existed only in the **stale local checkouts on this machine**, six of
> which were behind their remotes by up to eleven commits.
> `project-hook-conformance.sh --fleet` reads working trees and says nothing
> about how old they are, so it described this laptop and called it the fleet.
> The full account is in `PROPAGATION-EVIDENCE.md`; the instrument fix is
> deliberately NOT taken here and wants its own change.
>
> Consequence for the instruction below: **no repo needed a matcher edit**, and
> no PR could truthfully say `migrations/*` stops being blocked or the
> `Migration 0009` stub stops being injected — both had already stopped when the
> repos were shimmed at 1.1.0. Each of the five needed the same 1.1.0 → 1.2.0
> re-version as group 5.

Each repo: convert three hooks to 1.2.0 shims, own branch and PR, and state in
the PR body that `migrations/*` edits stop being blocked and the
`Migration 0009 not yet applied` stub stops being injected.

**The matcher edit is scoped to the `database-sentinel` entry only** (codex 5).
Each repo's `settings.json` carries several matchers; the gate's is
`Edit|Write|MultiEdit|NotebookEdit`, and applying `Bash|Edit|Write|MultiEdit`
across the file would strip the gate's `NotebookEdit` coverage. Change one entry,
and diff the file to prove only that entry moved.

- [x] 6.1 `agenticapps-roadmap` — PR #13. Opened against a stale checkout with
      claims that were false of the repo, then corrected in place: merged with
      current `main`, conflicts resolved to it, body rewritten to name the
      mistake. Net diff is now the same re-version as the other six.
- [x] 6.2 `callbot` — PR #100.
- [x] 6.3 `fbc-platform` — PR #105, prepared in a temporary worktree cut from
      `origin/main`: that checkout sits on an in-progress design-system branch
      with uncommitted work that must not be disturbed.
- [x] 6.4 `fx-signal-agent` — PR #120.
- [x] 6.5 `agents-task-viewer` — `database-sentinel` and `openspec-change-gate`
      only. Before converting the gate, verify the shared install resolves on
      this machine: that repo's current shim falls back to a repo-local
      `bin/openspec-change-gate.sh` (17k, verified present) and the contract's
      two-candidate order deliberately drops it (codex 2).
      PR #18. The premise is stale in the same way: upstream that shim is already
      the 1.1.0 two-candidate shim, so it has not fallen back to the repo-local
      copy since 2026-08-02.
- [x] 6.5a `agents-task-viewer`: dispose of the now-orphaned
      `bin/openspec-change-gate.sh` explicitly — removed, or kept with a note
      saying what still invokes it. A 17k copy that nothing calls and no
      instrument reports is the drift the shim contract exists to end.
      **Not orphaned — the second branch taken.** No instrument reports it, but
      CI invokes it: `openspec-gate.yml` runs `change-gate-conformance.sh`
      against it, `bin/openspec-gate-ci.sh` fails without it, and
      `core-vendor.manifest` pins its sha256 (ADR-0023). CI has no
      `~/.agenticapps` to resolve from. Kept, with `bin/README.md` saying so —
      beside the file, not inside it, because editing a pinned file breaks
      the pin.
- [x] 6.6 `agents-task-viewer`: relocate the 26-line opt-out rationale from
      `normalize-claude-md.sh` into an **ADR in that repo**, preserving the
      2026-07-21 date and the warning against re-registering the hook, and link
      it from `CLAUDE.md`. An ADR rather than prose in `CLAUDE.md` because
      `CLAUDE.md` is rewritten by tooling and trimmed by hand, and this rationale
      has already survived ~3 manual reverts by being hard to delete accidentally
      (gemini round 2). Not `settings.json` — it is strict JSON and cannot carry
      the comment.
      **Recovered rather than relocated**: upstream deleted the file in
      `ac13485` before this ran, so the rationale existed only in
      `git show ac13485^`. Now ADR 0009, linked from `CLAUDE.md`'s hand-written
      preamble — outside every GSD block, so the hook it declines to run could
      not rewrite the link even if re-registered.
- [x] 6.6a Add the opt-out to the declaration introduced in 2b.2, so the
      instrument reports it as declared rather than skipping it. Already present
      in `OPT-OUTS`; verified reported as an opt-out on both the marker and the
      matcher axis.
- [x] 6.7 `agents-task-viewer`: delete `normalize-claude-md.sh`. Depends on 6.6
      — the file is the only record of why the opt-out exists, so deleting it
      first destroys the reason and invites the next migration to undo it.
      **Already deleted upstream in `ac13485`, ahead of 6.6** — the dependency
      this task states was violated before the task ran, which is why 6.6 became
      a recovery from git history rather than a move.

## 7. Verify the propagation as a whole

- [x] 7.1 `tools/project-hook-conformance.sh --fleet ~/Sourcecode` reports 0
      findings, down from 30. Paste the output.
      **0, down from 46** — the stated 30 was never the baseline. Output in
      `PROPAGATION-EVIDENCE.md`, along with the intermediate reading of 7, which
      is the more informative one: after the merges but before the last checkout
      was brought current, every remaining finding belonged to the single tree
      that had not moved. The pull is part of the task, not cleanup after it —
      the scan reads working trees, so skipping it would have re-measured the
      same stale files the baseline did.
- [x] 7.2 Score core's binder **explicitly**, by passing
      `agenticapps-workflow-core` as a positional argument, and report its version
      beside the fleet's. `--fleet` excludes core by design, so 7.1 alone cannot
      cover it and must not be cited as if it did (codex 1).
      Core reports **33**, composed in `PROPAGATION-EVIDENCE.md`: 4 from the two
      hooks core does not bind, 29 override vectors from core's own tests, ADRs
      and archived specs — which name those variables because core is where the
      mechanism is specified. Its one real binder reads `current (1.2.0)`.
- [x] 7.2a State what 7.2 does **not** establish. Positionally the tool checks
      core's marker and then exempts byte identity as out of profile
      (`:268`) — it never exercises the fail-open path. The behavioural evidence
      for core is task 1.5's test and task 3's live run, and the change SHALL cite
      those rather than let a marker check stand in for conformance (codex
      round 2). Stated. The line reference has moved: the exemption is now
      `project-hook-conformance.sh:323`.
- [x] 7.3 Assert the matcher change per repo: `database-sentinel`'s entry reads
      `Bash|Edit|Write|MultiEdit` **and** the gate's still reads
      `Edit|Write|MultiEdit|NotebookEdit`. No instrument reads matchers at fleet
      scope — verified: `project-hook-conformance.sh:306-309` reads
      `settings.json` only for override env vectors — so this check is manual and
      its absence from the tooling is recorded, not papered over (opencode 3).
      **The parenthetical is out of date and the check is no longer manual**: the
      matcher axis added in group 2b reads matchers at fleet scope, which is why
      it could report four narrow registrations in the baseline. Asserted for all
      seven repos through that axis — every `database-sentinel` entry covers
      `Bash|Edit|Write|MultiEdit`, every gate entry still covers
      `Edit|Write|MultiEdit|NotebookEdit`, and `agents-task-viewer`'s
      `normalize-claude-md` is reported as a declared opt-out rather than a gap.
- [x] 7.4 In each converted repo, show the hook resolving: one benign matched
      call, exit 0. The instrument proves propagation, not that anything works.
      Done in all seven, on each branch's working tree — which is the right place
      for it, since the question is whether the shim resolves, not whether the PR
      merged. `DROP TABLE` through `database-sentinel` was run alongside each,
      returning exit 2: exit 0 alone is also what a hook that does nothing
      returns. **Re-run across all seven merged checkouts afterwards**, because a
      hook that resolves on a branch says nothing about the tree the operator
      actually works in. Benign 0, `DROP TABLE` 2, `migrations/*` 0 everywhere.
- [x] 7.5 Record which binders implement which profile, as the modified
      requirement obliges — seven published-resolution, one self-hosting in core.
      Recorded in `PROPAGATION-EVIDENCE.md` per hook, because the summary is only
      true of the gate: 7 published-resolution + 1 self-hosting for
      `openspec-change-gate`, 7 + 0 for `database-sentinel`, 6 + 0 for
      `normalize-claude-md`. Never two self-hosting binders for one hook.

## 8. Close

The change spans two core PRs, and saying so removes the inconsistency a reviewer
found: core must merge **first** so the other seven have an authority to be
compared against, but the propagation evidence only exists **after** they merge.
One PR cannot be both (codex round 2).

- [x] 8.1 Core PR 1 — implementation, spec delta, tests, instrument. Merged
      before any fleet repo's PR is opened. Merged as `8e7fcd4` (PR #73), and
      the first fleet PR was opened after it.
- [x] 8.2 The seven fleet PRs (groups 5 and 6). All seven merged (squash):
      dashboard #99, cparx #124, roadmap #13, callbot #100, fbc-platform #105,
      fx-signal-agent #120, agents-task-viewer #18. `fx-signal-agent` merged with
      two red checks — `pnpm-audit` and `gitleaks`, both failing on `main` since
      2026-07-29, neither reachable from a three-file hook diff. Named here
      rather than left for a reader to rediscover.
- [ ] 8.3 Core PR 2 — the propagation evidence from group 7, the README
      corrections from group 4, and the archive. This is the PR the change is
      archived in, because archiving before the evidence exists would fold a
      delta whose central claim is still unverified.
- [ ] 8.4 Stage-2 independent code review in a cleared session, against core PR 1
      before it merges and against core PR 2 before it merges. Two reviews, not
      one — PR 2 carries the claim that the fleet was actually reached, which is
      the claim most worth an independent reader.
  - [x] 8.4a **Core PR 1 reviewed** in a cleared session. Four findings, each
        reproduced before it was recorded; `CODE-REVIEW.md` holds the review and
        the reproductions. All four fixed in group 9. The half of 8.4 that
        remains is PR 2's review, so 8.4 stays open.

## 9. The Stage-2 findings against PR 1

Every one of these is the change's own principle applied to the change. Two are
in-diff; one is a spec gap that is why the first had nothing to violate; one is
pre-existing and is finding 6's second half.

- [x] 9.1 RED first, all four, committed as `test(RED): …` before any
      implementation edit — shim suite 60/4, conformance suite 55/5, and the new
      sibling assertions failing against a mutated gate shim that the suite had
      passed 56/56.
- [x] 9.2 **The matcher axis reported a narrowed registration and said nothing
      about a missing one.** `seen.get(hook, [])` is empty for a hook no entry
      names, so the loop never ran: three current, byte-identical shims wired to
      nothing scored `OK — no known vector found`, exit 0. Absence-reads-as-clean,
      in the axis added to remove absence-reads-as-clean. Now a finding, with
      declared opt-outs exempt.
- [x] 9.3 **The sibling shim was asserted by nothing.** `$BIN/openspec-change-gate.sh`
      is created in the gate-shim section and never removed, so `$GATE_SHIM`
      never reached the unresolvable path where the 1.2.0 rate limiter lives.
      Its suppressed line, four fields, and difference from the full report are
      now driven directly — verified by mutation, which the suite previously
      could not see.
- [x] 9.4 **Finding 6 survived on candidate 2.** `-x` alone is true of any
      searchable directory; the override branch was hardened at 1.1.0 and
      candidate 2 kept the bare test eleven lines below the comment explaining
      the bug. Both shims now require an executable regular file on both
      candidates, and report an occupied path as occupied rather than as absent.
- [x] 9.5 **The matcher axis shipped with no requirement.** `MATCHERS`,
      `report_matchers` and the `REGISTRATION` finding class had no delta text,
      which is why 9.2 violated nothing. The base requirement *Registration
      matches the implementation's tool coverage* is now MODIFIED to specify the
      same four properties the marker requirement specifies of itself — format,
      authority, comparison, check — plus the absent case and the opt-out
      exemption.
- [x] 9.6 GREEN: 64/64 shim, 60/60 conformance, 12/12 wrapper, `openspec
      validate --all` green.
- [ ] 8.5 `openspec archive shim-suppressed-report-and-fleet-propagation -y`,
      then ship. Two separate acts.
