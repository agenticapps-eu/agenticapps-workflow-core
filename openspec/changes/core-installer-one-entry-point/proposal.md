## Why

Installing this workflow currently means running whichever of four host repos
you happen to have checked out, each with its own installer, and all four are
now archived. Skill bindings on this machine still point into those checkouts —
including `setup-agenticapps-workflow`, `update-agenticapps-workflow`, a whole
`codex-*` set, and `update-opencode-agenticapps-workflow` — so deleting the
checkouts breaks four agents. There is no single command that puts the workflow
on a machine, and no command that tells you what state a machine is in.

Linear issue: AGE-503.

## What Changes

- **NEW** `install.sh` at the root of core — the one entry point. Four modes:
  - bare — publish the payload and install core's own git pre-commit hook. No
    host required.
  - `--host <name>` (repeatable) — additionally wire the named host.
  - `--host auto` — detect installed hosts and wire what is found.
  - `--check` — the doctor table. Reports, changes nothing.
- `install.sh` is a **front end**. It publishes through the two existing
  installers and installs core's hook through `install-core-git-hooks.sh` rather
  than writing files itself, so the contracts those carry — version arbitration,
  downgrade refusal, locking, atomic replacement, attestation, `git rev-parse`
  hook resolution, worktree and `core.hooksPath` tolerance, foreign-hook refusal
  — are kept rather than re-earned.
- **Publishing is two calls, not four.** The three workflow executables (gate,
  `run-plan-review`, `reviewer-cli`) go through `install-shared-artifact.sh`,
  which arbitrates on a version marker. The project-hook set goes through
  `install-project-hooks.sh`, which publishes the whole declared set and writes
  the attesting `manifest.tsv`. The arbitrating helper does not attest, so
  routing a project hook through it would publish an artifact that
  `project-hook-binding` then cannot verify.
- Skills are **symlinked** from `skills/` into each host's skill directory.
  Never copied.
- **NEW** a named manifest of the legacy skill names this workflow has installed
  under, so they can be replaced or removed. Iterating today's `skills/` cannot
  find them.
- **NEW** `hosts/` — the one place in this repo where a host name may appear:
  the opencode plugin and the codex adapter. `skills/` stays host-neutral.
- The opencode plugin is **derived from current gate behaviour, not lifted**.
  The installed copy states that a change must pass validation *and* carry two
  reviews, which the gate stopped enforcing at 2.0.0.
- Two hosts (`pi`, `omp`) get skills and no hook wiring. Both read
  `~/.agents/skills`, so one host-neutral directory covers both — this change
  resolves what an earlier session recorded as unknown for them. Unwired is a
  conformant state: those hosts run on the git and CI floor.
- **BREAKING** for anyone whose skills resolve through a host-repo installer.
  Those bindings are replaced by symlinks into `core/skills/`.

## What this change deliberately does not do

`--project` — binding a consuming project — was in the first two drafts and is
**deferred to its own change**. Two rounds of review established that it is not
one flag on this installer:

- `install-core-git-hooks.sh` cannot bind a project. The hook it writes resolves
  `<repo>/reference-implementations/…`, which is ADR-0028's self-hosting
  inversion working as designed and which a consuming project does not have. The
  project shim is a different artifact —
  `reference-implementations/project-hooks/openspec-change-gate.shim.sh` — with
  a different installer.
- **No canonical instruction-file provisioner exists in core.**
  `host-neutral-instruction-files` fixes the markers, the section version, the
  frontmatter placement and the consent rule; `tools/agents-md-conformance.sh`
  *checks* all of that and writes none of it. There is no template, no version
  source, and no frontmatter-preserving writer to delegate to.

So `--project` is a project-shim installer plus a provisioner core does not yet
have. Attaching it here would mean building both inside a change whose
specification caps the installer at 200 executable lines and forbids meeting
that cap by dropping a promised mode. It gets its own proposal and its own
review.

## Capabilities

### New Capabilities

- `workflow-installation`: what the one installer does, what it may hard-fail
  on, what it must delegate rather than reimplement, how each host is bound,
  what happens to a legacy or foreign binding, and what `--check` must be able
  to tell an operator.

### Modified Capabilities

None. Two existing capabilities were checked line by line, and this change
**conforms** to both rather than amending either:

- `installer-prerequisite-consent` requires that a skipped requested step exits
  non-zero, and that changes to software the workflow does not own are made
  only with acceptance. The first draft exited zero on a skipped wiring and
  edited host configuration unasked. The installer now conforms; the capability
  is unchanged.
- `project-hook-binding` defines the attestation the project-hook set carries
  and defines currency against an authority checkout. This change publishes
  through the installer that writes that attestation, and `--check` reports the
  currency it defines rather than comparing version markers.

`host-neutral-instruction-files` is untouched by this change, because the mode
that would have written an instruction file is deferred.

## Impact

- New: `install.sh`, `hosts/`, the legacy-binding manifest, and a test suite.
- **Not** superseded: `install-shared-artifact.sh`, `install-project-hooks.sh`
  and `install-core-git-hooks.sh` become the internals this change gives one
  door to. An earlier draft proposed replacing them, which would have discarded
  contracts that took real incidents to learn.
- The bindings into archived host repos become replaceable, which is what lets
  those checkouts be deleted.
- No change to `~/.agenticapps/bin/` contents, paths or permissions, so the six
  fleet projects that shim to it keep working untouched.
- One observable side effect of publishing through the attesting installer: it
  rewrites `manifest.tsv` in full from the declared set, so the stale
  `normalize-claude-md.sh` row left by that artifact's retirement disappears.
  The retired file itself stays in `~/.agenticapps/bin/`; this change does not
  remove software it did not install.
- Deferred to a follow-up change: `--project`, and with it any core-side
  instruction-file provisioner.
- **A capability window opens with that deferral.** This change removes the
  `setup-agenticapps-workflow` binding, whose replacement is `--project`. Until
  the follow-up lands, bootstrapping a fresh project means invoking the archived
  checkout's skill directly or doing it by hand. The window is accepted rather
  than avoided: the alternative is leaving a binding into an archived checkout,
  which is the condition this change exists to end. It makes the `--project`
  follow-up a precondition for deleting those checkouts in Phase 5b — alongside
  the codex adapter and the opencode plugin, which are also sourced from them.
