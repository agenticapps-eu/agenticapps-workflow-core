# ADR-0028: Core gates itself, with its own working-tree gate

**Status**: Accepted  **Date**: 2026-08-02  **Change**: `core-gates-itself`

## Context

Core authors and publishes the §18 change gate, the `pre-commit` wrapper, the CI
workflow template and the conformance harness. Four hosts pin those bytes and
publish them onward to nine projects.

Core ran none of them. Measured at `eccaf18`: no `.claude/hooks/`, no non-sample
hook in the resolved hooks directory, `core.hooksPath` unset, and only
`pages-cheatsheet.yml` in `.github/workflows/`.

The cost was not cosmetic. `tools/change-gate-conformance.sh` runs in *host* CI
against the copy that host resolved from its pin, so the conformance of the
artifact core authors was established downstream, by repositories whose only
evidence it was sound is that they had pinned it. No surface in core would have
gone red first.

## Decision

Core runs the gate at all three §18 interposition points — `PreToolUse`,
`pre-commit`, CI — and **all three resolve core's own working-tree
`reference-implementations/openspec-change-gate/openspec-change-gate.sh`**,
never the shared install at `~/.agenticapps/bin/`.

This is the exact inverse of the shim every consuming project installs, and the
inversion is the point. Core is the source of truth for those bytes. Gating core
with a published copy tests whichever host's installer ran last on that machine
— the race issue #32 records — and proves nothing about what core ships. It also
cannot work in CI, where no shared install exists.

The CI job scores the gate with the harness *before* invoking it, and asserts a
minimum scored-row count so a weakened harness cannot certify a drifting gate.
The harness reports 71/71 today, so the job starts green and any regression
turns core's own pull request red before a host can pin it.

**The CI job reports; it does not enforce.** Core's `main` carries no branch
protection and no rulesets, so a red run does not prevent a merge. Recorded as a
§09 delta rather than papered over. Making the check required is a repository
setting, deliberately left outside this change.

## Alternatives Rejected

**Vendor the standard project shim.** Maximum consistency — core would eat
exactly the fleet's dogfood. Rejected because it inverts the value: core would
be gated by a copy it cannot vouch for, and CI would have to run
`install-shared-artifact.sh` first, making the job a test of the installer
rather than of the gate.

**Split by layer** — shim locally, working-tree copy in CI. Rejected as the
worst of both: two resolution paths to keep honest, and a local pass would not
predict a CI pass because the two would run different implementations.

**Set `core.hooksPath` to a tracked directory.** Delivers the hook by checkout
and needs no installer. Rejected because the setting is repository-global: it
redirects *every* hook, silently disabling anything else a developer relies on.

**Byte or hash verification of installer hook ownership.** Requested in review.
Rejected because it cannot coexist with an upgrade path, also requested in
review: under byte equality a hook core wrote and later revised reads as foreign
and is refused permanently, so the gate could never be advanced. Ownership is a
marker with four explicit outcomes instead — and a marker is an ownership claim,
not an integrity proof, which is recorded rather than implied.

**Pin a digest of the harness** instead of a row-count floor. Stronger, but it
turns every legitimate harness edit into a two-step dance and every honest row
addition into a merge conflict. The floor catches the failure mode that matters
— silent weakening — at a fraction of the friction.

## Consequences

- Core's own pull requests are now the earliest place gate drift is detectable.
  This is the substantive gain and the reason for the inversion.
- Core's gate may diverge from what the fleet is running. Accepted; the CI job
  is what makes a divergence visible rather than silent.
- A `PreToolUse` hook cannot gate the session that installs it (§18, inherent).
- A missing `openspec` CLI is **fail-closed** — the gate returns 2 while a change
  is active, and core almost always has one open, so a contributor without the
  CLI is blocked locally. Inherited behaviour, preserved deliberately, disclosed
  because the gate's fail-open reputation makes it surprising.
- The hook's matcher is `Edit|Write|MultiEdit|NotebookEdit`. Edits made through
  `Bash` — `sed -i`, `tee`, redirects — bypass it. Three interposition points
  are not complete coverage.
- The `PreToolUse` hook is a new local code-execution surface in core: editing a
  file executes a working-tree script, so checking out an untrusted branch and
  editing anything runs that branch's shell. Already true of the four hosts, new
  to core. The trust boundary is the checkout.
- The `pre-commit` hook requires running `tools/install-core-git-hooks.sh` per
  clone. A clone where it has not run is not gated at commit time.
- Core's published CI template still carries the supply-chain weaknesses fixed
  in core's own copy (unpinned `npm i -g`, undeclared permissions, persisted
  checkout credentials). No host pins that template, so it is safely fixable;
  left to a follow-up because editing it changes what every host scaffolds.
