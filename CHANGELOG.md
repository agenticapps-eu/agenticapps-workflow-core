# Changelog

All notable changes to the AgenticApps workflow specification are documented
in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Versioning policy

Spec versions follow semver:

- **Patch** (0.1.x) — typo fixes, clarification rewordings, no conformance impact.
- **Minor** (0.x.0) — additive: new declarative requirement, new optional gate.
  Hosts already at the prior version remain conformant.
- **Major** (X.0.0) — breaking: canonical block reworded, gate removed,
  evidence rules tightened. Hosts MUST update their implementations.

Each entry below names the conformance impact for host implementers.

## [Unreleased]

**No spec version change.** Everything below touches `tools/` and
`reference-implementations/`, neither of which is normative spec text. No
host's conformance claim changes and no host action is required — though the
drift-report fixes surface a pre-existing §11 gap in `claude-workflow` that
does need a host change; see under *Fixed*.

### Added
- **`reference-implementations/shared-install/`** — the arbiter every host
  installer calls to write a versioned artifact into `~/.agenticapps/bin/`, plus
  **`tools/shared-install-conformance.sh`** (12 rows).

  Core had specified only *"refuse to downgrade"*. All four hosts implemented
  that correctly and the shared path was **still** not monotonic, because the
  arbitration is a read-compare-write with nothing held across it — two
  installers each deciding correctly against the same observed state let the
  later writer win regardless of version. **Per-host arbitration does not compose
  into machine-wide monotonicity.** Reported as
  [pi-agentic-apps-workflow#13](https://github.com/agenticapps-eu/pi-agentic-apps-workflow/issues/13);
  the same shape as [#41](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/41)
  one level down, where the *write* was unguarded rather than the *decision*.

  The contract is now stated as a postcondition — after any set of concurrent
  installs the path holds the newest version offered — and both the gate and
  `reviewer-cli` READMEs were corrected: they specified the necessary half of the
  rule and were silent on serialisation, which is why four correct
  implementations still raced.

  Mutual exclusion is `mkdir`-based (atomic on POSIX; `flock(1)` is absent on
  macOS), per-artifact so the gate does not serialise against `reviewer-cli`, and
  stale locks are broken by pid so one killed installer cannot wedge the machine
  permanently. Writes land via rename-into-place so an agent whose `PreToolUse`
  hook fires mid-install never reads a truncated script — the lock gives
  monotonicity, the rename gives readers integrity, and they solve different
  problems.

  The harness pins the distinction that matters: an implementation with correct
  arbitration and no lock **passes every arbitration row and fails monotonicity**
  (9/12). That gap is the defect, and it is why "we refuse downgrades" is not
  evidence of conformance.

  **No spec version change and no host action required by this entry** — hosts
  currently ship correct-but-unserialised arbitration and should adopt, but
  nothing they publish today is non-conformant to §18.

- **`reference-implementations/reviewer-cli/`** — core now publishes the reviewer
  wrapper too, plus **`tools/reviewer-cli-conformance.sh`** (14 rows) to score
  any copy. The change gate *consumes* review evidence; this is what *produces*
  it, and it was the same fork the gate had just been rescued from.

  Three divergent copies existed at the shared `~/.agenticapps/bin/` path with no
  version marker and no arbitration — `codex-workflow` 95 lines / 4 vendor arms,
  `pi-agentic-apps-workflow` 85 / 3, `opencode-workflow` 72 / 2, `claude-workflow`
  none. On 2026-07-25 a host installer delivered the correctly-arbitrated `1.2.2`
  gate and **in the same run** blind-installed a 3-arm wrapper over the 4-arm one;
  the next review asking for `opencode` got `unknown vendor`. The gate survived
  because it carries `# gate-version:` and every host arbitrates on it. This file
  had no marker, so the same installer run upgraded one shared artifact and
  downgraded the other.

  Not a gate bypass — a producer excluding its own host still had two vendors and
  §18's `>= 2` threshold held. It is a silent capability loss that surfaces
  mid-review, gets recorded as "reviewer unavailable", and proceeds with one
  fewer opinion.

  The canonical is a **merge, not a pick**: `pi`'s structure (stdin pinned inside
  `run_bounded` in one place covering both branches, explicit usage checks, the
  unbounded-run warning) with `codex`'s coverage (four arms, and the note that
  `opencode` is a *client not a provider* so the producer must record the
  resolved model). Neither copy was simply better. Ships at
  `# reviewer-cli-version: 1.0.0`; installers MUST refuse to downgrade.

  **No spec version change and no host action required by this entry** — §18's
  normative text is untouched and vendoring is offered, not mandated. Hosts that
  adopt should re-vendor; until then the fleet scores 58/70 (see the harness).
  Closes [#41](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/41).

- **Two conformance rows for defects no row covered** (31 → 33). Both are fixed
  in the canonical gate, so nothing was broken — but a future change could have
  regressed either and still scored every declared row green.

  - *`active change, evaluated from a subdirectory -> block`.* A gate that
    resolves `openspec/changes` against `$PWD` rather than `git rev-parse
    --show-toplevel` finds no active change from below the root and allows the
    edit, while logging a line that reads like a correct decision. A
    `PreToolUse` hook inherits the session's cwd, so this is the common case.
  - *`brace-free garbage stdin -> allow (fail-open)`.* The existing garbage row
    uses `not json {{{`, which is **not discriminating**: a gate whose JSON
    branch is guarded on `{` skips it and reaches a `TOOL<TAB>PATH` fallback
    that splits whitespace-only input into a plausible path and proceeds to
    policy — failing CLOSED on a parse error, the one posture §18 forbids.
    `not json at all` is the input that separates the two.

  Both rows were mutation-checked: each fails against a gate carrying the
  corresponding defect while the surrounding rows stay green. Reported from
  `codex-workflow`'s adoption (GAP-1 / GAP-4).
  Closes [#37](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/37).

- **`reference-implementations/openspec-change-gate/`** — core now publishes the
  §18 change-gate itself (script, `pre-commit` wrapper, CI workflow), plus
  **`tools/change-gate-conformance.sh`** to score any copy against §18's truth
  table. ADR-0022; closes [#32](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/32).

  **No spec version change and no host action required by this entry** — §18's
  normative text is untouched and vendoring is offered, not mandated. Recorded
  here because it changes what this repo *is*: `tools/drift-report.sh` measures
  hosts, and core now also supplies them.

  The prompting defect: five mutually divergent copies of the gate existed
  across the family, **none conformant**, in two lineages sharing no code. §18
  requires the gate be "demonstrable by direct script invocation with simulated
  payloads", but every copy hardcoded the `openspec` binary, so the block/allow
  rows could not be driven without a real populated OpenSpec repo — the contract
  was unverifiable as written, which is why the drift went unmeasured. Scored
  against the new harness:

  | Copy | Score |
  |---|---|
  | `reference-implementations/openspec-change-gate/` | **28/28** |
  | `claude-workflow/bin/` | 25/28 |
  | `pi-agentic-apps-workflow/bin/` | 18/28 |
  | `codex-workflow/bin/` · `opencode-workflow/bin/` | 16/28 |
  | `~/.agenticapps/bin/` (shared install) | 16/28 |

  Expect **host copies to start reporting failures against unchanged behaviour**
  — the harness is new, the defects are not. A hook-only gate was already
  non-conformant to §18's "real enforcement surface" clause; it now says so.

  The gate carries a **`# gate-version:`** marker (currently `1.2.0`) so host
  installers can arbitrate writes to the shared path and refuse to downgrade.
  Adopted from `claude-workflow`; **every host installer needs this check**, not
  just the one that had it — a host without it still clobbers.

  Two of the 28 rows exist because independent review caught the *first* version
  of this implementation scoring a clean 19/19 while carrying four bypasses,
  including an `openspec/` exemption that exempted `src/openspec/app.ts` and
  `/tmp/openspec/x.ts`. The rows had been drawn to match the code rather than
  the threat model. Recorded in ADR-0022 because the failure mode generalises:
  a composed implementation is only as good as the moment its inputs were
  measured.

  Note the shared-install race the issue documented: `claude-workflow`'s
  installer writes to `~/.agenticapps/bin/`, where every host's shim, `pre-commit`
  and pi's extension resolve — so whichever installer ran last owns the gate for
  every host. Re-vendoring closes it; the harness proves it closed.

### Changed
- **`reference-implementations/README.md`** — `opencode-workflow` moves from
  **0.4.0 → 0.9.1** (`full`), reflecting its adoption PR (host v0.4.0, migration
  `0007`). It binds §02 `plan-review` to the upstream `/gsd-review` command,
  declares §14 trivially conformant (no LLM prompt-building surface — the
  trigger cannot occur; §09 requires only that the host say so), and names its
  §08 drift guard in its instruction file per v0.9.0.

  Worth recording for the §08 history: this host's guarded-snapshot install was
  **non-conformant under pre-0.9.0 §08 for as long as it cited 0.4.0** — its
  claim, not its code, was the liability. The v0.9.0 amendment (written citing
  this host's ADR-0007 alongside `claude-workflow`) is what legitimized the
  strategy, so absorbing *retired* a violation rather than adding obligations.

  Fleet status after this: `claude-workflow` 0.9.0, `opencode-workflow` 0.9.1,
  `codex-workflow` 0.4.0. The fleet is no longer uniform.

  > **Correction (2026-07-19).** This entry originally added: "and
  > `codex-workflow` has the same pre-0.9.0 §08 exposure, since it too installs
  > from a snapshot." **That is false.** `codex-workflow` installs by **replay**
  > — its setup skill walks `0000`→latest step by step, it ships no
  > `check-snapshot-parity.sh`, and its CI runs only `migrations/run-tests.sh`.
  > Replay is §08's first-listed strategy, so the v0.9.0 amendment's drift-guard
  > obligation — which binds snapshot installers — never applied to that host,
  > and it had no §08 exposure to retire. Surfaced while auditing codex for its
  > 0.10.0 adoption.

### Fixed

- **Gate 1.2.2 — two symlink escapes in the `openspec/` exemption.** Both
  pre-existing since 1.2.0 (verified by running the same reproducer against
  1.2.0 and 1.2.1 with identical results), so neither is a regression from the
  1.2.1 symlinked-root fix.

  - **`..` was collapsed textually before physical resolution.** Where a symlink
    inside `openspec/` precedes the `..`, the textual pass and the kernel
    disagree — `openspec/out/../victim` with `openspec/out -> /tmp/outdir` reads
    as `$ROOT/openspec/victim` (exempt) while the write lands in `/tmp`. Now
    resolves physically first; a `..` that survives forfeits the exemption
    rather than being guessed at, since it sits below a directory that does not
    exist and its destination is unknowable.
  - **The final path component was never resolved.** A symlinked artifact path
    (`openspec/changes/x/design.md -> src/app.go`) was exempted and the writer
    followed it, truncating code under an unsatisfied change. Now resolved when
    it exists and is a symlink. The not-yet-existing Write target that 1.2.1
    fixed is unaffected: `[ -L ]` is false for a path that does not exist.

  The comments in both places asserted the opposite of what the code did —
  claiming the textual-first order "keeps the escape rows blocked" (it keeps
  only the *bare* escapes blocked) and that refusing to resolve the last
  component prevented following a link out of the tree (it is what permitted
  it). Corrected; that was the more durable hazard.

  **Severity is lower than "escape" suggests.** Both need a symlink to already
  exist inside `openspec/`, which needs shell access — at which point the
  `PreToolUse` hook is bypassable by writing through bash anyway. `--pre-commit`
  and `--ci` were never affected: staged paths are repo-relative, git cannot
  stage a `..` component, and a staged symlink stores its target as the blob.

  Four harness rows added (33 → 37): symlink-then-`..`, an unresolvable `..`
  below `openspec/`, a symlinked artifact pointing at code, and a not-yet-
  existing artifact pinning the 1.2.1 behaviour. The first two defect rows fail
  against 1.2.1 and the third against a fix lacking the leftover-`..` guard, so
  each is load-bearing. **Hosts must re-vendor** — see
  [#34](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/34).
  Closes [#36](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/36).

- **`tools/change-gate-conformance.sh` inherited `OPENSPEC_GATE_SELF` from the
  environment it was measuring.** The vendoring README tells hosts to export the
  variable (step 5) and then run the harness (step 7); doing both in one shell
  scored a **fully conformant gate 30/31**. The two-reviewer row seeds `claude`
  and `codex`, so an ambient `OPENSPEC_GATE_SELF=codex` made the gate correctly
  drop one review, leaving one reviewer and a block — the row failed for a gate
  behaving exactly as specified. The harness now `unset`s it at the top; the
  section-E rows set it per-row as a command-scoped assignment and are
  unaffected. README steps 5 and 7 gained the matching warnings, including
  `env -u` rather than `VAR=` (set-but-empty and unset differ under `set -u`).
  Reported from `codex-workflow`'s adoption, where it bit the CI driver and then
  the workflow's own job-level `env:`.
  Closes [#37](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/37).

- **`tools/drift-report.sh` reported a false PASS on §04.** It grepped for the
  literal `13 Red Flags — STOP → DELETE → RESTART`, but `spec/04` rule 3 (since
  0.8.0) makes the heading's leading count **not normative** — a host appending
  a host-specific flag updates it to its own total. claude-workflow ships
  `## 14 Red Flags`, which no tracked file matched; the check stayed green only
  because two **gitignored scratch files** quoted the old phrase. The tool was
  enforcing a literal the spec explicitly declares non-normative. It now matches
  only the canonical, non-count portion of the heading.
- **`tools/drift-report.sh` accepted canonical prose from anywhere in a clone.**
  A repo-wide `grep -r --include="*.md"` meant a phrase in a migration, a test
  fixture, or a planning doc satisfied a conformance check — a host could gut its
  instruction file and still pass on a fixture's quotation. Checks now read each
  host's declared prose files only (`spec/09` items 1 and 4), which also removes
  the gitignored-scratch problem by construction rather than by an exclusion
  list. See ADR-0019.
- **`tools/drift-report.sh` scored repos that claim nothing.**
  pi-agentic-apps-workflow carried `implements_spec` in no file yet scored 12 OK,
  though `spec/09` item 4 says such a host "is unversioned and cannot claim any
  conformance level"; agenticapps-dashboard is a consumer that authors no
  canonical prose. Between them they contributed 27 of the report's 68 OKs. A
  missing or unversioned instruction file now reports `ERROR` and is not scored.

- **`tools/drift-report.sh` let a scaffolding payload satisfy §11.** §11 binds
  its block to the host's "primary project-instruction file (CLAUDE.md,
  AGENTS.md, …)". claude-workflow's block appears only in `templates/`,
  `setup/` and `migrations/0014` — payload it ships *into* consuming projects —
  so the old repo-wide grep reported OK while the host's own `CLAUDE.md` carries
  no §11 block at all. Checks now read the declared project-instruction file.

  **This surfaced a real conformance gap:** claude-workflow did not reproduce
  the §11 block in its own `CLAUDE.md`, and declared no §11 delta, while codex
  and opencode both carry it in `AGENTS.md`. Fixed by **claude-workflow#88**;
  until that merges the report shows it as DRIFT (3 checks), which is correct.
  With both merged: 45 OK / 0 DRIFT.

### Added

- **`tools/drift-report.test.sh`** — the first tests in this repo. 18 assertions
  driving `drift-report.sh` through its public interface against synthetic host
  clones (temp dirs; no network, no real clones). The three defects above
  shipped because nothing exercised the tool. T13 pins the payload-mirror case;
  T12 pins the report against depending on the caller's working directory.

### Removed

- **pi-agentic-apps-workflow** is retired as a host: removed from the
  `reference-implementations` table and from the drift report. Adoption was
  never pursued and the repo is no longer in use. It held no conformance claim
  to withdraw. Recorded under "Retired hosts" in
  `reference-implementations/README.md`.

## [Unreleased]

**No spec version change.** `reference-implementations/` and `tools/` are not
normative spec text. No host's conformance claim is altered *by this repo*.

### Changed

- **`pi-agentic-apps-workflow` is un-retired** and listed in the active table
  again, at **0.10.0 / `partial`**. ADR-0019 removed its row on the grounds that
  it carried `implements_spec` in no file (per §09 item 4, unversioned and unable
  to claim any level) and shipped no §11 canonical block. Both were fixed at host
  v0.2.0: §11 is vendored byte-identical to codex's and opencode's mirrors and
  injected into a new `AGENTS.md` behind a provenance anchor, and the trigger
  skill now carries `implements_spec: 0.10.0`. Its §01/§03/§04/§05 blocks were
  already verbatim.

  It claims `partial`, not `full`, and names its deltas as §09 requires — §10
  observability unsatisfied, §14 undeclared (likely trivially conformant but
  unaudited, so not assumed away), §15 unwired, §02 `plan-review` unbound, and
  a session handoff that is not host-scoped.

  Notably it was **built to §12's instruction-surface economy rather than
  migrated to it**: `templates/pi-md-sections.md` went 179 lines → the §11 block
  plus a trigger-skill pointer and a session-handoff pointer, in the same change
  that gave it a §11 block at all.

- **`codex-workflow` moves 0.4.0 → 0.10.0** (`full`), reflecting its adoption PR
  (host v0.9.0, migration `0012`). Two things landed together: §12's
  instruction-surface economy (`AGENTS.md` 269 → 120 lines; gate table, routing,
  session-handoff, §15 tail and the plan-review *procedure* moved to the
  lazily-loaded trigger skill, with the `PreToolUse` hook wiring untouched), and
  a citation reconciliation. The citation had been stale by six spec versions —
  0.5.0/0.7.0/0.8.0/0.9.0 were already satisfied by shipped implementation, and
  the one real gap was **§14 (0.6.0), a *declaration* gap**: no LLM
  prompt-building surface exists, but §09 requires the host to say so. The
  migration refuses to advance the claim unless the declaration lands first.

  With this the fleet is uniform again at **0.10.0**: `claude-workflow` 0.9.0 →
  pending, `codex-workflow` 0.10.0, `opencode-workflow` 0.10.0,
  `pi-agentic-apps-workflow` 0.10.0 (`partial`).

- **`tools/drift-report.sh` scores pi again** — added back to `HOSTS` as
  `pi-agentic-apps-workflow|skills/agentic-apps-workflow/SKILL.md|AGENTS.md`. It
  reports **15/15 OK**, taking the report to **60 OK / 0 DRIFT / 0 ERROR** across
  four hosts. `drift-report.test.sh` T8 is inverted rather than deleted: it still
  pins that the dashboard (a genuine consumer) is never scored, and now also pins
  that pi *is*. 18/18 tests pass.

## [1.3.0] — 2026-07-30

**Minor — §18 gains the counting terms the gate needed, and stops
contradicting itself about the reviewer floor.**

**Conformance impact.** A host conformant to 1.2.0's *behaviour* stays
conformant: the floor text is corrected to match enforcement that already
existed, and the new terms are additive. But **evidence produced under 1.2.0
becomes unverifiable** — every existing `REVIEWS.md` predates the trailer, so a
gate implementing 1.3.0 counts zero reviewers until each change is re-reviewed.
That wave is scheduled, not discovered: publish the producer, re-review, then
publish the gate.

### Fixed

- **§18 mandated ≥1 and ≥2 simultaneously.** The truth table (line 73) and the
  rationale said one; line 146 and line 174 still said two, so the section was
  not satisfiable as written and "the producer is non-conformant" was only half
  true. Both are corrected to the one-reviewer floor. The same stale floor is
  corrected in §17, §02, the CI workflow, the reviewer-cli README and its script
  header. Statements of *preference* (SHOULD ≥ 2) and the historical note on why
  the floor moved are deliberately left.

### Added

- **A verdict term in the truth table.** The reference gate's own source recorded
  that "§18's truth table has no verdict term, so a gate that blocked on this
  would be non-conformant" — accurate against the previous text, and the reason
  a heading with no review counted. A section is counted only with **a verdict
  and a body**; the vocabulary is closed and the grammar is specified to the
  byte. Both failure halves were observed in production: a bare
  `VERDICT: APPROVE` with no body on 2026-07-29T07:52:54Z, and a verdictless
  preamble the same week.
- **Recorded implementing-host identity**, read from the artifact rather than
  the evaluating process's environment — CI and pre-commit hooks routinely
  evaluate evidence some other host produced, so an environment-derived identity
  names the wrong party. Missing or unrecognised counts zero. Independence is
  claimed as *a different CLI*, not a different model.
- **A digest binding a review to what was reviewed.** An amended change
  previously kept its old `REVIEWS.md` with the gate unable to tell — a hole
  walked through twice in one session. Stated as drift detection, **not**
  authenticity: it is computable by anyone holding the same artifacts and does
  not resist forgery.

## [1.0.0] — 2026-07-24

**Major release — the first. Breaking: the GSD-engine front end is replaced
by the OpenSpec + Superpowers front end.**

**Conformance impact.** A host claiming a **0.x** version is **unaffected** and
remains fully conformant at its cited version — 1.0.0 does not retroactively
invalidate it (§09 "Two front ends coexist"). A host that wants the new
behavior adopts 1.0.0 by satisfying the four new sections and stamping
`implements_spec: 1.0.0`. No host cites 1.0.0 yet; the whole fleet stays at
0.10.0. This is a major because the §02/§07 review gates are remapped and the
front-end lifecycle changes — a host cannot claim the new behavior while
implementing the old gates.

**Grounded in a measured pilot, not a hypothesis.** The 2026-07-24 cParX pilot
(`PILOT-REPORT.md`) ran a real task end-to-end through the new lifecycle; the
retargeted gate blocked a code edit before review and permitted it after, and
an adversarial reviewer caught a real spec defect *before code*. Measurements
in `MEASUREMENT.md`.

### Added

- **§16 — OpenSpec spec slot.** Three-slot model (`specs/` durable truth,
  `changes/` deltas, `archive/` history), two-part done-ness rule (delta folded
  **and** `validate --all` green), and the bind-upstream rule (OpenSpec is a
  per-host upstream tool, not re-ported). The installed CLI is authoritative
  over this prose where they disagree.
- **§17 — Lifecycle & gate mapping.** propose → validate → Superpowers-execute
  → archive; `archive ≠ ship`; and the table mapping every §02 gate to
  collapsed / retained / conditional. `plan-review` + `spec-review` collapse
  into `validate`; `code-review`/`tdd`/`verification`/`security` retained;
  `security` always; design/db/qa conditional; §13 declare-first → lint.
- **§18 — Retargeted change-gate.** The 0.x `PreToolUse` plan-review hook
  retargeted from "`*-PLAN.md` without `*-REVIEWS.md`" to "active OpenSpec change
  without validation + review", with a normative exit-code truth table
  (0 allow / 2 block; OpenSpec-artifact writes exempt; escape hatch; fail-open
  on garbage; validate-green **and** ≥2 reviewers required).
- **§19 — Spec-vs-process placement & Linear coupling.** The "product guarantee
  vs way of working?" test; capabilities merged-not-mirrored from phases; Linear
  coupled loosely by convention, never synced.
- **ADR-0021**, `docs/WORKFLOW.md` (the explainer),
  `docs/recipes/0001-planning-to-openspec.md` (the migration recipe, three
  tiers + Tier-1 script + git-ref fixture contract), `PILOT-REPORT.md`, and
  `MEASUREMENT.md`.

### Changed

- **§02 (hook taxonomy) and §07 (two-stage review) are remapped, not deleted.**
  Each gained a banner: normative as written for 0.x hosts; read through §17's
  gate mapping for 1.0.0 hosts. Their `spec_version` frontmatter bumped to
  1.0.0 (the banners are the change).
- **§00 (overview)** — added the v1.0.0 trajectory paragraph, a `Change`
  glossary term, and §16–§19 to the section lists. **§09 (conformance)** — the
  two-front-ends coexistence rule and §16–§19 added to the declarative-MUST
  list.

### Notes

- **gitnexus** has no normative binding in the core spec (a grep of `spec/` and
  active ADRs finds only one incidental historical mention in ADR-0019). The
  GSD-era gitnexus *host* binding retires on a host's adoption of 1.0.0; nothing
  in §16–§19 references it.
- **The migration recipe is a reference, not a shipped migration.** This repo is
  spec-only prose and ships no runnable `migrations/` chain; the executable
  `run-tests.sh` git-ref fixture is the adopting host's deliverable (cParX
  first). Host-level: claude-workflow's ADR-0003/0007/0009 and
  `docs/standards/gsd-binding-and-planning.md` are superseded in that host on
  adoption.

## [0.10.0] — 2026-07-19

Additive minor release, SHOULD-level. One new §12 convention; **no canonical
prose reworded and no §11 bytes changed**. Hosts at 0.9.x remain conformant
for their 0.9.x claims and need take no action to keep them.

### Added

- **`spec/12-authoring-conventions.md` — "Instruction-surface economy (eager
  vs lazy)."** §12 already governed *where in* the always-loaded instruction
  file behavior-critical prose sits; it said nothing about *what belongs in
  that file at all*, and the fleet split on the question. A host **SHOULD**
  now keep its always-loaded file (`CLAUDE.md` / `AGENTS.md`) to the §11
  canonical block plus a short pointer to the trigger skill, and **SHOULD**
  place content only needed once a code task is underway — the §02 gate-binding
  table, task-size routing, the §15 ritual tail, session-handoff, and
  gate-procedure prose — in the lazily-loaded trigger skill or a
  workflow-config. Hook *wiring* stays wherever the runtime needs it; only the
  explanatory prose moves. §01/§03/§04 **MAY** move to the trigger skill, or
  stay eager if the host judges the budget affordable.

  The always-loaded file is re-billed on every turn, including turns that never
  touch code, and padding it pushes the §11 block toward the mid-context
  position the existing placement advisory exists to avoid (Liu et al., 2023).
  `claude-workflow`'s 98-line §11-only `CLAUDE.md` is named as the reference
  shape. Rationale and rejected alternatives — a MUST, host discretion, a hard
  token budget — in **ADR-0020**.

- **`adrs/0020-instruction-surface-economy.md`** (Accepted, 2026-07-19).

### Changed

- **`spec/12`** — Conformance gains one SHOULD bullet for the new convention;
  the section's claim version advances `0.4.0` → `0.10.0`. The existing
  branchy-workflow bullet's "at or after 0.4.0 adoption" anchor is unchanged.
- **`spec/00-overview.md`** — §12's v0.10.0 addition recorded in the version
  history; `spec_version` → 0.10.0.
- **`spec/09-conformance.md`** — `spec_version`, the "at version" line, the
  `implements_spec` citation example, and the claimable-version list advance to
  0.10.0 (the list also backfills the previously omitted `0.9.1`).
- **`reference-implementations/README.md`** — "Current spec version" → 0.10.0.
  Host rows untouched per convention; they move via each host's adoption PR.

### Conformance impact

- `claude-workflow` **already satisfies** the new SHOULD (its `CLAUDE.md` is
  the reference shape). No action; it may re-assert at 0.10.0 opportunistically.
- `codex-workflow` and `opencode-workflow` adopt by slimming their ~220–250-line
  `AGENTS.md` and bumping `implements_spec`, each via its own migration and
  adoption PR.
- A host that ships a heavy always-loaded file at 0.10.0 is below this SHOULD
  but **not non-conformant overall**, exactly like the existing branchy-workflow
  SHOULD.
- `tools/drift-report.sh` is unaffected: it scores canonical-prose blocks, and
  none changed.

## [0.9.1] — 2026-07-15

Patch — clarification only, no conformance impact. A host conformant at 0.9.0
remains conformant at 0.9.1.

### Fixed
- **`spec/08-migration-format.md` §Concept** — the migration-selection sentence
  said the update flow applies migrations "whose `from_version` is newer than
  the project's installed version." That is wrong and contradicted the file's
  own per-field rules (§Frontmatter: skip when installed `<` `from_version`;
  §Skip cases: skip when installed `≥` `to_version`). Taken literally, a project
  at 2.4.0 would skip the 2.4.0→2.5.0 migration (its `from_version` is 2.4.0,
  not *newer*) and could never advance. Reworded to select by "not yet applied"
  (`to_version` newer than installed), consistent with the normative table.

## [0.9.0] — 2026-07-14

Additive minor release. One declarative contract relaxed; no canonical prose
reworded. **Hosts at 0.8.0 remain conformant with no action** — the §08 change
only widens what satisfies an existing MUST; it tightens nothing.

### Changed

- **`spec/08-migration-format.md`** — the setup flow's **end state** is now
  normative; the mechanism is not. The section previously required migrations be
  stored "in a single directory consumed by both setup and update flows", which
  read as: setup reaches the current version by replaying `0000`→latest.

  That assumed every migration chain is shell-replayable. A chain containing
  **prose, agent, or interactive steps cannot be** — a step whose apply is "the
  agent composes prose appropriate to this project" or "ask the user which stack
  they want" has no mechanical equivalent, so a script replaying it either hangs
  or silently produces a different shape than the chain describes. `claude-workflow`
  (host ADR-0036, host issue #74) and `opencode-workflow` (its ADR-0007) both hit
  this and both independently shipped the same answer: install a prebuilt snapshot
  from setup, and run a CI guard proving the snapshot equals the chain's end state.
  Under §08 as written, both were non-conformant on a MUST — including the host
  that authors this spec's canonical prose.

  v0.9.0 states the guarantee §08 actually wanted instead of the mechanism that
  happened to deliver it. Setup **MUST** produce an end state equivalent to a full
  `0000`→latest replay, by one of two conformant strategies:
  - **replay** — setup applies every migration from `0000-baseline` forward; or
  - **snapshot** — setup installs a prebuilt artifact assembled from the same
    sources, **PROVIDED** a drift guard runs in CI and fails the build when the
    snapshot and the sources disagree.

  A host choosing snapshot **MUST** name its guard in its instruction file. The
  update flow's obligation is unchanged: it consumes the single `migrations/`
  directory directly.

  The guard is the load-bearing half. §08's original concern — one source of truth
  for "what does v1.3.0 look like on disk", no divergent code paths — is unchanged
  and still binding. A guarded snapshot is not a second source of truth; it is a
  build artifact of the first one, and the guard is what makes that claim checkable
  rather than merely asserted. An **unguarded** snapshot is still non-conformant.

  The Concept section was rewritten accordingly (it cited ADR-0013, which assumed
  replayability), and `spec_version` advanced `0.1.0` → `0.9.0` — its first change
  since the spec's initial population.

- **`spec/09-conformance.md`** — **§09 said "Section 02 enumerates 15 gates"; it
  enumerates 16.** The count was never updated when the `plan-review` gate landed
  at v0.5.0. Corrected in both places it appeared (the `full` gate-binding
  requirement and the "Allowed extensions" allowance, which said "beyond the 15").
  No gate changed; this is a documentation defect, not a conformance change — a
  host that bound all applicable gates was already conformant. Version references
  and the `implements_spec` citation example advanced to 0.9.0.

- **`spec/00-overview.md`** — §08's v0.9.0 amendment added to the version history.
  `spec_version` advanced to 0.9.0. Also dropped a stale count in the glossary
  ("The four ADRs in `adrs/`" — there are nine).

- **`adrs/0013-migration-framework.md`** — Status annotated and a superseded-in-part
  note added to its "Setup ⊕ update unification" section. ADR-0013's decision (the
  migration framework itself) stands unamended; only its replayability assumption
  is superseded.

- **`reference-implementations/README.md`** — the `claude-workflow` row was two
  releases stale and factually wrong in two ways. It claimed spec **0.3.0** (now
  **0.9.0**, `full`, audited 2026-07-14 per host ADR-0040) and credited the
  `add-observability` skill as shipping from that repo — the skill was **removed at
  claude-workflow's 2.0.0** (`217baec`) and now lives in the standalone
  `agenticapps-observability` repo. The new row states §10/§14 as **delegated** to
  that skill (satisfied MUSTs per §09, not deltas), §15 as wired at all three ritual
  triggers, and the snapshot install as conformant under §08 as amended here. Header
  "Current spec version" advanced to 0.9.0 (its trailing "to 0.7.0" cross-reference
  had also been left behind by the 0.8.0 release).

### Added

- **`adrs/0018-snapshot-install-conformance.md`** — records the §08 decision: the
  end state plus a mechanical guard is normative, the mechanism is not. Rejects
  forcing replay (impossible for prose/agent/interactive chains — it would mean
  deleting the scaffolder's actual value to preserve a mechanism the spec only ever
  wanted for its guarantee), leaving §08 as-is and letting the reference
  implementation carry a permanent `partial` (makes `full` structurally unreachable
  for the host authoring the canonical prose, and strands `opencode-workflow`'s
  existing `full` claim as quietly false), permitting snapshot without a guard (the
  one shape that genuinely reintroduces the divergent-shape risk), and specifying
  the guard's implementation (the same error as freezing replay, one level down).
  Supersedes ADR-0013's replayability assumption.

### Host-implementer actions

- **A replaying host needs no action.** Replay remains fully conformant and is
  still the first-listed strategy. A host at 0.8.0 may claim 0.9.0 on its next
  audit with no implementation change.
- **A host that installs from a snapshot** (`claude-workflow`,
  `opencode-workflow`) must, to claim 0.9.0: ensure its drift guard **runs in CI
  and fails the build** on disagreement — a guard that exists but is not wired into
  CI does not satisfy the MUST — and **name the guard in its instruction file**.
  Both hosts already ship a `check-snapshot-parity.sh`; the new obligation is that
  the guard be named where a reviewer can find it.
- **A host staying at its current claim needs no action at all.**
  `implements_spec` names the version the host claims; a host citing 0.4.0 remains
  conformant at 0.4.0.
- **No host needs to act on the §09 gate-count fix.** It corrects the spec's own
  description of section 02, which is unchanged.

### Known gap

- **`tools/drift-report.sh` has no notion of setup strategy** and does not check
  the §08 equivalence obligation, the guard's existence, or its CI wiring. Nothing
  in this repo can independently verify a host's snapshot equals its chain end
  state; the spec takes the host's guard at its word. A §09 review-check block for
  snapshot hosts (mirroring the §15 knowledge-capture checks) is deferred until a
  third host ships the pattern — see ADR-0018 Follow-ups.
- **The 0.8.0 known gap is unchanged and still open.** `drift-report.sh`'s §04
  check greps the literal `13 Red Flags — STOP → DELETE → RESTART` heading, so it
  still reports DRIFT for a host that legitimately appends a flag and updates the
  count per the 0.8.0 rules — which `claude-workflow` now does (its host-specific
  flag sits at position 14). That finding is **expected and is a defect in the
  check, not in the host**. Deliberately not fixed here; tracked separately.

## [0.8.0] — 2026-07-14

Additive minor release. One section clarified; no canonical prose reworded.

### Changed
- **`spec/04-red-flags.md`** — the section contradicted itself. It required
  hosts to "reproduce the block below verbatim" *and* stated that "adding red
  flags is permitted". No host could satisfy both: appending a 14th flag
  necessarily changes the heading count, the numbering, or both. A host that
  exercised the permission was non-conformant under the verbatim rule; a host
  that honored the verbatim rule could not exercise the permission.

  v0.8.0 makes the permission usable by scoping what "verbatim" binds:
  - Host-specific flags MUST be **appended after** the canonical 13 (position
    14+). Inserting one between canonical flags is now explicitly forbidden.
  - The canonical 13 therefore keep positions **1–13**, in the listed order,
    with the listed wording.
  - The heading's **leading count is not normative** — a host that appends
    updates it to its own total (`## 14 Red Flags — STOP → DELETE → RESTART`).
    The rest of the heading stays canonical and MUST NOT be reworded.

  Rationale: pinning the canonical 13 to positions 1–13 keeps the block's first
  thirteen numbered lines byte-identical across hosts, so conformance is an
  exact match rather than an order-preserving subsequence search that has to
  strip numbering first.

  **The 13 canonical flags are untouched** — no wording, no order, no
  additions. This is a clarification of the rules *around* the block, not a
  change to the block. Per the versioning policy a reworded canonical block
  would be a major; this is not one.

### Host-implementer actions
- **A host that adds no red flags** (`codex-workflow`, `opencode-workflow` —
  both reproduce the canonical 13 exactly) needs **no action**. It is already
  compliant with the 0.8.0 rules and may claim 0.8.0 on its next audit.
- **A host that inserts a host-specific flag between the canonical 13** must
  move it to the end. Known case: `claude-workflow`'s `skill/SKILL.md` carries
  `8. /gsd-review skipped — no {phase}-REVIEWS.md artifact`, which renumbers
  canonical 8–13 into 9–14. Moving it to position 14 restores canonical
  numbering; its heading may stay `## 14 Red Flags — …` (the count is not
  normative). All 13 canonical flags are already byte-identical there, so this
  is a reordering, not a rewrite.
- **A host staying at its current claim needs no action at all.**
  `implements_spec` names the version the host claims; a host citing 0.4.0
  remains conformant at 0.4.0. All three scaffolders currently cite 0.4.0.

### Known gap
- **`tools/drift-report.sh` does not yet implement these rules.** Its §04 check
  greps the literal heading `13 Red Flags — STOP → DELETE → RESTART`, so it
  still reports DRIFT for a host that legitimately appends a flag and updates
  the count — including `claude-workflow` after it complies. Its other two §04
  checks are substring matches (`Code written before the test`, `This case is
  different because`), which match reworded flags too and therefore pass on
  prose that violates "with the listed wording". Deliberately not fixed here:
  the check should assert the thirteen canonical flag lines rather than the
  heading. Tracked separately.

### Added — registry and tooling

Shipped alongside the §04 clarification; no conformance impact of their own.

- **`reference-implementations/README.md`** — row for
  [`opencode-workflow`](https://github.com/agenticapps-eu/opencode-workflow)
  (scaffolder for opencode, spec **0.4.0**, `full`). The host has been shipping
  since its fork from `codex-workflow` but was never registered here, so it was
  absent from the adoption table and invisible to every fleet-level check.
- **`tools/drift-report.sh`** — `opencode-workflow` added to `HOSTS`. It passes
  all 15 canonical-phrase checks (§01, §03, §04, §05, §11) on first inclusion.

### Fixed
- **`tools/drift-report.sh` resolved no hosts at all.** `HOSTS_DIR` defaulted to
  a hardcoded `~/Sourcecode`, which silently stopped resolving once the repos
  were reorganized into per-family subdirectories (`~/Sourcecode/agenticapps/…`).
  Every host reported `SKIP: not cloned` and the summary read `0 OK / 0 DRIFT /
  60 SKIP` — a green-looking report that had in fact checked nothing. The default
  now derives from `BASH_SOURCE` (the spec repo's parent, where the host clones
  are siblings), so it stays correct wherever the family tree lives. An explicit
  path argument is unaffected.

  With the path fixed, the report resolves for the first time: **67 OK / 8 DRIFT
  / 0 SKIP**. The 8 findings are advisory and pre-existing —
  `pi-agentic-apps-workflow` (3, §11) and `agenticapps-dashboard` (4, §04 + §11)
  are expected (adoption pending / consumer-only, no ritual surface). The one
  worth a look: **`claude-workflow` is missing §04's `13 Red Flags — STOP →
  DELETE → RESTART`** despite being the source of canonical prose and claiming
  `full`. Not addressed here — flagged for its own PR.

## [0.7.0] — 2026-07-06

Additive minor release. One new conditional spec section and one ADR.
Hosts at v0.6.0 remain conformant for v0.6.0 claims; hosts wishing to
claim v0.7.0 wire the knowledge-capture trigger points and skip
behavior per the host-implementer actions below. Repos opt in
individually; a repo that never opts in is conformant-by-skip.

### Added

- **`spec/15-knowledge-capture.md`** — declarative contract for
  capturing transferable learnings into the operator's Obsidian vault
  as a cross-repo, human-readable memory (one note per repo). Six
  requirements: three MUST-level trigger points (session handoff, plan
  completion, phase completion — each as the final step of its ritual,
  after the ritual's artifact is committed, never failing the ritual);
  destination resolved exclusively from an opt-in `knowledge_capture`
  block in `.planning/config.json` (`enabled`, `note`) — vault paths
  hardcoded in host skill logic are non-conformant; silent graceful
  skip (one info line, no error, no folder creation) when the block is
  absent, disabled, or the note's parent folder does not exist (other
  machines, CI, containers); a note schema mirrored from the
  vault-side `CLAUDE.md` (curated `## Key Learnings` targeting ~10–20
  items; append-only newest-first `## Log` with
  `### YYYY-MM-DD — <handoff|plan|phase> — <short title> (<host>)`
  headings; create-from-template on first write); a selectivity bar of
  1–5 transferable learnings per trigger with nothing-qualifies →
  write nothing (status updates, plan restatements, and facts already
  in ADRs/handoffs do not qualify); and vault-safety rules (touch only
  the configured note; no secrets, no client-confidential data).
  Architecture: contract in core, generators in hosts — the two-layer
  shape §10 / ADR-0014 established for observability.
- **`adrs/0017-knowledge-capture-obsidian.md`** — records the decision
  to lift learnings out of per-repo `session-handoff.md` (where they
  are overwritten and never cross repos or hosts) into a per-repo
  vault note, the per-repo-config / no-hardcoded-paths stance, the
  rejected alternatives (handoff-only, family wiki, central memory
  service, hardcoded paths), and the consequence that the external
  path dependency is opt-in and machine-local while downstream hosts
  must mirror via their own migrations.

### Changed

- **`spec/09-conformance.md`** — §15 added to the `full`
  declarative-MUST list with its wired-per-host / activated-per-repo
  rule; new "Knowledge-capture checks (§15)" block naming the three
  review checks (trigger wiring present in host ritual instructions,
  config block honored with no hardcoded vault path, graceful-skip
  behavior); version references advanced to 0.7.0.
- **`spec/00-overview.md`** — §15 added to the declarative-contract
  index and the version history; `spec_version` advanced to 0.7.0.
- **`reference-implementations/README.md`** — "Current spec version"
  header advanced to 0.7.0 (it had been left at 0.4.0 through the
  0.5.0/0.6.0 releases). Host rows untouched — hosts move themselves
  via their own adoption PRs.

### Host-implementer actions

- A **consumer-only** host (e.g. the dashboard) has no ritual surface
  and is trivially conformant — no action.
- A host with session-handoff / plan / phase rituals claiming v0.7.0
  wires the knowledge-capture write as the final step of each of the
  three rituals, reads the destination from the repo's
  `knowledge_capture` config block, and implements the silent skip.
  Propagation machinery (the `claude-workflow` / `codex-workflow` /
  pi migrations and config-template updates) is a separate brief that
  depends on this section.
- **Repos** opt in by adding the `knowledge_capture` block to
  `.planning/config.json` on machines where the vault exists. No
  repo-side action is required to stay conformant.

## [0.6.0] — 2026-06-17

Additive minor release. One new conditional spec section and one ADR.
Hosts at v0.5.0 remain conformant for v0.5.0 claims; hosts wishing to
claim v0.6.0 satisfy §14 for each LLM-prompt-building stack, or declare
the trivial / single-shot delta per the host-implementer actions below.

### Added

- **`spec/14-prompt-injection.md`** — declarative contract,
  architecture-first, for projects that build LLM prompts from
  non-self-authored values. Seven requirements with per-language
  bindings: trust classification at the call site (tenant-untrusted /
  tenant-trusted, fail-closed); static CI enforcement (TypeScript
  custom ESLint rule, Go `go/analysis` analyzer, with the inline-only
  v1 limitation documented per host); a refreshable untrusted-input
  registry; runtime trust separation via a `fenceUntrusted` contract;
  output schema-validation plus a leak canary; least privilege
  (allowlist + confirmation) for tool-calling agents; and a dynamic
  (input × attack-family × payload) regression matrix with model-drift
  pinning. Includes a "Detection is the weakest layer" prose block
  naming detection as defense-in-depth only, never a guarantee.
  Provenance: generalized from `fx-signal-agent`'s REQ-SEC03 / D-05
  tenant-untrusted tagging and D-06 attack-matrix test into a
  stack-agnostic contract, the way §10 generalized the observability
  wrapper.
- **`adrs/0016-prompt-injection-defense.md`** — records the decision to
  lift the fx-signal-agent pattern into a portable spec section and the
  architecture-first stance (detection is the weakest layer; the
  load-bearing guarantees are trust separation, output validation, and
  least privilege).

### Changed

- **`spec/02-hook-taxonomy.md`** — the `security` gate (which already
  fires on LLM trust boundaries) now requires SECURITY.md to record §14
  conformance evidence when the changeset touches an LLM prompt-building
  path; `spec_version` advanced to 0.6.0.
- **`spec/09-conformance.md`** — §14 added to the `full` declarative-MUST
  list with its conditional-applicability rule (hosts with no LLM
  prompt-building surface are trivially conformant via a spec delta);
  version references advanced to 0.6.0.
- **`spec/00-overview.md`** — §14 added to the declarative-contract
  index and the version history; `spec_version` advanced to 0.6.0.

### Host-implementer actions

- A host with **no LLM prompt-building surface** (e.g. the dashboard)
  declares §14 N/A under "Spec deltas" and remains conformant.
- A host with a **single-shot** surface (prompt → JSON, no tool
  dispatch) satisfies 14.1–14.5 and 14.7 and records 14.6 (tool
  least-privilege) as N/A.
- A host with an **LLM prompt-building surface** claiming v0.6.0
  satisfies §14.1–14.7 for each such stack. Propagation machinery (the
  `claude-workflow` migration + `add-injection-guard` generator) is a
  separate brief that depends on this section.

## [0.5.0] — 2026-06-03

Additive minor release. (Backfilled 2026-06-17 — the 0.5.0 spec change
shipped without a CHANGELOG entry; reconstructed from `00-overview.md`
and the git history for a coherent version record.)

### Changed

- **`spec/02-hook-taxonomy.md`** — added the `plan-review`
  pre-execution gate, specifying the robust phase-resolution order and
  the grandfather rule for phases planned before the gate existed.
  Hosts claiming v0.5.0 bind the new gate where its trigger condition
  can occur.

## [0.4.0] — 2026-05-20

Additive minor release. Three new spec sections and one host-agnostic
ADR placeholder. Hosts at v0.3.2 remain conformant for v0.3.2 claims;
hosts wishing to claim v0.4.0 satisfy the new sections per the
host-implementer actions block below.

### Added

- **`spec/11-coding-discipline.md`** — canonical-prose section with
  four short rules (Think Before Coding, Simplicity First, Surgical
  Changes, Goal-Driven Execution), each followed by 5–6 anti-pattern
  bullets the rule prevents. Provenance: distilled from public
  discussion of recurring failure modes in coding-agent output
  (Karpathy, 2025-2026), as gathered in the community skill
  collection `multica-ai/andrej-karpathy-skills`. Hosts updating to
  v0.4.0 MUST reproduce the canonical block verbatim in their
  primary project-instruction file (CLAUDE.md, AGENTS.md, or
  equivalent).
- **`spec/12-authoring-conventions.md`** — declarative contract for
  authoring host SKILL.md, AGENTS.md, and contract spec files. Three
  SHOULD/MAY-level requirements: SHOULD render branchy workflows as
  Mermaid `flowchart` diagrams with explicit cycle/fallback paths
  and a REPORT terminal; SHOULD keep judgment-heavy passages in
  prose; MAY combine both within a single section. Plus an advisory
  on placement of behavior-critical prose given known
  long-context-attention drop-off. Cites Xiao et al., *FlowBench*
  (EMNLP 2024 Findings, arXiv:2406.14884) and Liu et al., *Lost in
  the Middle* (arXiv:2307.03172, TACL 2024).
- **`spec/13-ts-declare-first.md`** — declarative contract for a
  host-provided `ts-declare-first` skill (host-named equivalents
  permitted). SHOULD-level for hosts that target TypeScript
  projects. Defines a three-phase discipline: Phase 1 produces a
  `declare`-only type-surface file with zero implementation bodies;
  Phase 2 produces tests that import and exercise the declared
  surface and fail in the expected way; Phase 3 produces the
  implementation whose exported signatures match the declarations
  exactly. Piggy-backs on §06 for evidence shapes; integrates with
  the §02 `verification` gate; MUST NOT collapse Phase 1 and Phase 3
  into a single commit.
- **`adrs/0015-secret-scanner.md`** — placeholder ADR. Status:
  Proposed; Decision: **TBD pending evaluation in claude-workflow's
  `feat/v1.14.0-workflow-additions` branch**. Reserves the ADR
  number and gives the downstream evaluation a stable target file to
  populate with the benchmark outcome. Context captures the
  candidates (`gitleaks` vs `betterleaks`) and the four evaluation
  criteria the populated Decision must address (true-positive
  recall, false-positive rate, migration cost, CI runtime).

### Changed

- **`spec/00-overview.md`** — section-list updated to include §11 as
  canonical prose and §12, §13 as declarative contracts. Explanatory
  paragraph extended to cover the v0.4.0 additions. Frontmatter
  `spec_version` bumped to 0.4.0.
- **`spec/09-conformance.md`** — §11 added to the canonical-prose
  list (item 1 under `full`); §12 and §13 added to the declarative-
  MUST list (item 2 under `full`), with §13 noted as
  TypeScript-target-only. `implements_spec` citation-format example
  bumped from `0.3.0` to `0.4.0`. Header prose updated from "at
  version 0.3.0" to "at version 0.4.0". Frontmatter `spec_version`
  bumped to 0.4.0.
- **`reference-implementations/README.md`** — current-spec version
  noted as 0.4.0. Host conformance rows unchanged; hosts move to
  v0.4.0 via their own adoption PRs.

### Host implementer actions

- **All hosts.** Reproduce the §11 canonical block verbatim in
  CLAUDE.md / AGENTS.md / equivalent at the host's next minor
  release. Bump `implements_spec` to `0.4.0` after the block is in
  place and any other applicable sections (§12, §13) are satisfied.
- **All hosts.** Audit existing SKILL.md / AGENTS.md / contract spec
  files against §12 at next significant rewrite. Convert branchy
  workflows to Mermaid `flowchart` diagrams with explicit
  cycle/fallback paths. Bulk conversion is not required; the
  obligation is SHOULD-level and applies to newly authored sections
  at or after v0.4.0 adoption.
- **TS-targeting hosts (`claude-workflow`, `codex-workflow`).** Ship
  a `ts-declare-first` skill (or host-named equivalent) satisfying
  §13's Phase 1 / Phase 2 / Phase 3 contract and integrating with
  the §02 `verification` gate. Non-TS-targeting hosts MAY omit the
  skill and SHOULD record the omission as a spec delta per §09.
- **`pi-agentic-apps-workflow`, `agenticapps-dashboard`.** Adoption
  pending at v0.1.0; absorb v0.2.0 → v0.4.0 additions at adoption
  time. Dashboard is consumer-only and not affected by §11, §12, or
  §13 directly.
- **`claude-workflow`** specifically additionally drives the
  benchmark that populates ADR-0015's Decision block. Until that
  benchmark lands, ADR-0015 ships as Proposed; hosts SHOULD continue
  using `gitleaks` as the de facto default and SHOULD NOT switch
  defaults based on the Proposed status alone.

## [0.3.2] — 2026-05-18

Patch release: §10.5 Flush-primitive obligation codified. Most existing
hosts already satisfy it implicitly via host-runtime await
(`ts-cloudflare-worker`, `ts-cloudflare-pages`, `ts-supabase-edge`,
`ts-react-vite`); the change moves the obligation from "implicit
best-practice" to "explicit MUST" so generators in languages without
runtime-await for short-lived processes (Go today; future Rust/Python/
Node-on-bare-V8) cannot ship without addressing it.

### Documentation

- **§10.5 Flush primitive** — added MUST-level bullet between the
  existing "Non-blocking emission" and "Fail-safe behavior" bullets.
  Wrappers MUST expose a `Flush(timeout)` (or idiomatic equivalent)
  that drains in-flight emission goroutines/microtasks INTO the
  destination SDK's transport BEFORE draining the SDK's own buffer.
  Short-lived processes MUST call it before exit; long-running services
  need not. Implementations MUST report success when the destination
  SDK was never configured (no DSN), since the emission-layer drain is
  the only contract `Flush` has in that mode. Witness: factiv/cparx
  2026-05-18 Sentry adoption verification — wrapper-routed events were
  silently dropped from CLI smoke tests because `sentry.Flush` raced
  against fire-and-forget emission goroutines.

### Conformance impact for host implementers

- **`claude-workflow`** (current `implements_spec: 0.3.0`) — `ts-*`
  templates satisfy the new obligation implicitly via host-runtime
  await. `go-fly-http` template needs an explicit `Flush(timeout)`
  addition; PR #36 ships the fix at `add-observability` v0.3.3.
  After PR #36 merges, claude-workflow can bump `implements_spec`
  0.3.0 → 0.3.2.
- **`codex-workflow`** — no observability templates today; not affected.
- **`pi-agentic-apps-workflow`** — adoption pending; absorbs the
  obligation at adoption time.
- **`agenticapps-dashboard`** — consumer-only; not affected.

## [0.3.1] — 2026-05-15

Patch release: ADR-0011 addendum documenting the upstream
`pbakaus/impeccable` CLI rename. No conformance impact — addendum
clarifies the existing decision.

### Documentation

- **ADR-0011 addendum** documenting the upstream `pbakaus/impeccable`
  CLI rename (`critique` subcommand removed in v1.0.1; v1.x
  unpublished from npm; v2.x emits a finding-list shape under
  `npx impeccable detect`). Skill hook syntax
  (`impeccable:critique`, `impeccable:audit`) is unchanged and
  continues to satisfy the gate-point contract. Hosts with
  CLI-based CI gates have two response options (migrate to `detect`
  or adopt per-phase artifacts); both satisfy the ADR.

### Conformance impact for host implementers

- None. Addendum clarifies the existing ADR-0011 decision; hosts
  at v0.1.0 / v0.2.0 / v0.2.1 / v0.3.0 remain conformant. Hosts
  with standalone CLI-based CI gates that called
  `npx impeccable critique` directly need to migrate, but the
  skill-based hook syntax (the canonical reference path) is
  unchanged.

## [0.3.0] — 2026-05-15

Conformance enforcement layer for §10 observability. Additive minor —
hosts already at v0.2.1 remain conformant for v0.2.1 claims.

### Added

- **`spec/10-observability.md` §10.9 Conformance enforcement** — new
  sub-section. Defines three primitives generators MUST support
  (delta scan via `--since-commit`, baseline file at
  `.observability/baseline.json`, CI-integration guidance) plus an
  optional pre-commit hook (§10.9.4). Baseline JSON schema includes a
  per-checklist breakdown of high-confidence gaps so dashboards can
  surface richer state; baseline updates happen on successful
  `scan-apply` or via explicit `scan --update-baseline`, never
  silently on read-only scans.
- **`spec/10-observability.md` §10.7 fifth bullet** — generators MUST
  support delta scan and maintain the §10.9 baseline. The baseline
  file is the source of truth for "what conformance level is this
  project currently at?"
- **`spec/10-observability.md` §10.8 `enforcement:` sub-block** —
  OPTIONAL field in the project metadata block declaring baseline /
  CI workflow / pre-commit paths. Projects that omit it default to
  the canonical baseline path and no CI gate; projects that declare
  it MUST satisfy the per-field §10.9 contract.
- **`adrs/0014-observability-architecture.md` v0.3.0 follow-up
  subsection** — documents what shipped in v0.3.0 (closes deferred
  gap G7 from the cparx 2026-05-10 pilot rollout plan), what's
  deferred to v0.4.0 (handler-entry vs background-work split per
  cparx gap G3; medium-confidence gate threshold pending data from
  first host CI deployment).

### Changed

- **`spec/00-overview.md`** — section-list updated to include §10 as
  a declarative contract; explanatory paragraph added about §10's
  v0.2.0 → v0.2.1 → v0.3.0 trajectory and how hosts choose which
  version to claim. Frontmatter `spec_version` bumped to 0.3.0.
- **`spec/09-conformance.md`** — §10 added to the declarative-MUSTs
  list (item 2 under `full` conformance). `implements_spec`
  citation-format example bumped from `0.1.0` to `0.3.0`. Header
  prose updated from "at version 0.1.0" to "at version 0.3.0".
  Frontmatter `spec_version` bumped to 0.3.0.

### Conformance impact for host implementers

- Hosts at v0.2.1 remain conformant for v0.2.1 claims (additive
  minor).
- Hosts wishing to claim v0.3.0 MUST update their generator skill
  to satisfy §10.9.1–§10.9.3 (delta scan, baseline maintenance,
  CI-integration reference workflow). §10.9.4 (pre-commit hook) is
  MAY.
- Projects claiming v0.3.0 conformance SHOULD prevent regression
  per §10.9; the MUST inside §10.9.3 is that opt-out (deleting or
  emptying the baseline) MUST NOT be silent — the CI workflow logs
  it visibly so reviewers see enforcement is disabled.

## [0.2.1] — 2026-05-13

Patch release: §10 amendments from the cparx 2026-05-10 pilot.

### Changed

- **`spec/10-observability.md` §10.5** — added a note on host
  recoverer interaction. When a project already uses a
  framework-level panic/error recoverer (Chi's `chimw.Recoverer`,
  Express's error handler, Fastify's `setErrorHandler`), the
  observability wrapper's middleware SHOULD be mounted inside the
  recoverer so error capture sees the original exception, not the
  recovered response. Recommendation, not a MUST. Source: cparx
  pilot 2026-05-10, gap G4.
- **`spec/10-observability.md` §10.7.1** — added explicit
  module-root path resolution rule. Generators MUST resolve target
  paths against the language module root (the directory containing
  `go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml`,
  `deno.json`), not the project root. Multi-language monorepos run
  the generator independently for each detected stack. Source:
  cparx pilot 2026-05-10, gap G1.

### Conformance impact for host implementers

- Hosts at v0.2.0 remain conformant for v0.2.0 claims (clarifications,
  not new requirements).
- Hosts wishing to claim v0.2.1 SHOULD update their templates to
  apply the recoverer recommendation and MUST update their generator
  to resolve target paths against module roots if their stack
  templates ship anywhere other than the repo root.

## [0.2.0] — 2026-05-10

First observability spec section. Introduces the contract for
event emission, trace context propagation, mandatory instrumentation
points, and the generator obligation.

### Added

- **`spec/10-observability.md`** — declarative contract for
  observability. Defines the wrapper interface (`logEvent`,
  `captureError`, `startSpan`), the seven-field event envelope, W3C
  `traceparent` as the cross-service correlation primitive, four
  mandatory instrumentation points (handler entry, outbound calls,
  caught errors, business events), operational requirements
  (non-blocking emission, fail-safe behavior, PII discipline,
  sampling), destination independence, the generator obligation, and
  the project metadata block. Host-agnostic and vendor-agnostic.
- **`adrs/0014-observability-architecture.md`** — two-layer
  architecture decision: normative contract in the core spec +
  per-host generator skill that produces conformant code for each
  tech stack. Documents nine rejected alternatives (vendor-direct
  installs, OTel-direct, single-service logo-wall vendors,
  one-vendor-per-concern, internal package distribution, spec-only,
  generator-only, auto-apply, defer-until-first-incident).

### Conformance impact for host implementers

- Hosts at v0.1.0 remain conformant for v0.1.0 claims (additive
  minor).
- Hosts wishing to claim v0.2.0 MUST provide an observability
  generator skill satisfying §10.7 and MUST produce projects that
  satisfy §10.1–§10.6 + §10.8.

## [0.1.0] — 2026-05-09

First public release. Establishes the canonical specification baseline.

### Added

**Spec (10 files):**
- `spec/00-overview.md` — workflow elevator pitch, four pillars, and
  glossary of six terms (gate, hook, phase, plan, verification, ADR).
- `spec/01-commitment-ritual.md` — canonical Step 0 commitment block.
  Reproduction required verbatim by host implementations; substitution
  permitted inside `{{...}}` placeholders.
- `spec/02-hook-taxonomy.md` — declarative contract enumerating 15
  named gates (brainstorm-ui, brainstorm-architecture, design-shotgun,
  design-critique, tdd, ui-preview, verification, spec-review,
  code-review, security, database-security, qa, impeccable-audit,
  db-pre-launch-audit, branch-close) with trigger conditions, required
  evidence artifacts, and binding guidance.
- `spec/03-rationalization.md` — canonical 7-row rationalization table.
- `spec/04-red-flags.md` — canonical 13 red flags.
- `spec/05-pressure-test.md` — canonical 3-question pressure test.
- `spec/06-evidence-rules.md` — declarative verification-before-completion
  contract. Permitted evidence shapes (test output, grep result, curl
  response, screenshot path, file existence, diff snippet); forbidden
  patterns (manually verified, trust me); 1:1 evidence-to-`must_have`
  correspondence requirement.
- `spec/07-two-stage-review.md` — declarative two-stage review contract.
  Stage 1 (spec compliance) before Stage 2 (code quality); independent
  reviewer agent required for Stage 2; forbidden collapses enumerated.
- `spec/08-migration-format.md` — declarative migration file format.
  Filename convention, frontmatter fields, four-section step structure,
  idempotency contract, atomicity contract, dry-run mode requirement.
- `spec/09-conformance.md` — full / partial / consumer-only conformance
  levels, citation format (`implements_spec: 0.1.0` in host frontmatter),
  allowed extensions, drift policy.

**ADRs (4 files):**
- `adrs/0010-backend-language-routing-go.md` — per-language Stage 2
  review skill packs.
- `adrs/0011-impeccable-design-quality-gate.md` — pre-phase critique +
  finishing audit via `pbakaus/impeccable`.
- `adrs/0012-database-sentinel-rls-audit-gate.md` — RLS sub-gate via
  `Farenhytee/database-sentinel`; CVE-2025-48757, MongoBleed, pgBouncer
  references.
- `adrs/0013-migration-framework.md` — versioned migration framework
  rationale; cross-references spec section 08 for the format spec.

**Reference implementations:**
- `reference-implementations/README.md` — adoption table for
  `claude-workflow`, `pi-agentic-apps-workflow`, `codex-workflow`, and
  `agenticapps-dashboard`. All rows currently TBD pending each host's
  own adoption PR.

**Tools:**
- `tools/drift-report.sh` — advisory health check (read-only, exit 0
  always). Greps each host clone for canonical phrases. NOT a CI gate
  at v0.1.0.

### Conformance impact for host implementers

This is the first release. Hosts targeting v0.1.0 MUST:

1. Reproduce the four canonical-prose blocks (sections 01, 03, 04, 05)
   verbatim in their host-instruction file.
2. Satisfy the four declarative contracts (sections 02, 06, 07, 08)
   in the host's idiom.
3. Document host-specific bindings for every gate whose trigger
   condition can occur in the host's project type.
4. Add `implements_spec: 0.1.0` to the host's primary instruction-file
   frontmatter.

Hosts that previously authored their own gate-mapping prose should
plan an adoption PR titled "Adopt agenticapps-workflow-core spec
v0.1.0" with its own GSD phase plan. Adoption is honor-system at
this version; the drift-report tool is advisory only.
