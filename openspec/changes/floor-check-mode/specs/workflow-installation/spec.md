## ADDED Requirements

### Requirement: The check mode reports which enforcement surfaces are active

`--check` SHALL report whether `core.hooksPath` is set, whether it resolves to
the published directory, and whether the published `pre-commit` is current by
content against the checkout.

It SHALL report the **effective** binding for the repository it runs in, not the
global one. A local `core.hooksPath` is preferred by git, so reporting the
global binding as active is simply wrong wherever one is set — and one is set in
six repositories today. A `--check` that says the floor is bound while the
repository it ran in is outside the floor is worse than no report, because it is
believed.

Removing a surface makes it more important, not less, that an operator can see
which surfaces remain. "The workflow got weaker" and "the workflow moved its
floor" are indistinguishable from the outside unless something says which.

#### Scenario: The machine is fully bound

- **WHEN** `--check` runs on a bound machine
- **THEN** it reports the global binding as present and current
- **AND** it names the surfaces that enforce the gate

#### Scenario: The machine is unbound

- **WHEN** `--check` runs where `core.hooksPath` is unset
- **THEN** it reports the floor as not bound
- **AND** it states what to run to bind it

#### Scenario: The repository is outside the floor

- **WHEN** `--check` runs in a repository with a local `core.hooksPath`
- **THEN** it reports the effective binding rather than the global one
- **AND** it states that the global floor does not govern this repository

#### Scenario: The binding is dangling

- **WHEN** `core.hooksPath` is set to a directory that does not exist
- **THEN** `--check` reports the binding as dangling
- **AND** it states that commits in every repository the binding governs are
  proceeding **ungated and silently**, rather than failing

> **An earlier revision of this scenario had it backwards**, asserting that
> `git commit` fails machine-wide until the directory is restored. Tested on
> git 2.50.1 with `core.hooksPath` pointing at an absent directory: the commit
> **succeeds, exit 0**, and nothing is reported. A dangling binding does not
> break the machine loudly; it removes the floor quietly, which is the failure
> mode `core-self-enforcement` names as the one this workflow must not have.
> The correction matters because it changes what `--check` is *for* here: it is
> not a convenience that explains a visible breakage, it is the only surface
> that would ever mention this at all.

#### Scenario: The published hook is not executable

- **WHEN** the published `pre-commit` has correct content but lacks its execute
  bit
- **THEN** `--check` reports the floor as **not active**
- **AND** SHALL NOT report it as current on the strength of content alone,
  because git does not run a non-executable hook

#### Scenario: The published hook has been hand-edited

- **WHEN** the published `pre-commit` differs by content from the checkout at
  the same version
- **THEN** `--check` reports it as modified rather than current
