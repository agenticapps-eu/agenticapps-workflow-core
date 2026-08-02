## Context

Core authors and publishes four enforcement artifacts — the gate
(`reference-implementations/openspec-change-gate/openspec-change-gate.sh`), the
`pre-commit` wrapper beside it, the CI template at
`reference-implementations/openspec-change-gate/hooks/openspec-gate.ci.yml`, and
the conformance harness at `tools/change-gate-conformance.sh`. Four hosts pin
those bytes and publish them onward to nine projects.

Core runs none of them. Measured on 2026-08-02 at `eccaf18`:

- `.claude/` contains `commands/`, `skills/` and a 96-byte
  `settings.local.json`. There is no `hooks/` directory.
- `.git/hooks/` contains no non-sample hook. `core.hooksPath` is unset.
- `.github/workflows/` contains only `pages-cheatsheet.yml`.

The gap is not merely cosmetic. `tools/change-gate-conformance.sh` is executed
in host CI against the copy that host resolved from its pin. Core — which owns
the file — has no surface that scores it. Conformance is therefore established
downstream of authorship, by repositories whose only evidence that the artifact
is sound is that they pinned it.

Two constraints shape the implementation. `.git/hooks/` is not tracked by git,
so the commit floor cannot arrive by checkout. And in CI there is no
`~/.agenticapps/`, so any design that resolves the shared install must first
publish it.

## Goals / Non-Goals

**Goals:**
- Core enforces §18 against itself at all three interposition points.
- Core's CI becomes the first surface that fails when the gate core publishes
  stops being conformant.
- The gate's existing §18 semantics are preserved exactly; self-enforcement adds
  a deployment, not a stricter rule.

**Non-Goals:**
- Changing what the gate enforces. No requirement in `change-gate-enforcement`
  moves.
- Editing any pinned artifact. The seven files named in every host's
  `core-vendor.manifest` are consumed, not modified, so no host pin can be
  invalidated by this change.
- Fixing the published `pre-commit` wrapper's `<repo>/bin/` fallback. That
  defect is real and is already in `shim-project-hooks`'s scope; duplicating it
  here would put two changes on the same lines.
- Wiring `meta-observer`, `skill-router-log` or any other hook. This change
  installs the change gate only.

## Decisions

### Decision 1 — Core resolves its working-tree copy, not the shared install

Every consuming project installs a shim that prefers
`~/.agenticapps/bin/openspec-change-gate.sh`. Core inverts that and resolves
`reference-implementations/openspec-change-gate/openspec-change-gate.sh`
directly.

*Why.* Core is the source of truth for that file. Gating core with the published
copy tests whichever host's installer ran last on this machine, which is the
race `issue #32` records — it proves nothing about the bytes core ships. It also
does not work in CI, where no shared install exists.

The payoff is specific: scoring the working-tree copy makes core's own pull
request the earliest possible detector of gate drift. The harness gives the
current implementation **71 passed, 0 failed**, so the job starts green and any
regression turns core red before a host advances a pin to it.

*Alternative considered — vendor the standard project shim.* Maximum
consistency, and core would eat exactly the fleet's dogfood. Rejected because it
inverts the value: core would be gated by a copy it cannot vouch for, and CI
would have to run `install-shared-artifact.sh` first, making the job test the
installer rather than the gate.

*Alternative considered — split by layer* (shim locally, source in CI).
Rejected as the worst of both: two resolution paths to keep honest, and an
interactive session in core would be gated by a different implementation than
its own CI, so a local pass would not predict a CI pass.

*Cost, accepted.* Core's gate can now differ from what the fleet runs. This is
the intended trade, and the CI job is precisely what converts a silent
divergence into a visible one.

### Decision 2 — Core does not vendor the published `pre-commit` verbatim

The published wrapper resolves
`${OPENSPEC_GATE:-${OPENSPEC_CHANGE_GATE:-$HOME/.agenticapps/bin/…}}` and falls
back to `<repo>/bin/openspec-change-gate.sh`. Core has no `bin/`, so vendoring
it unmodified would resolve the shared install — contradicting Decision 1 — or,
absent that, warn and exit 0, gating nothing.

Core therefore gets its own short `pre-commit`, written by
`tools/install-core-git-hooks.sh`, that resolves the working-tree path and
`exec`s it with `--pre-commit`.

*Alternative considered — set `OPENSPEC_GATE` in core's git config or a
`.envrc`.* Rejected: it makes correct behaviour depend on ambient environment
that is invisible in the repository and absent in CI, and it would silently
change the gate used by any other tool in the session that honours the variable.

### Decision 3 — The commit hook ships as an installer that resolves its target

The hooks directory cannot be populated by checkout, so an installer is needed.
Two things the first revision of this design got wrong, both caught in review:

**It must not write a literal `.git/hooks/` path.** In a linked git worktree
`.git` is a *file*, not a directory, so that path does not exist. Verified on
this machine against `agenticapps-dashboard-add-agent-board`: `.git` is ASCII
text, and `git rev-parse --git-path hooks` resolves to
`…/agenticapps-dashboard/.git/hooks` — the main checkout's directory. The
installer therefore resolves the destination with `git rev-parse --git-path
hooks`, and reports that a hook installed from a worktree is shared with the
main checkout.

**It must detect `core.hooksPath`.** If that setting is configured, git ignores
the default hooks directory entirely, so an installer blind to it writes a hook
that can never fire — worse than not installing, because it looks installed. The
installer reports the conflict and exits non-zero.

*Alternative considered — set `core.hooksPath` to a tracked directory ourselves.*
Delivers the hook by checkout, needs no installer. Rejected because the setting
is repository-global: it redirects *every* hook, silently disabling anything else
a developer relies on. A large side effect for one gate, and invisible from the
working tree.

*Consequence, disclosed.* A clone where the installer has not run is not gated
at commit time.

### Decision 4 — Ownership by marker, not by byte equality

Review split on this. codex asked for exact-byte or hash verification of
installer ownership; opencode asked for a defined upgrade path when a hook core
wrote has since gone stale. **Those two cannot both be satisfied by byte
equality**: under it, a hook core wrote and later revised reads as foreign and is
refused permanently, so the gate could never be advanced. That is the opposite
of the intended behaviour, so this design takes the marker and makes its
semantics explicit rather than leaving them implied — no hook, current hook,
stale marked hook, and unmarked hook each get a defined outcome.

*Accepted limit, recorded rather than implied.* A marker is an ownership claim,
not an integrity proof. A hand-edited hook carrying the marker will be treated as
core's and updated in place, and an adversarially marked hook likewise. For a
repository-local convenience script whose whole purpose is to install a
locally-bypassable `--no-verify`-able hook, that is proportionate; asserting
otherwise would be security theatre.

### Decision 5 — The scorer is bounded, because it scores itself into a corner

The headline claim is that core proves the gate conformant. The harness that
does the proving is a working-tree file executed from the same checkout as the
gate it scores, so a change that guts the harness — deleting rows, inverting
expected exit codes — yields a green job while certifying a drifting gate. The
"named target is missing" case only covers zero-of-zero; it says nothing about a
row count quietly falling from 71 to 3.

The CI job therefore asserts a **minimum scored-row count** as a literal, and
fails below it. A floor may be raised as rows are added; lowering it requires an
explicit recorded decision, which is the point — the number is a tripwire that
has to be edited deliberately and shows up in the diff.

*Alternative considered — pin a digest of the harness.* Stronger, but it makes
every legitimate harness edit a two-step dance and turns an honest row addition
into a merge conflict. The row-count floor catches the failure mode that
actually matters (silent weakening) at a fraction of the friction.

### Decision 6 — A new capability, not an amendment

`change-gate-enforcement` has six requirements and all six are parsing and
verdict semantics: what counts as a reviewer, what the trailer grammar is, how a
review binds to what it reviewed. Its stated Purpose is what the gate "enforces
and what it merely reports". Which repositories wire the gate, and how they
resolve it, is a different subject. Folding self-enforcement in would give a
spec with one crisp purpose a second, unrelated one.

## Risks / Trade-offs

- **Installing a gate could deadlock work on the open `shim-project-hooks`
  change** → Measured rather than assumed, against the repo as it stands with
  that change open and its `REVIEWS.md` stale: `--ci` exits 0, `--pre-commit`
  exits 0, a `PreToolUse` payload on product code exits 0, malformed stdin exits
  0, and an edit to the change's own `tasks.md` exits 0. Gate 2.0.0 blocks only
  on `openspec validate --all`, which is green (4 passed, 0 failed). No deadlock
  exists, and this change does not depend on `shim-project-hooks` landing.

- **Core's gate drifts from the fleet's published copy** → This is Decision 1's
  accepted cost, and the CI job is the mitigation: divergence becomes a red
  build in core rather than an undetected difference.

- **A `PreToolUse` hook cannot gate its own installing session** → Inherent, and
  named as such by §18 rather than treated as a defect. The pre-commit and CI
  floors are what the requirement rests on. Disclosed in the spec delta.

- **The installer is a manual step a contributor may skip** → CI is the floor
  beneath it, and the spec delta makes the ungated-clone case an explicit
  scenario rather than an oversight.

- **Adding a CI job to a repo that had almost none could surprise open work** →
  The job runs `openspec validate --all` and the harness, both of which pass on
  `main` today. Its first run is on this change's own pull request, where it is
  observable before it can affect anything else.

- **CI is called a floor but does not block a merge** → Verified: core's `main`
  has no branch protection and no rulesets, so a failing check is advisory. The
  spec delta is worded to match reality — the job runs and reports — and the
  absent floor is recorded as a §09 delta. Making the check required is a
  repository setting, deliberately left outside this change.

- **A missing `openspec` CLI blocks every edit** → Verified in the gate source:
  the CLI-absent branch does `return 2`. Because core almost always has a change
  open, a contributor without the CLI is hard-blocked locally. This is inherited
  §18 behaviour and is preserved deliberately, not introduced — but the gate's
  fail-open reputation makes it surprising, so it is now an explicit scenario
  rather than a footnote.

- **The `PreToolUse` hook is a new code-execution surface in core** → After this
  change, editing a file executes a script from the working tree, so checking
  out an untrusted branch and editing anything runs that branch's shell. Already
  true of all four hosts; new to core. The trust boundary is the checkout, and
  it is stated rather than left implicit. It also argues for landing the CI job
  first, which the migration plan already does.

- **The hook is not on every edit path** → Its matcher is
  `Edit|Write|MultiEdit|NotebookEdit`, so `sed -i`, `tee` and redirects through
  `Bash` bypass it entirely. Disclosed as a scenario so a later reader does not
  mistake three interposition points for complete coverage.

- **The CI job executes working-tree scripts after an unpinned global install** →
  The job declares read-only `contents` permission, disables checkout credential
  persistence, and pins the `openspec` CLI to the version core validated against
  (1.6.0), so an upstream release cannot change the verdict for an unchanged
  revision. Core's *published template* carries the same three weaknesses; no
  host pins it, so it is safely fixable, but it is left to a follow-up because
  editing it changes what every host scaffolds.

## Migration Plan

1. Add the CI workflow. It is the floor and the only surface no local
   configuration can bypass; landing it first means everything after is
   gated.
2. Add the `PreToolUse` hook and `.claude/settings.json`.
3. Add `tools/install-core-git-hooks.sh` and run it in this checkout.
4. Record the resolution decision in `adrs/0028-core-gates-itself.md`.

*Rollback.* Every element is additive and independently removable: delete the
workflow file, the hook, the settings entry, or `.git/hooks/pre-commit`. No
existing file changes behaviour, so rollback cannot leave a partial state.

## Open Questions

- Should the four hosts eventually adopt the same source-direct posture for
  *their* vendored harnesses? Out of scope here; raised because this change
  establishes the pattern that would answer it.
