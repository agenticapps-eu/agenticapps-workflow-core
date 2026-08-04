# Session Handoff — 2026-08-04 (second session of the day)

## Accomplished

- **PR #72 reviewed independently and merged.** This session was the cleared
  session for it. One defect found and fixed before merge: the propagation note
  cited `grep -c database-sentinel-version` returning 0 as what distinguished the
  three inlined copies from the shim — but the shim returns 0 for that grep too.
  The marker (`# <artifact>-version:`) lives in the *published* implementation,
  not in project hook files. Conclusion was right, evidence didn't hold.
- **A new change is open, planned, twice-reviewed and half-built:**
  `shim-suppressed-report-and-fleet-propagation`. **Core PR 1 is #73, open and
  green.**
- **The rate-limit defect is fixed.** A suppressed call emits one line and keeps
  `exit 1`. The rate limit governs verbosity — the only thing it can govern,
  since the exit code interrupts regardless.
- **Core's own binder was violating the rule this repo publishes, and is fixed.**
  `.claude/hooks/openspec-change-gate.sh` failed open with `printf … >&2; exit 0`
  from 1.1.0 until today. `spec.md:611-615` names that construction as warning
  nobody. `--fleet` excludes core by design, so no run of the instrument could
  ever have reported it.
- **The instrument gained two axes.** Absence is reported instead of skipped
  (`[ -f "$shim" ] || continue` on both axes), and registrations are checked
  against a declared `MATCHERS` set. `--fleet` findings went **30 → 46**.
- **Contract is at 1.2.0** across template, gate shim and core's binder, enforced
  by an existing parity assertion.

## Decisions

- **Bundle the propagation with the fix, and cross the family boundary** — both
  your calls, made explicitly. The change reaches all seven declared binders,
  four of which are in `factiv`. Recorded in the proposal as authorized for this
  change only, not standing permission.
- **Convert all three shimmed hooks in the five inlining repos**, not just
  `database-sentinel` — your call. Feasible because the README had already argued
  every reconciliation (differences 1–6); this applies them, it decides nothing new.
- **A suppressed call says one line rather than exiting 0.** Exiting 0 would
  deliver the interval policy's intent and make the rest of the hour an
  *unannounced* fail-open — the posture this capability rejects.
- **Two core PRs, not one.** Core must merge first so the seven have an authority
  to compare against; the propagation evidence only exists after they merge. One
  PR cannot be both. The archive belongs to PR 2.
- **Instrument gaps became work, not caveats.** Round 1 recorded them in
  `design.md`; both round-2 reviewers rejected that on the change's own terms.

## The theme, now at eleven — and the suite was in on it

9. **The acceptance criterion could not see the authority.** "`--fleet` reports 0"
   structurally excludes core. Following that exclusion found core's binder
   shipping the defect the spec names.
10. **`[ -f "$shim" ] || continue`, second occurrence.** Same shape as the
    currency-table defect repaired in #71 two days ago, in a different tool. A
    repo with no shims at all scored exactly like a current one.
11. **Two tests asserted the defect as the contract.** `"unresolvable report is
    rate limited (1/3)"` required that two of three calls say *nothing*, and
    `"genuinely absent gate fails open (0)"` required the exit code that discards
    the message. Both had to invert. A test that asserts the defect answers the
    question before anyone thinks to ask it.

## Files modified

- `reference-implementations/project-hooks/shim-template.sh` — suppressed line,
  report-then-mark, 1.2.0
- `reference-implementations/project-hooks/openspec-change-gate.shim.sh` — same
- `.claude/hooks/openspec-change-gate.sh` — `exit 0` → report + `exit 1`, 1.2.0
- `tools/project-hook-conformance.sh` — absence axis, registration axis, matcher axis
- `reference-implementations/project-hooks/MATCHERS`, `OPT-OUTS` — **new** declarations
- `tools/project-hook-shim.test.sh`, `project-hook-conformance.test.sh`,
  `test-claude-hook-wrapper.sh` — new assertions, two inverted
- `reference-implementations/project-hooks/README.md` — fix recorded; the
  three-repos-one-family count corrected to five across two
- `openspec/changes/shim-suppressed-report-and-fleet-propagation/` — proposal,
  design, delta, tasks, `REVIEWS.md` (2 rounds), `REVIEW-RESPONSE.md`

## Next session: start here

**PR #73 needs the independent code review in a cleared session** — `/clear`,
then review the branch. It is the one gate this branch does not carry evidence
for, and task 8.4 asks for it explicitly *before* merge. Everything else on PR 1
is verified: 56/56 shim suite, 54/54 conformance suite, 12/12 wrapper suite,
validate green, gate `--ci` exit 0, RED observed before every GREEN.

After it merges, the remaining tasks are groups 3, 5, 6, 7 and 8 in
`tasks.md`: live end-to-end verification (needs a 1.2.0 shim deployed, so it
follows 5.1), then seven repos each by its own branch and PR — 6 shims
re-versioned in `agenticapps-dashboard` and `cparx`, 14 inlined copies converted
in `agenticapps-roadmap`, `agents-task-viewer`, `callbot`, `fbc-platform` and
`fx-signal-agent`, and one file deleted in `agents-task-viewer` **after** its
opt-out rationale is relocated to an ADR there. Then core PR 2 carries the
evidence and the archive.

## Open questions

- **Converting will change live behaviour in five repos**, and it is intended:
  their inlined `database-sentinel` blocks every `migrations/*` edit behind a
  sentinel file they do not have, with a remedy naming `/gsd-discuss-phase`
  (removed 2026-07-28). Each PR body must say so.
- **`agents-task-viewer` carries `bin/openspec-change-gate.sh` (17k).** The
  contract's two-candidate order drops that fallback deliberately. Task 6.5a
  disposes of it explicitly rather than orphaning it.
- **The matcher axis needs `python3`** and says so when absent. "Not checked" is
  a different sentence from "checked and clean" — but a CI runner without python3
  would silently narrow coverage to what the other axes see.
- **`agenticapps-dashboard-add-agent-board` is not in `FLEET`** and its hooks do
  fire when that worktree is used. Left unconverted, reasoning in `design.md`.
- **`provisioning-check.sh` is still not published to the shared bin.** Unchanged
  from previous sessions.
- **27 branches carry genuinely unmerged content**, still unjudged for worth.
- The convergence rule is still unwritten — tenth session.
- **Two neuroflash PRs remain open** (api-docs #14, terraform #185) — different
  family, untouched.
