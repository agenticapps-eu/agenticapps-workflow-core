## Why

Core publishes the §18 change gate, the pre-commit wrapper, the CI workflow
template and the conformance harness, and runs none of them. `.claude/` carries
no `hooks/` directory, `.git/hooks/` is empty, `core.hooksPath` is unset, and
`.github/workflows/` holds only `pages-cheatsheet.yml`. Every repo core gates is
gated; core is not.

That is conspicuous rather than merely untidy, and it costs something concrete.
Core's own reference implementation is never scored by core. Today a defective
gate is caught only after a host advances its pin, vendors the harness and runs
it in *that* host's CI — so the artifact's conformance is proven downstream of
the repo that authored it, by repos that trusted it. Core has no surface that
would go red first.

## What Changes

- Core runs the §18 gate at all three interposition points the spec names: a
  `PreToolUse` hook, a git `pre-commit` hook, and a CI job. **None of the three
  is an enforced floor**, and the change does not claim one — see Impact.
- All three resolve **core's own**
  `reference-implementations/openspec-change-gate/openspec-change-gate.sh`,
  not the shared install at `~/.agenticapps/bin/`. Core is the source of truth
  for that file; gating core with a published copy would prove nothing about
  the bytes core ships.
- The CI job scores the gate with `tools/change-gate-conformance.sh` **before**
  trusting its verdict, exactly as the template core publishes instructs, and
  asserts a minimum scored-row count so a weakened harness cannot certify a
  drifting gate. This is the substantive gain: core's own pull requests become a
  live conformance test of the artifact core distributes.
- Core gets a `.claude/settings.json` (it has only `settings.local.json` today)
  registering the hook on `Edit|Write|MultiEdit|NotebookEdit`.
- Core gets `tools/install-core-git-hooks.sh`, because `.git/hooks/` is not
  tracked by git and the floor cannot be delivered by checkout alone.

**Not** a change to what the gate enforces. No requirement in
`change-gate-enforcement` moves; the blocking predicate, the reviewer counting
and the reporting behaviour are all untouched.

## Capabilities

### New Capabilities
- `core-self-enforcement`: core enforces §18 against its own repository, at the
  three interposition points, resolving its own reference implementation rather
  than the published copy — and proves the implementation conformant before
  acting on its verdict.

### Modified Capabilities

None. `change-gate-enforcement` defines what the gate computes and what it
reports — its six requirements are parsing and verdict semantics throughout. It
says nothing about which repositories wire the gate or how they resolve it, so
self-enforcement is a new concern rather than an amendment to that one. Adding
it there would give a spec with a crisp single purpose a second, unrelated one.

## Impact

**Files added**
- `.claude/hooks/openspec-change-gate.sh` — core-specific resolver
- `.claude/settings.json` — registers the hook
- `.github/workflows/openspec-gate.yml` — the CI job, which **reports**. It is
  not a floor: `main` carries no branch protection, so a red run does not
  prevent a merge. An earlier revision of this list called it "the CI floor",
  which is the precise claim task 6.7 exists to prevent
- `tools/install-core-git-hooks.sh` — installs the local pre-commit hook
- `tools/test-install-core-git-hooks.sh` — regression tests for that installer,
  run by the CI job. Added because the job scored the gate 71/71 green while the
  installer carried four live defects: the harness scores the artifact core
  publishes, not the code core runs
- `adrs/0028-core-gates-itself.md` — the resolution decision

**Files modified**
- `docs/WORKFLOW.md` — records core's inverted resolution order and the
  disclosed limits. The spec delta requires this documentation, so it must
  appear here; an earlier revision listed only files added, which contradicted
  its own requirement.

**Files not changed**
- `reference-implementations/openspec-change-gate/openspec-change-gate.sh` and
  its `pre-commit` and `hooks/openspec-gate.ci.yml` siblings are consumed, not
  edited. **This change edits none of the files any host pins**, so it cannot
  invalidate a host pin.

  Stated that way deliberately. An earlier revision claimed "all seven manifest
  artifacts are byte-identical between pin `ef030d0` and `main`", which is
  imprecise twice over: pin state is a property of the host repositories and is
  not verifiable from inside core, and the manifests do not agree on seven —
  `claude-workflow` pins seven files, while `codex-workflow`, `opencode-workflow`
  and `pi-agentic-apps-workflow` pin five each, omitting `run-plan-review.sh` and
  `install-shared-artifact.sh`. What this change can assert about itself is that
  it modifies none of them.

- `reference-implementations/openspec-change-gate/hooks/openspec-gate.ci.yml`
  is copied, not edited — but it carries the same supply-chain weaknesses this
  change fixes in core's copy (unpinned `npm i -g`, undeclared permissions,
  persisted checkout credentials). No host pins that template, so fixing it is
  safe; it is nonetheless left to a follow-up, because editing it changes what
  every host scaffolds and deserves its own review rather than riding along
  here. Recorded so the divergence between core's copy and core's template is
  deliberate and visible rather than accidental.

**Interaction with the open `shim-project-hooks` change: none, verified rather
than assumed.** Every gate path was run against the repo as it stands, with that
change open and its `REVIEWS.md` stale:

| invocation | exit | behaviour |
|---|---|---|
| `--ci` | 0 | "all active changes validate"; stale review printed as a NOTE |
| `PreToolUse` on product code | 0 | allowed |
| `--pre-commit` | 0 | allowed |
| malformed stdin | 0 | fails open per §18 |
| edit to the change's own `tasks.md` | 0 | artifact exemption holds |

The gate scores **71 passed, 0 failed** against core's own harness today, so the
CI job starts green.

**Known limits, disclosed rather than discovered later.** Most of these came out
of the Stage 2 review, which returned three REQUEST-CHANGES verdicts.

- **There is no enforced floor.** Core's `main` carries no branch protection and
  no rulesets — verified — so a failing CI check does not prevent a merge. The
  CI job reports; it does not enforce. Recorded as a §09 delta rather than
  papered over, and left as a deliberate repository-settings decision outside
  this change.
- **A missing `openspec` CLI is fail-CLOSED**, not fail-open. The gate returns 2
  when the binary is absent while any change is active. Core almost always has a
  change open, so a contributor without the CLI is blocked locally on every
  non-exempt edit. Inherited gate semantics, correctly preserved — but the
  gate's fail-open reputation makes this genuinely surprising, so it is stated.
- **The hook does not observe every edit path.** Its matcher is
  `Edit|Write|MultiEdit|NotebookEdit`; a `sed -i`, `tee` or redirect through
  `Bash` never reaches it. The three interposition points are not complete
  coverage.
- **The hook is a new local code-execution surface.** After this change, editing
  any file in core executes a script from the working tree, so checking out an
  untrusted branch and editing a file runs that branch's shell. This is already
  true of the four hosts; it is new to core, and the trust boundary is the
  checkout.
- A `PreToolUse` hook cannot gate the session that installs it. §18 names this
  an inherent property.
- Core's gate may now differ from what the fleet is running. That is the
  intended trade; the CI job is what makes such a divergence visible instead of
  silent.
- The `pre-commit` hook requires running the installer per clone, and a marker
  is an ownership claim rather than an integrity proof — a hand-edited hook
  carrying the marker will be updated in place.
