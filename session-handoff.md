# Session Handoff — 2026-08-05 (third session)

## Accomplished

**`installer-prerequisite-consent` implemented, archived, and opened as PR #82.**
40/40 tasks. It was the only active change; there are none now.

- `spec/21-installer-prerequisites.md` — new declarative contract. Spec 1.5.0 → 1.6.0.
- `tools/installer-prereq-conformance.sh` + `.test.sh` — single-target harness, 75 rows.
- `tools/install-core-git-hooks.sh` — gained the `git` check it was missing.
- `.github/workflows/openspec-gate.yml` — runs the suite and scores core's own installer.
- Folded 9 requirements into `openspec/specs/installer-prerequisite-consent/`.

Verification: 75/75 under bash 3.2/BSD sed **and** bash 5.2/GNU sed/mawk;
shellcheck clean; §20 suite 42/42; agents-md 77/77; hook installer 16/16;
`openspec validate --all` 8/8; spec-placement clean; gate `--ci` green.

**The fixtures were not enough.** Three harness defects surfaced only when it
was pointed at the four real installers and core's own, and all three failed in
the quiet direction — the harness declining to look while sounding like it had:

- the recognisability screen listed host-shaped directories only, so core's own
  hook installer (which resolves `git rev-parse --git-path hooks`) read as "not
  an installer" — core would have shipped a contract it never scored itself against
- the quote strip took `$(…)` with the surrounding string, so an unguarded
  `OUT="$(npm install -g pkg)"` read as fully conformant. The consent row, the
  harness's whole job, defeated by a pair of quotes
- `~/.agenticapps/bin/` is written through a variable (`AA_BIN`, `AGENTICAPPS_BIN`)
  by three of the four, so matching the literal found the write in one installer
  and called the other three INCONCLUSIVE — on the row the ownership boundary exists for

Each is now pinned by a fixture.

## Decisions

- **A prerequisite installed on the operator's behalf is never removed** (task 1.5,
  Donald chose "state it: never auto-remove"). The ownership test runs both ways:
  by removal time other projects may resolve it. Offering to remove was rejected —
  it prompts about the outcome the operator almost always wants.
- **Core's own installer was fixed, not excused** (task 5.3). It failed
  `prereq-detection` on an unchecked `git`. Three lines; without it the failure
  surfaces as git's own "command not found".
- **Section 21, and §00's declarative list corrected** — it still listed the
  retired §15.

## Files modified

All on `feat/installer-prerequisite-consent`, PR #82, four commits.

- `spec/21-installer-prerequisites.md` — new
- `spec/00-overview.md` — 1.6.0, §21 added to the declarative list, §15 note
- `CHANGELOG.md` — the 1.6.0 entry
- `tools/installer-prereq-conformance.{sh,test.sh}` — new
- `tools/install-core-git-hooks.sh` — `git` prerequisite check
- `tools/conformance-harness-reporting.test.sh` — registers the new harness
- `.github/workflows/openspec-gate.yml` — two steps
- `openspec/specs/installer-prerequisite-consent/` — new, 9 requirements
- `openspec/changes/archive/2026-08-05-installer-prerequisite-consent/` — archived,
  carrying `CONFORMANCE-EVIDENCE.md`

## Next session: start here

**Run the Stage-2 code review on PR #82 in a cleared session** — `/clear`, then
review the diff. §07 independence means it cannot be a subagent of the session
that wrote the code, and this session wrote all of it. The highest-value target
is `tools/installer-prereq-conformance.sh`: it is a static analyser making
claims about shell reachability, three of its detectors were wrong on first
contact with real installers, and a fourth wrong detector would look exactly
like the three did — green fixtures and a quiet INCONCLUSIVE.

After that, the fleet has work waiting: `codex-workflow:333` and
`opencode-workflow:373` are non-conformant on consent, `pi` on the reporting
obligation, and all four on the unchecked `git`. Each is that host's own change.

## Open questions

- **Nothing verifies that a PASS on `consent-guard` means the guard dominates
  the install.** It means a guard was found lexically before it. A script could
  reach the install through an indirection the harness does not model.
- **`prereq-detection` reads a fixed list of 16 known tools.** A prerequisite
  outside that list is invisible to the row, and the harness does not say so.
- **The plan reviews predate the merged text**, again — `REVIEWS.md` records 3/3
  REQUEST-CHANGES against pre-rewrite artifacts. All three findings are addressed
  in what shipped, but the reviewers never saw the corrected specs. Gemini argued
  for the location rule; `CONFORMANCE-EVIDENCE.md` is why it was not taken.
- **CodeRabbit reviewed none of #79/#80/#81.** Assume the same for #82 until the
  body says otherwise; the green check is not the review.
- **`.planning/skill-observations/*` is still being written** despite the freeze
  rule. Unchanged across five handoffs.
