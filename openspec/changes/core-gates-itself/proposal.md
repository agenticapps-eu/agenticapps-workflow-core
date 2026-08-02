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

- Core wires the §18 gate at all three interposition points the spec names: a
  `PreToolUse` hook, a git `pre-commit` floor, and a CI job.
- All three resolve **core's own**
  `reference-implementations/openspec-change-gate/openspec-change-gate.sh`,
  not the shared install at `~/.agenticapps/bin/`. Core is the source of truth
  for that file; gating core with a published copy would prove nothing about
  the bytes core ships.
- The CI job scores the gate with `tools/change-gate-conformance.sh` **before**
  trusting its verdict, exactly as the template core publishes instructs. This
  is the substantive gain: core's own pull requests become a live conformance
  test of the artifact core distributes.
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
- `.github/workflows/openspec-gate.yml` — the CI floor
- `tools/install-core-git-hooks.sh` — installs the pre-commit floor
- `adrs/0028-core-gates-itself.md` — the resolution decision

**Files not changed**
- `reference-implementations/openspec-change-gate/openspec-change-gate.sh` and
  its `pre-commit` and `hooks/openspec-gate.ci.yml` siblings are consumed, not
  edited. Core's copies stay byte-identical to what the four hosts pin, so this
  change cannot invalidate a host pin. Verified: all seven manifest artifacts
  are byte-identical between pin `ef030d0` and `main`.

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

**Known limits, disclosed rather than discovered later**
- A `PreToolUse` hook cannot gate the session that installs it. §18 names this
  an inherent property and requires the pre-commit and CI floors because of it.
- Core's gate may now differ from what the fleet is running. That is the
  intended trade; the CI job is what makes such a divergence visible instead of
  silent.
- The pre-commit floor requires running the installer per clone. This is the
  same limitation every repo has, and CI is the floor beneath it.
