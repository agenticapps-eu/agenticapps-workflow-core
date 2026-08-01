# Session Handoff — 2026-08-01

## Accomplished

**Core's spec now describes the gate core ships.** Two PRs, both merged to main.

| PR | what |
|---|---|
| [#50](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/50) | `hooks/openspec-gate.ci.yml` — the CI template promised a reviewer floor gate 2.0.0 does not enforce |
| [#52](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/52) | **spec 1.5.0** — §18's review clause becomes reported, not enforced; §17, `docs/WORKFLOW.md`, CHANGELOG, ADR-0027 |

(#51 was #52's original number, stacked on #50's branch. Merging #50 with
`--delete-branch` closed it, and GitHub refuses to reopen a PR whose base is
gone or to retarget a closed one. #52 is the same commit against `main`.)

**The divergence.** Gate 2.0.0 withdrew blocking on review state on 2026-07-31.
`spec/18` and `spec/17` were never swept for it, so core's normative text still
required a block the reference gate does not perform — `validate` green + no
`REVIEWS.md` → exit 2, plus the same for an absent/malformed trailer and a
stale digest. Every host pinning that gate was non-conformant with the spec it
cites. pi surfaced it by declining to pin the CI template.

**Three things found that weren't in the brief:**

1. **No ADR recorded the withdrawal.** The fleet's largest behavioural reversal
   existed only as a CHANGELOG entry and a shell-script comment, while
   ADR-0021 still cites the gate having "demonstrably blocked a code edit
   before review" as evidence for the standard. Written as **ADR-0027**,
   superseding rather than rewriting.
2. **`track-and-conform-plan-review`'s own delta contradicted its headline
   requirement in three scenarios** — identity-absent, amended-after-review,
   amended-to-address-an-objection all still said the gate blocks. Its prose
   also claimed amending "forces a re-review, so the only route past an
   objection is to leave the change unamended", true only while a stale review
   blocked. All corrected.
3. **§18 still carried the level-1-or-2 section bound** that gate 1.6.0
   replaced after `## Summary` was found truncating sections and discarding
   real verdicts. The delta got that fix; §18 never did.

Verified on main after merge: `openspec validate --all` 3 passed / 0 failed;
`tools/change-gate-conformance.sh` 71/71; `spec_version: 1.5.0` in §00, §17,
§18. Nothing executable changed in either PR.

## Decisions

- **spec 1.5.0, a minor — because §18 simultaneously grants blocking as a
  declared §09 host extension.** Without that clause this is a major: removing
  a MUST makes every still-blocking host non-conformant. With it, a host that
  blocks *declares* rather than diverges, and pi's `check-change-review.sh` ≥2
  hard stop is legal the day this lands. The two decisions only work together.
- **The work went into `track-and-conform-plan-review` (new section 1b), not a
  new change.** That change is titled "Repair and extend §18", already owns the
  `change-gate-enforcement` capability, and its own delta requires that "every
  statement of it in the spec agrees" — so this discharges an existing
  obligation. A separate change would have had to ADD overlapping requirements
  to a capability that exists only inside that change's unarchived delta, making
  archive order decide whose prose wins.
- **The gate script's own stale `--ci` usage line was left alone.** Correcting
  it bumps the version marker and invalidates the sha256 in four host pins — a
  one-line doc fix would force a fleet-wide re-pin. Recorded as task 1b.22; it
  waits for a gate change that must move anyway.
- **`spec/02:101` and `spec/07:18` judged intentional, not stale** — 0.x
  plan-review and Stage-1 ordering, neither retargeted by §18.
- **#52 was merged with CodeRabbit's check still PENDING.** "merge all" was
  explicit and the check is advisory, but nobody has read its findings.

## Files modified

- `spec/18-retargeted-change-gate.md` — truth table, both-clauses rule, floor
  rule, scenarios, fail-open clause, escape hatch, MAY-extension, section bound
- `spec/17-lifecycle-and-gate-mapping.md` — stage 2, gate-mapping row,
  requirement, `review before code` scenario
- `spec/00-overview.md` — `spec_version` 1.4.0 → 1.5.0 + version history
- `CHANGELOG.md` — the 1.5.0 entry
- `adrs/0027-reviews-are-reported-not-enforced.md` — new
- `docs/WORKFLOW.md` — L13, gate table
- `reference-implementations/openspec-change-gate/hooks/openspec-gate.ci.yml` —
  rewritten in #50, `(spec §18)` citation restored in #52
- `openspec/changes/track-and-conform-plan-review/` — `tasks.md` section 1b
  (27 tasks, all ticked); `specs/change-gate-enforcement/spec.md` three
  scenarios + the withdrawn "only route past an objection" claim

## Next session: start here

**Archive `track-and-conform-plan-review`.** It is at 155/157 with only two
tasks open: `9b.18` (publish gate 1.6.0 — bumped and green, never published,
gated on 8b.7) and `10.2` (`openspec-change-gate.sh --ci` green). Check whether
9b.18 is now moot given gate 2.0.0 shipped past 1.6.0; if it is, say so in the
task rather than ticking it. Archiving that change is what finally creates
`openspec/specs/change-gate-enforcement/spec.md`, after which any further gate
work can write a normal MODIFIED delta instead of the ADD-and-hope shape this
session had to work around.

## Open questions

- **The four hosts still cite spec 1.4.0.** Nothing forces them to move — 1.5.0
  requires no host action — but until they re-cite, their `implements_spec`
  names a version whose §18 contradicts the gate they pin. Deciding whether
  that re-cite is a fleet task or a per-host one is unowned.
- **Core still does not gate itself.** No `.claude/hooks/`, and
  `.github/workflows/` has only `pages-cheatsheet.yml` — the repo that
  publishes the change gate runs neither the hook nor the CI job. The template
  it now correctly describes is not installed here.
- **`shim-project-hooks` is on main at zero tasks done** — an unimplemented
  proposal, unchanged this session.
- **The §07 Stage-2 code review of core #49's merged work is still NOT DONE**,
  carried from two sessions ago.
- **Migration 0032 installs the producer without version arbitration** — open.
- **CodeRabbit's review of #52** was never read; it was pending at merge.
