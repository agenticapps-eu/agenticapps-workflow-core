# project-hooks — fleet-shared workflow hooks

The canonical implementations of the workflow hooks that more than one project
binds, plus the shim template every project binds them *through*.

Seven repos used to carry a full copy of each of these files. Four of the eight
copied hooks had drifted into two or three distinct versions; the one hook that
was never copied — `openspec-change-gate.sh`, a ~13-line shim — had zero drift
across all seven. This directory is that observation applied to the rest.

**Authority.** For a hook in the `published-resolution` profile, the file in
*this* directory is authoritative and the project copy is a shim that `exec`s
it. The shim template here — not any project's copy of it — is the authority
for shim conformance.

---

## The shim contract

A shim is a project-local file, registered in that project's
`.claude/settings.json`, whose entire job is to find the implementation and hand
over to it.

### Resolution order (published-resolution profile)

**Two candidates, in order:**

1. `$<HOOK>_OVERRIDE` — an explicit path, when set.
2. `~/.agenticapps/bin/<hook>.sh` — the shared install.

There is **no third `<repo>/bin/` candidate.** A repo-local copy is the drift
this directory exists to remove; keeping it as a fallback keeps the drift and
hides it, because the fallback only runs on the machines nobody is looking at.

### Unresolvable → fail open, and report

If neither candidate resolves to an executable file, the shim **allows the tool
call** and **reports on stderr**. It does not block.

The reasoning is scope, and it is worth stating because an earlier revision of
this change had it the other way. These hooks are registered on broad matchers —
`database-sentinel` on `Bash|Edit|Write|MultiEdit`. A shim that blocks when it
cannot resolve an implementation therefore blocks *every Bash command and every
file edit in the repository*, not `.env` and dangerous SQL. Narrowing that would
require the shim to inspect the tool payload, which is exactly the behaviour the
contract forbids and exactly the duplicated logic this directory exists to
remove.

The guarantee moves to where it can be enforced without duplicating anything:
the installer verifies the implementations are present and executable, and a
per-machine provisioning check reports the machine's state. Absence becomes a
provisioning failure — caught once, visibly — rather than a per-tool-call
outage.

### Behaviour-free — a closed list

A shim does exactly these five things and nothing else:

1. resolves the implementation,
2. host self-identification (the change-gate shim only; being retired),
3. `exec`s the implementation, passing stdin through **untouched**,
4. reports when it cannot resolve, or when an override is set but unusable,
5. reads and writes **one** repetition marker, if its report is rate-limited.

In particular it **inspects no tool payload**. A shim that reads stdin to look
at the payload has consumed the implementation's input.

### Profiles

Not every binder of a shimmed hook resolves a *published* copy.

| | `published-resolution` | `self-hosting` |
|---|---|---|
| Who | the seven consuming projects | `agenticapps-workflow-core` itself |
| Resolves | override → `~/.agenticapps/bin/` | its own working-tree reference implementation |
| Resolution order applies | yes | **no** |
| Byte-identity across projects applies | yes | **no** |
| Contract version marker applies | yes | yes |
| Behaviour-free rule applies | yes | yes |
| Fail-open-and-report applies | yes | yes |

Core's `.claude/hooks/openspec-change-gate.sh` is `self-hosting` by design, not
by omission: per ADR-0028 core must score the bytes it *ships*, not whichever
host's installer last wrote `~/.agenticapps/bin/`. A shim there would test the
wrong file.

**A hook has exactly one `self-hosting` binder.** Two would be two authorities,
which the `project-hook-binding` capability's first requirement forbids.

### Version markers — two of them, deliberately distinct

| Marker | Lives in | Says |
|---|---|---|
| `# shim-contract: <semver>` | every **shim** | which contract revision the shim implements |
| `# <hook>-version: <semver>` | every **implementation** | which build of the implementation this is |

Both sit within the first 10 lines, matching the `# gate-version:` convention
`openspec-change-gate.sh` already uses. The implementation marker is what the
install manifest's rows reference; the shim marker is what a per-project
conformance scan compares against the template in this directory.

---

## Coverage boundary

Stated so the hooks can be relied on correctly. A control described as stronger
than it is invites exactly the wrong decisions.

### `database-sentinel`

**It is best-effort defence in depth, not a security boundary.**

- The `Bash` arm matches `DROP TABLE`, `TRUNCATE TABLE`, and `DELETE FROM`
  without a `WHERE`, by regex on the command string. Indirection defeats it:
  `psql -f script.sql` never presents the SQL to the regex, and neither does a
  heredoc fed to a client, an ORM call, or a migration runner.
- It does **not** stop `Bash` writing `.env`. The `.env` arm reads
  `tool_input.file_path`, which `Bash` does not supply; `echo SECRET > .env`
  passes.
- The implementation is a **user-writable file in a shared directory**, executed
  by seven projects. Anyone who can write `~/.agenticapps/bin/` can change what
  all seven enforce. That is the cost of consolidation, and the reason the
  maintained copy lives here in core rather than the published one being
  authoritative.
- On an unprovisioned machine it does not run at all. It reports and allows.

### `normalize-claude-md`

- `PostToolUse`, so it observes an edit that has already happened. It is a
  normalizer, not a gate, and blocks nothing.
- It rewrites `CLAUDE.md` in place. Its failure mode is a mangled instruction
  file, not a leaked secret.

### The override, in both hooks — it is a kill switch

`$<HOOK>_OVERRIDE` exists for testing and staged rollout. It is **not** a
production configuration mechanism, and it cuts two ways:

- **Pointing it at a non-existent path disables that hook on a healthy
  machine.** For the §18 change gate that is a one-variable bypass of the gate
  at the tool boundary.
- **Pointing it at a file that *exists* gets that file `exec`d** on every
  `Bash`/`Edit`/`Write`/`MultiEdit`, with the operator's privileges. Combined
  with the vectors below, that is repository-supplied code running at the tool
  boundary. The missing-file case is the *safe* one.

A shim cannot defend against this, and pretending otherwise was tried and
withdrawn (design Decision 13). The host injects `.claude/settings.json` `env`
values into the hook process's environment, where they are indistinguishable
from an operator's own `export`. A behaviour-free shim reads `$VAR` and has no
provenance to inspect. The answer is a **conformance scan that reports the
repository by name**, not a runtime suppression — the value takes effect, which
is precisely why it must surface in review.

The scan must cover more than `settings.json`: an `.envrc` (direnv), a bootstrap
or setup script, a task-runner definition, or README instructions can each
export the override into the operator's shell. A green result therefore reads
**"no known vector found"**, never "no override is set".

---

## Reconciliation record

Task 1.3a requires that each behavioural difference between project copies be
resolved *with a reason*. The superset is the default, not an unconditional
rule: a clause that traces to no live gate or stated policy is escalated rather
than unioned, and a deliberate project-specific difference is preserved as a
documented opt-out.

Measured on this machine, 2026-08-02, across all seven repos.

### `database-sentinel` — three distinct variants

| Variant | Repos |
|---|---|
| `a5030f…` (68 lines) | dashboard, roadmap, agents-task-viewer, fbc-platform, fx-signal-agent |
| `211cac…` (71 lines) | callbot |
| `dabf20…` (72 lines) | cparx |

**Difference 1 — `.env` matching: enumerated list vs. wildcard.**
Five copies enumerate `.env{,.local,.production,.staging,.development}` and the
`*/`-prefixed forms. `callbot` uses `.env|.env.*|*/.env|*/.env.*` plus an
explicit `*.env.example|*.env.template` allowance.
**Canonical: the wildcard.** It is a strict superset — every enumerated path
matches it — and the enumeration misses any novel suffix, which is the exact
case a secrets guard exists for. The `.example`/`.template` allowance is
required *by* the wildcard (those paths match `.env.*`) and restores parity with
the enumerated variants, which never blocked them either. **Nothing is lost.**

**Difference 2 — `MultiEdit` in the tool test.**
Only `callbot` tests for it. **Canonical: include it.**
Coverage of a tool the host does not provide is not protection gained — see
task 4.8, and note that `MultiEdit` appears to be absent from the current host's
tool set. This is forward-compatibility. It must not be reported as closing a
live gap unless 4.8 finds otherwise. It is also inert without the matching
`settings.json` matcher change, which is why the rollout edits six matchers.

**Difference 3 — the `migrations/` arm. Dropped, not carried, and it is in all
seven copies rather than one.**
Every variant blocks `migrations/*` and `*/migrations/*` unless
`.planning/current-phase/migrations-approved` exists, and prints a remedy naming
`/gsd-discuss-phase` — a command removed 2026-07-28. Measured: **six of the
seven repos have no such sentinel**, so every migration edit in those six is
blocked today, with an unactionable remedy. Only `cparx` has the file.
This is the same dead-sentinel mechanism as `design-shotgun-gate`, inside the
hook the first draft of this change classified as healthy.
**This corrects the change's own artifacts, which scoped the live defect to
`callbot` alone.** The remedy is unchanged — the clause goes — but the reported
impact is six repos, not one.

**Difference 4 — `cd "${CLAUDE_PROJECT_DIR:-$PWD}"`.**
`cparx` only. It exists to resolve the repo-relative sentinel path in the
`migrations/` arm against the project root rather than the hook's CWD.
**Canonical: dropped.** With difference 3 removed, no surviving check reads a
repo-relative path — every remaining test reads `tool_name`, `command`, or
`file_path` from the payload. The `cd` becomes inert, and an inert `cd` in a
hook that must stay behaviour-free is worth removing rather than inheriting.

### `normalize-claude-md` — three distinct variants

| Variant | Repos |
|---|---|
| `5a06d7…` (288 lines) | roadmap, callbot, cparx, fbc-platform, fx-signal-agent |
| `0dc500…` (287 lines) | dashboard |
| `14af2d…` (314 lines) | agents-task-viewer |

**Difference 5 — the `workflow` slug branch (resolves design open question 1).**
`dashboard`'s 2026-07-26 fix always collapses the block. The other five fall
back to injecting a `> Workflow defaults. Migration 0009 not yet applied.` stub
whenever `.claude/claude-md/workflow.md` is absent — which, since workflow
v3.0.0 moved the canonical document to `docs/WORKFLOW.md` and the vendored copy
was removed, is both false and stale in every repo.
**Canonical: `dashboard`'s.**

`agents-task-viewer`'s 314-line variant is **this file's predecessor plus a
26-line opt-out banner comment** — diffed, and it contains no functional
addition. Design open question 1 resolves to *nothing to fold in*.

**Difference 6 — the opt-out itself is preserved, as an opt-out.**
`agents-task-viewer` deliberately does not register this hook (in-file note
dated 2026-07-21): the hook collapsed CLAUDE.md's inlined stack block into a
pointer link, and that block carries pinned-version constraints the project's
correctness depends on. It had been manually reverted ~3 times.
**Per task 4.3 that repo receives no file at all** — the opt-out forbids wiring
the hook, it does not require an unwired file to exist, and a shim nothing
invokes is a copy that can drift unnoticed.

> **Carry the rationale forward.** The 26-line banner is currently the *only*
> record of why the opt-out exists. Deleting the file without relocating that
> note destroys the reason and invites the next migration to re-add the
> registration — which the note explicitly warns against. See task 4.3.

---

## Audit: other checks with dead preconditions (task 1.8)

Task 1.4 removed one check whose precondition no surviving command can satisfy.
Task 1.8 asks whether either canonical implementation contains another. Both
files were read end to end.

**`database-sentinel` — none remaining.** After difference 3, every test reads
the tool payload. No sentinel file, no marker, no external command.

**`normalize-claude-md` — one stale remedy, no dead gate.**

- Line ~160, the `profile` slug branch, emits
  `> Run \`/gsd-profile-user\` to generate.` into `CLAUDE.md`.
  `/gsd-*` commands were removed on 2026-07-28. This is the same *class* as
  task 1.4 — a remedy naming a dead command — but it is **not** a gate: it
  writes a stub, it blocks nothing, and no precondition is being tested.
  **Recorded, not changed.** Editing it would alter this hook's output in seven
  repos, which task 3.4's "behaves identically apart from the dropped
  `migrations/` clause" does not admit. It belongs to the §02 GSD-vocabulary
  cleanup that `docs/PLAN-lightweight-fleet.md` step 5 owns.
- Lines ~107–112 map source labels to paths under `.planning/`. This hook
  **reads** that directory and rewrites `CLAUDE.md` to *link into* it. The
  fleet's frozen-archive policy forbids **writing** there, which this hook does
  not do — but pointing the live instruction file at frozen history is a real
  smell, and it is the same step 5 root cause. **Recorded, not changed.**

Neither finding blocks this change. Both are logged here so the next revision of
`docs/PLAN-lightweight-fleet.md` step 5 inherits them rather than rediscovering
them.

---

## Files

| File | What |
|---|---|
| `database-sentinel.sh` | canonical implementation, published to `~/.agenticapps/bin/` |
| `normalize-claude-md.sh` | canonical implementation, published to `~/.agenticapps/bin/` |
| `shim-template.sh` | the authority for shim conformance |
