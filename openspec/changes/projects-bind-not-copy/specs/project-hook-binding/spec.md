## ADDED Requirements

### Requirement: The workflow binds no host-specific hook surface

The workflow SHALL NOT bind a hook through a surface only one host reads.
`.claude/settings.json` is such a surface — Claude reads it, and Codex, opencode,
pi and omp read nothing from it — and this holds wherever the file sits, in
`$HOME` or in a repository. The enforcement floor SHALL be the machine-level git
hook, which fires for every host and for a person with an editor.

The host hook was deleted for three stated reasons: with no active change the
gate returns satisfied, so it never enforced spec-before-code; the condition it
did enforce is caught again at `git commit` and in CI; and it was every
host-specific line in the repository. **All three apply unchanged to the same
file inside a repository.** The surface was closed at `$HOME` and left open in
nine checkouts, and nothing recorded a reason for the distinction because there
is not one — the change simply did not reach that far.

The measurement that settles it: in `cparx` on 2026-08-07 there was no
`.git/hooks/pre-commit`, `core.hooksPath` was unset globally and locally, and the
only invoker of the gate shim was a `PreToolUse` entry. The gate fired at neither
of the two surfaces its own documentation claims. A Claude-only hook that returns
satisfied whenever no change is active was the whole of that repository's
enforcement.

A hook whose protection is genuinely pre-tool rather than pre-commit is not
excluded by this requirement — it is required to argue that, in the change that
keeps it, and to say what it protects that commit-time enforcement cannot.
**Making that argument successfully is necessary and not sufficient**: a
protection that reaches one host of five is not a floor, and the surface is not
closed while a single hook holds it open.

`database-sentinel` is the worked case and it is decided: **removed.** Its
destructive-SQL arms do make the pre-tool argument, and make it correctly —
`DROP TABLE` never enters git, so no commit-time or CI surface can see it, and
they are the only interception of an irreversible action in this workflow. It is
removed regardless, because it protects Claude sessions only. The protection is
not claimed to survive; it is reassigned to the host's own permission layer,
which is the operator's configuration and not core's to ship.

#### Scenario: A hook is bound through a single-host surface

- **WHEN** the workflow would register a hook in a configuration file only one
  host reads
- **THEN** it does not
- **AND** the enforcement is placed at the machine-level git hook instead

#### Scenario: A hook claims a pre-tool protection

- **WHEN** a hook is proposed for retention on a host-specific surface
- **THEN** the change states what it protects that commit-time enforcement
  cannot
- **AND** a hook with no such statement is removed with the surface

#### Scenario: The pre-tool argument succeeds and the hook is still removed

- **WHEN** a hook's protection genuinely cannot be provided at commit time, and
  the surface carrying it reaches only one of the provisioned hosts
- **THEN** the hook is removed with the surface
- **AND** the change names what is lost and where the protection is reassigned
- **AND** the change SHALL NOT describe the protection as preserved

### Requirement: No project binds any fleet hook once the surface is closed

After this change `SHIMMED-HOOKS` names no hook, and a project SHALL bind none.

The declaration held exactly two entries. `database-sentinel` is removed with
the host-specific surface, and `openspec-change-gate`'s project binding is
replaced by the machine-level git hook, so the set is empty rather than
shortened. That is a stronger and simpler rule than the one it replaces: the
reverse pass no longer asks whether a held hook appears in a declaration, it
asks whether any fleet hook is held at all.

This also removes the need for a sanctioned-extra mechanism. `OPT-OUTS` can
record a *missing* binding as intended and has no axis for an *extra* one, so a
retained hook would have failed the both-directions check permanently with no
way to say it was deliberate. An empty declaration means there is nothing to
sanction.

#### Scenario: A project holds no fleet hook

- **WHEN** both passes run against a repository carrying no fleet hook shim and
  no host configuration entry for one
- **THEN** it is reported conformant

#### Scenario: A project still holds a fleet hook

- **WHEN** a repository holds a shim or a host configuration entry for any fleet
  hook
- **THEN** the condition is reported, naming the repository and the hook
- **AND** the check exits non-zero
- **AND** no opt-out sanctions it

### Requirement: A project binds no hook the declaration does not name

A project SHALL NOT bind, in its host configuration or its project hook
directory, a fleet-shared hook that `SHIMMED-HOOKS` does not name. Retiring a
hook from the declaration SHALL be accompanied by removing the binding from every
repository that holds one, and the two SHALL NOT be separated across releases.

**The declaration detects a missing member and is blind to an extra one, and that
asymmetry is the whole of this requirement.** `ARTIFACTS`, `FLEET` and
`SHIMMED-HOOKS` exist because "an expected set discovered from the artifacts
cannot detect a missing artifact" — every one of them is checked by iterating the
declaration and asking whether the machine satisfies it. Nothing walks the other
direction and asks what the machine holds that the declaration does not.

The consequence is not hypothetical. `normalize-claude-md` is bound by six fleet
repositories — `agenticapps-dashboard`, `agenticapps-roadmap`, `callbot`,
`cparx`, `fbc-platform` and `fx-signal-agent`, measured 2026-08-07.
`agents-task-viewer` does **not** bind it, which is why it is the clean
reference — and the change retiring it removes it from `ARTIFACTS` and
`SHIMMED-HOOKS` in core while leaving all six bindings in place. Because
`install-project-hooks.sh` carries forward manifest rows outside the declared set
by design, the implementation stays on disk and the hook keeps running: a retired
hook rewriting `CLAUDE.md` on every edit in seven repositories, published by
nothing, attested by nothing, and reported by nothing. The conformance run that
inspected those same repositories the day before said "every declared hook is
bound with the authority's bytes", which was true and complete and did not
mention it.

A retirement that leaves the binding is not a retirement. It converts a shared
hook into an unmanaged one, which is strictly worse than the hook it replaced.

#### Scenario: A project binds a hook the declaration does not name

- **WHEN** a project holds a shim, or a host configuration entry, for a
  fleet-shared hook absent from `SHIMMED-HOOKS`
- **THEN** the condition is reported, naming the repository and the hook
- **AND** the check exits non-zero

#### Scenario: A hook is retired from the declaration

- **WHEN** a hook name is removed from `SHIMMED-HOOKS`
- **THEN** no repository retains a shim or a configuration entry for it
- **AND** the retirement and the removals are not separated across releases

#### Scenario: A project binds a hook that is declared

- **WHEN** a project holds a shim for a hook `SHIMMED-HOOKS` names
- **THEN** it is checked for the authority's bytes as it is today
- **AND** it is not reported as undeclared

### Requirement: The conformance check walks both directions

The fleet check SHALL make two passes over each declared repository: one that
iterates the declaration and asks whether the repository satisfies it, and one
that iterates what the repository holds and asks whether the declaration names
it. A pass that runs only the first SHALL NOT be described as reporting a
repository's conformance.

One pass answers "is anything missing". The other answers "is anything extra".
They are different questions, they fail in different directions, and a check that
answers only the first will report a clean fleet while a retired hook executes in
seven of its members.

#### Scenario: A repository holds only declared hooks

- **WHEN** both passes run against a repository whose hooks are exactly the
  declared set
- **THEN** it is reported conformant

#### Scenario: A repository holds a declared hook and an undeclared one

- **WHEN** both passes run against such a repository
- **THEN** the declared hook is reported bound and the undeclared one is reported
  as undeclared
- **AND** one clean pass does not suppress the other's finding
