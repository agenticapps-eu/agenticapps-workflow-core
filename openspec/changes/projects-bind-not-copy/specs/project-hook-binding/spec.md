## ADDED Requirements

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

The consequence is not hypothetical. `normalize-claude-md` is bound by seven fleet
repositories, and the change retiring it removes it from `ARTIFACTS` and
`SHIMMED-HOOKS` in core while leaving all seven bindings in place. Because
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
