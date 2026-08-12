---
reviewers: [gemini, codex]
models: [gemini-cli-default-unpinned, gpt-5.6-sol]
verdicts: [REQUEST-CHANGES, REQUEST-CHANGES]
reviewed_artifacts_sha: 0d08fdef392a6fa2ddb63d70f605af7bcba547c6f7fbbda99d20a9b350c816c1
---

# Change review — trim-stale-fleet-rosters

Both reviewers are of vendors other than this host's. Both returned
REQUEST-CHANGES. The reviewed artifacts are `proposal.md`, `tasks.md` and the
spec delta as they stood before any resolution below — the sha is of the
concatenated prompt, not of the current files.

**On the recorded models.** `reviewer-cli.sh` pins no model; each vendor CLI
uses its own default. Codex resolves to `gpt-5.6-sol` from `~/.codex/config.toml`
(reasoning effort `high`). The gemini CLI carries no model in
`~/.gemini/settings.json`, so its resolved model could not be established and is
recorded as unpinned rather than guessed. Rule 4 asks for the resolved model;
where it cannot be read, saying so is the honest form.

**On the trailer.** There is none. `REVIEWS.md` here is hand-written, and the
`<!-- openspec-review-trailer -->` block the gate parses is emitted only by
`run-plan-review.sh`. `trailer-absent` is the honest state; hand-stamping a
digest would assert a provenance this file does not have.

## Reviewer: codex (gpt-5.6-sol)

VERDICT: REQUEST-CHANGES

- [HIGH] `vestigial-surface-removal` / task 4.2 — the capability's first
  requirement exempts `tools/` and "every test harness" from deletion, so
  deleting `tools/drift-report.sh` and its test contradicts a live requirement
  while `validate` stays green. Add a narrowly scoped delta reconciling the
  rule, or retain the tool.
- [HIGH] proposal / ADDED requirement — after the trim, `--family` holds no host
  implementation: `core` is the authority and `shared-install` an installed copy
  of it. `shared-install` is not a repository, contradicting "a roster declares
  only repositories", and "scored 2 of 2" presents two local surfaces as family
  coverage. Retire or rename `--family`, or redefine the roster as artifact
  targets and state what the two-target measurement proves.
- [HIGH] Non-goals / REMOVED requirement — the change keeps
  `resolve-core-artifact.sh` published for future consumers while deleting the
  only harness integration, reporting distinction and path-confinement security
  contract those consumers would need. A future adopter is reported as merely
  absent and must reconstruct the safety rules from an old commit. Keep the
  branch while the resolver is published, or retire the resolver in the same
  change.
- [MEDIUM] ADDED requirement — its scope is "a roster in a core harness", but
  `FLEET` belongs to `check-shims.sh` and `drift-report.sh` is advisory and
  outside the conformance-harness set. The delta governs two of the four roster
  changes it claims to.
- [MEDIUM] tasks 4.3–5.3 — the reference sweep is incomplete. `README.md` still
  lists `drift-report.sh` as the current advisory check, and
  `reference-implementations/README.md` still presents the four archived hosts
  as the current fleet.
- [MEDIUM] scenario "A roster's every entry is retired" — an empty roster does
  not imply an empty instrument. `check-shims.sh` treats an empty `FLEET` as a
  valid clean state. Require proof the instrument has no remaining subject
  through *any* input.
- [MEDIUM] tasks 3.1–3.5 — the claimed RED does not exercise the branch. Since
  no host directory currently holds a resolver and manifest, asserting that
  output lacks the resolvable string already passes before implementation, and
  deleting J3 removes the only test that reached it.

## Reviewer: gemini (model unpinned)

VERDICT: REQUEST-CHANGES

- [MEDIUM] `drift-report.sh` retirement — removes the repository's only
  automated canonical-prose drift check without deciding the capability's
  future. `spec/09` should reference that decision.
- [MEDIUM] `resolve-core-artifact.sh` — this change removes its only known
  consumers and the mechanism that tested its use, then declines to retire it.
  Deferring creates documented dead code, which is the principle the change
  invokes against everything else.
- [LOW] `GATE-INVENTORY.md` — task 5.3 says "correct the verdict" without
  saying to what.

## Independence

Two vendors, neither this host's. The two HIGH findings on
`resolve-core-artifact.sh` (codex HIGH 3, gemini MEDIUM 2) were reached
independently and are the strongest signal in this round.

## Resolution

**codex HIGH 1 — confirmed by reading, and escalated rather than resolved.**
`openspec/specs/vestigial-surface-removal/spec.md` does say it: *"Deletion SHALL
NOT reach records, tests, tooling, or authored prose. Specifically exempt from
deletion: `adrs/`, `openspec/`, `CHANGELOG.md`, `docs/`, `prompts/`, `tools/`,
`spec/`, and every test harness."* It carries a tiebreaker too — where the class
is unclear, an artifact *"SHALL be treated as a record and retained, because the
cost of keeping a dead file is bounded and the cost of deleting a reason is
not."* The proposal cited that same capability as its warrant for deleting
`drift-report.sh`, which the capability's own scope forbids. This is not
resolvable by editing the proposal: it needs either a narrow delta amending that
requirement, or the retirement dropped. Put to the operator; nothing in §4 or §5
of `tasks.md` proceeds until it is answered.

**codex HIGH 2 — accepted.** The ADDED requirement is recast in terms of roster
*targets*, not repositories, and the proposal states what the two-target sweep
proves: it compares core's working-tree reference implementation against the
copy `install.sh` published, which is a real and continuing measurement —
publish drift — and not family coverage. `--family` is not renamed; the flag is
an interface with callers, and correcting what the sweep claims costs nothing
while renaming it churns every caller.

**codex HIGH 3 + gemini MEDIUM 2 — accepted, and the scope widens.** Two vendors
found it independently. The Non-goal is withdrawn:
`reference-implementations/shared-install/resolve-core-artifact.sh` is a
published interface artifact and squarely inside `vestigial-surface-removal`'s
governed class, so it is retired in this change. Its harness,
`tools/resolve-core-artifact-conformance.sh`, is `tools/` and runs into HIGH 1 —
it is bound to the same operator decision.

**codex MEDIUM 1 — accepted.** The requirement is reworded to reach any declared
roster in this repository, so `FLEET` is covered by the rule that governs it
rather than by proximity.

**codex MEDIUM 2 — accepted, and verified.** `README.md:103` and `:137` name
`drift-report.sh` as the current advisory check; `README.md:17–26` and
`reference-implementations/README.md:61–64, 82–97` present the four archived
hosts as the current fleet. Tasks are added. The distinction that governs each
edit is the one `vestigial-surface-removal` already draws: a *dated measurement
record* stays and a *live instruction* is corrected, and each reference is
classified before it is touched.

**codex MEDIUM 3 — accepted.** The scenario is weakened to require that the
instrument have no remaining subject through any input, not merely an empty
roster.

**codex MEDIUM 4 — accepted, and it caught a trap the delta names elsewhere.**
The proposal argues against an inverted J3 precisely because asserting the
absence of a string passes for a harness that prints nothing — then task 3.1
proposed exactly that. The vacuous assertion is dropped. What remains is a real
RED: `--resolve` is accepted today and must be rejected after, which fails
before the change and passes after.

**gemini MEDIUM 1 — accepted.** Task 5.1 is sharpened: `spec/09`'s `## Drift`
section states the decision and its reason, rather than going silent.

**gemini LOW — accepted.** Task 5.3 names the verdict.
