## Why

Applying a migration currently requires an agent to read markdown prose and act
on it. That makes installing the workflow depend on an authenticated coding
agent with token budget, and makes it non-reproducible — two runs against the
same repo can produce different trees. The goal is determinism; testability is a
side benefit, not the case.

The moment is right because the fleet just reached a state that makes the change
cheap: every live install is at head, so no existing migration ever needs to
replay, and the new format can be greenfield rather than a 445-fence retrofit.

## What Changes

- **§08 gains an executable form.** Steps keep their existing `**Label:**` prose
  headings and gain a `role=` tag on each executable fence
  (```` ```bash role=apply ````). Roles: `check`, `precondition`, `apply`,
  `verify` (optional), `rollback`.
- **Un-annotated ```` ```bash ```` fences become explicitly non-executable.**
  This is what lets a migration keep explanatory snippets beside real commands.
- **An ID threshold scopes the format.** The ID comes from the migration's
  **filename**, so it cannot be evaded by omitting a frontmatter field.
  Migrations at or above their host's threshold MUST be executable and MUST
  declare `migration_format: executable`; the declaration is cross-checked
  against the filename and may add a migration to the linter's scope but never
  remove one. Below the threshold, migrations are frozen history and are skipped
  entirely. Retrofit scope is zero by decision.
- **Thresholds are declared in core**, at
  `reference-implementations/migration-runner/THRESHOLDS`, one row per host —
  the same way core already declares `FLEET`, `ARTIFACTS` and `SHIMMED-HOOKS`.
  A host may declare its own later and take precedence.
- **A format linter ships and blocks**, enforcing five rules: required roles
  present (L1), role matches its heading (L2), no duplicate roles (L3),
  unrecognised role values rejected (L4), `role=` only on `bash` fences (L5).
- **The runner lints before it executes**, and refuses a migration yielding zero
  steps or a step with no `apply` block. Catching a bad migration at lint time
  is not enough on its own, because nothing obliges the operator to have linted;
  a runner that executes whatever it is given can be handed an all-illustration
  document and report success having changed nothing.
- **BREAKING (to §08's own text, not to any host): the atomicity contract is
  amended.** §08 currently requires an interactive three-option prompt on
  mid-migration failure, which a non-interactive runner cannot satisfy. Amended:
  prompt when stdin is a TTY; when it is not, abort in place, report which steps
  applied, and roll back nothing. No host implements the executable runner yet,
  so nothing in the fleet is invalidated.
- **The dry-run promise is corrected.** §08 currently says dry-run "prints the
  diff each step would apply." A runner that has not executed `apply` cannot
  produce a diff. It will print the apply block's source instead.
- **Three bash scripts land** in `reference-implementations/migration-runner/`:
  `extract.sh`, `lint-migration.sh`, `run-migration.sh`, each carrying a
  `# migration-runner-version:` marker for later publication under the same
  arbitration as the gate and the reviewer CLI.

Deliberately **not** included: the `answers:` frontmatter block (its only
consumer was `0000-baseline`, which never replays), and `role=apply-agent` (it
existed to absorb legacy prose, and there is no legacy prose in scope).

## Capabilities

### New Capabilities
- `executable-migration-format`: the role-tagged fence contract, the five linter
  rules, the ID threshold that scopes which migrations must satisfy it, the
  runner's execution order, and the non-interactive failure policy.

### Modified Capabilities
<!-- None. The five existing capabilities (change-gate-enforcement,
     conformance-harness-reporting, core-self-enforcement, plan-review-production,
     project-hook-binding) govern the gate, the harnesses and hook binding.
     None of them states a requirement about migration format, so none has a
     requirement that changes. The contract being revised is spec/08-migration-format.md,
     which is core's published spec text rather than an openspec/specs/ capability. -->

## Impact

- `spec/08-migration-format.md` — revised; `spec_version` 0.9.1 → 0.10.0.
  This is the published contract four host repos implement, so the revision is
  the highest-risk part of the change.
- `reference-implementations/migration-runner/` — new directory, three scripts,
  eight fixtures, a README.
- `tools/migration-runner.test.sh` — new.
- `reference-implementations/migration-runner/THRESHOLDS` — new; the declared
  per-host boundary the linter reads.
- `.github/workflows/openspec-gate.yml` — one new step.
- **No host repo is touched.** The four hosts declare their thresholds
  (claude `0035`, codex `0016`, opencode `0012`, pi `0011`) when the installer
  lands, which is a separate change.
- **No existing migration is modified.** All 73 across the four hosts stay as
  they are. Note that the threshold exempts them from the *executable form*
  only — §08's four-section quartet remains a universal MUST and is not being
  amended, so `codex-workflow`'s `0014` and `0015` stay non-conformant against
  it exactly as they are today. This change neither fixes nor excuses that; it
  declines to make it worse.
- Dependencies: bash, awk, git, and the POSIX text utilities already assumed
  everywhere else in this repo — `sed`, `grep`, `tr`, `basename`, `mktemp`.
  Reversing a list uses `tac` where present and `tail -r` on BSD. Deliberately
  no Node, so migrations stay runnable on a machine without it.
