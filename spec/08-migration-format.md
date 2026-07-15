---
id: 08-migration-format
section_type: declarative-contract
spec_version: 0.9.1
---

# 08 — Migration Format

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. Prose, formatting, file paths, and
runtime semantics are at the host's discretion. The keywords MUST,
MUST NOT, SHOULD, SHOULD NOT, and MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Concept

A migration is a versioned, idempotent, atomic, dry-runnable patch
that brings an installed AgenticApps workflow scaffolding from one
version to the next. The `migrations/` directory is the single source
of truth for what each version looks like on disk. The existing-project
update flow consumes it directly, applying only those migrations not yet
applied — those whose `to_version` is newer than the project's installed
version (equivalently, the chain of migrations whose `from_version` is at or
after the installed version). This matches the per-field rules below: a
migration is skipped when the installed version is below its `from_version`
or already at or beyond its `to_version`.

The fresh-project setup flow MUST arrive at the same end state that a
full `0000-baseline`→latest replay produces — but it need not get there
by replaying. Two strategies are conformant: **replay** (setup applies
every migration from `0000-baseline` forward) and **snapshot** (setup
installs a prebuilt artifact assembled from those same sources, with a
drift guard in CI proving artifact and sources agree). The Conformance
section below is the normative statement.

What this spec forbids is a *second source of truth*: a setup path that
writes a shape derived from somewhere other than the migration sources,
so that "what does v1.3.0 look like on disk" is maintained twice and can
silently diverge. A guarded snapshot is not a second source of truth —
it is a build artifact of the first one, and the guard is what makes
that claim checkable rather than merely asserted.

ADR-0013 established the migration framework and assumed both flows
would replay. ADR-0018 supersedes that assumption: a chain containing
prose, agent, or interactive steps cannot be shell-replayed, so the end
state — not the mechanism — is what the spec makes normative.

## Requirements

### File location and naming

- **MUST** store migrations in a `migrations/` directory at the
  scaffolder repo root.
- **MUST** name each migration file `NNNN-{kebab-slug}.md` where
  `NNNN` is a four-digit zero-padded sequential ID and `kebab-slug`
  is a short kebab-case description.
- **MUST** use sequential IDs starting at `0000`. Sequential IDs
  decouple "I have a new feature" from "what version number does
  that imply" — multiple migrations MAY ship inside one semver
  release.
- **MUST** treat `0000-baseline.md` as special: it codifies the
  starting state of a fresh project at the workflow scaffolder's
  initial supported version. Every other migration is incremental.

### Frontmatter

Every migration MUST include YAML frontmatter with at minimum:

| Field | Required | Meaning |
|---|---|---|
| `id` | MUST | Sequential migration ID (matches filename prefix) |
| `slug` | MUST | Kebab-case slug (matches filename middle) |
| `title` | MUST | Human-readable one-line title |
| `from_version` | MUST | Installed version that this migration upgrades from. The update flow skips this migration if the project's installed version is less than `from_version`. |
| `to_version` | MUST | Version after this migration successfully applies. The update flow writes this to the project's installed-version field on success. |
| `applies_to` | MUST | List of files / directories this migration touches (for impact awareness in plan output) |
| `requires` | MAY | List of external dependencies (skills, tools, CLIs) that must be installed before this migration applies. Each entry SHOULD include `verify` (test command) and `install` (install command). |
| `optional_for` | MAY | List of conditional groups. Each entry has a `tag`, a `detect` shell command, and a `note`. Steps tagged with the same `tag` are skipped if `detect` returns non-zero. |

### Step structure

Every migration body MUST contain at least one step. Every step MUST
have four sections, in this order:

| Section | Purpose |
|---|---|
| **Idempotency check** | A shell command that returns 0 if the step has already been applied. The update flow skips applied steps without prompting. |
| **Pre-condition** | A shell command that must return 0 before the step can apply (e.g. "the file exists and has the section we're patching"). If pre-condition fails, the step errors with a specific message rather than silently producing wrong output. |
| **Apply** | The exact patch — markdown content to insert, JSON entry to add, file to create. |
| **Rollback** | How to revert this step. Either a unique anchor comment to delete, an explicit `git revert` instruction, or "manual — see VERIFICATION.md for resolution". |

### Idempotency contract

- **MUST** make every step safely re-runnable. Running the same
  migration twice in a row MUST produce: 1 actual apply, 1 "skipped
  (already applied)" log line.
- **MUST** use idempotency checks of the appropriate shape:
  - For markdown insertions: a unique anchor string from the new
    content (e.g. `grep -q "^## Backend language routing" <host-workflow-config>`).
  - For JSON modifications: a unique key path (e.g.
    `jq -e '.hooks.pre_phase.design_critique' <host-config-json> >/dev/null`).
  - For file creation: file existence at the expected path with
    expected content (e.g. `test -f templates/<artifact>.md`).
- A migration without working idempotency checks is non-conformant.
  The update flow MUST refuse to apply it twice; the second run
  MUST error.

### Atomicity contract

- **MUST** prompt the user with three options when step N fails
  halfway:
  1. **Retry** — re-run step N (idempotent steps are safe to re-run).
  2. **Skip with warning** — log the skip, continue with step N+1.
     The migration is recorded as `partial` in the version-bump
     record.
  3. **Rollback** — apply rollback patches for steps 1..N-1 (using
     each step's `Rollback` clause), restore the project to its
     pre-migration state.
- **MUST NOT** auto-rollback without explicit user consent.
  Partial-state recovery may be more useful than full revert.

### Dry-run mode

- **MUST** support a dry-run mode that runs every step's
  idempotency check and prints the diff each step would apply,
  without writing or committing.
- **SHOULD** make dry-run the default-on-confirm interactive mode:
  dry-run the whole chain, show diffs, then ask "apply now?".

### Skip cases

Migrations MUST handle (without crashing) at minimum:

- The project has no workflow scaffolding installed yet → migration
  is skipped with a note directing the user to the setup flow.
- The project's `installed_version` is already ≥ this migration's
  `to_version` → migration is skipped silently.

### Test fixtures

- **SHOULD** ship a fixture pair (before-state, expected-after-state)
  for every migration that operates on existing files.
- **SHOULD** maintain a runner script (`run-tests.sh` or equivalent)
  that asserts each migration produces the expected end-state when
  applied to its before-state fixture.
- The `0000-baseline.md` migration MAY omit a non-interactive test
  if its application requires interactive input.

## Example migration outline

The following is an illustrative skeleton. Host implementations may
adapt path conventions; the shape is normative.

```markdown
---
id: 0001
slug: example-feature-add
title: Add example feature wiring to AgenticApps workflow
from_version: 1.2.0
to_version: 1.3.0
applies_to:
  - <host-workflow-config>
  - <host-config-json>
  - <host-instruction-file>
  - docs/decisions/
requires:
  - skill: example-skill
    install: "<host-install-command>"
    verify: "<host-verify-command>"
optional_for:
  - tag: example-tag
    detect: "<detect-command>"
    note: "If <condition> not detected, tagged steps install but the runtime won't trigger them."
---

# Migration 0001 — Add example feature wiring

## Pre-flight
{commands the update flow runs before any patch}

## Steps

### Step 1: Add anchor section to host-workflow-config
**Idempotency check:** `grep -q "^## Example feature" <host-workflow-config>`
**Pre-condition:** the file exists and has a `## Conventions` section
**Apply:**

\`\`\`markdown
## Example feature

{content}
\`\`\`

**Rollback:** delete the section bounded by the unique anchor `^## Example feature`.

### Step 2: ...
{...}

## Post-checks
- All `grep` verifications pass
- `<host-config-json>` validates structurally
- ADR opportunity: prompt user whether to draft an ADR

## Skip cases
- Project has no workflow scaffolding → skip with note "no workflow detected; run setup first"
- Project's `from_version` already ≥ this migration's `to_version` → skipped silently
```

## Conformance

A host implementation:

- **MUST** store migrations in a single directory that the update flow
  consumes. The setup flow **MUST** produce an end state equivalent to a
  full `0000`→latest replay, by one of:
  - **replay** — setup applies every migration from `0000-baseline` forward; or
  - **snapshot** — setup installs a prebuilt artifact assembled from the same
    sources, PROVIDED a drift guard runs in CI and fails the build when the
    snapshot and the sources disagree.

  The snapshot strategy exists because a migration chain containing prose,
  agent, or interactive steps cannot be shell-replayed (ADR-0013 assumed it
  could; ADR-0018 supersedes that assumption). What is normative is the
  equivalence of the end state and a mechanical guard proving it — not the
  mechanism. A host choosing snapshot **MUST** name its guard in its
  instruction file.
- **MUST** support the frontmatter fields, step structure,
  idempotency contract, atomicity contract, and dry-run mode listed
  above.
- **SHOULD** ship test fixtures for every non-baseline migration.
- **MAY** define host-specific frontmatter fields beyond the
  required minimum (e.g. host-runtime-extension version pins).
