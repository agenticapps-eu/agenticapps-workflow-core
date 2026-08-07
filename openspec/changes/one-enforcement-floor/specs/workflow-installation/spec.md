## MODIFIED Requirements

### Requirement: One command installs the workflow, and it names no host

The workflow SHALL be installable by a single command in core that requires no
host argument. Running it with no arguments SHALL publish the payload, publish
the gate's `pre-commit` to the machine-level hooks directory, and bind that
directory through `core.hooksPath`. A host is an optional addition to that
install, never a precondition for it.

An operator who has never heard of the five hosts SHALL still get a working
install. The git and CI floor **is** the workflow; a host adds skills, and
nothing else.

#### Scenario: A bare run installs without a host

- **WHEN** the operator runs the installer with no arguments
- **THEN** the payload and the gate's `pre-commit` are published
- **AND** the machine-level hooks directory is bound through `core.hooksPath`
- **AND** the run succeeds without any host being detected or named

### Requirement: The installer is short enough to be read before it is trusted

The installer SHALL NOT exceed 217 executable lines, counting neither comments
nor blank lines.

> **This change spends, it does not save.** The host wiring was already removed
> by `core-installer-one-entry-point`, which is where the budget came back from
> 250 to 217 and where the implementation landed at 210. This change adds: the
> published hook, the global binding, the foreign-binding refusal, and four new
> `--check` reports. That is growth, and 7 lines of headroom is plainly not
> enough for it.
>
> The budget is therefore **not pre-raised here**, and saying in advance that it
> will not fit is the point rather than an admission. If the mandatory behaviour
> does not fit, the escape clause applies as written — itemise the overage, name
> the behaviour responsible, and raise the number in this document. What is not
> permitted is arriving at 240 and discovering the ceiling had already been
> moved to accommodate it.

Mandatory: every mode named in this specification, publishing, skill binding,
the global floor binding, the foreign-binding refusal, the legacy manifest, and
every acceptance and preservation rule. None may be omitted to fit.

Deferrable, in order: reporting distinctions within check mode that collapse
into a coarser but still correct state; then the archived-binding sweep's
per-name reporting, which may collapse to a count.

Anything deferred SHALL be reported to the operator, naming what was deferred
and why.

#### Scenario: The budget is measured

- **WHEN** the installer's executable lines are counted
- **THEN** the count is at most 217, or the budget has been raised in this
  document with the overage itemised

#### Scenario: The growth is accounted for

- **WHEN** this change is complete
- **THEN** the installer's line count is reported against its count before the
  change
- **AND** the difference is attributed to named behaviour rather than absorbed

## ADDED Requirements

### Requirement: The enforcement floor is bound once per machine, not once per repository

The gate's `pre-commit` SHALL be published to a single machine-level hooks
directory and bound by setting `core.hooksPath` in the operator's global git
configuration. It SHALL NOT be copied into an individual repository's hooks
directory.

A per-repository copy is a fork that nothing reports has forked. Nine
repositories on the machine this was measured on carried the gate at four
different sizes, and no surface named the divergence.

#### Scenario: A machine is bound

- **WHEN** the installer runs
- **THEN** the gate's `pre-commit` is published to the machine-level hooks
  directory
- **AND** `core.hooksPath` in global git configuration resolves to that
  directory

#### Scenario: Every repository is covered without being visited

- **WHEN** a repository on a bound machine runs `git commit`
- **THEN** the published gate runs
- **AND** the repository required no installation step of its own

#### Scenario: A repository needs different hooks

- **WHEN** a repository sets its own `core.hooksPath` in local configuration
- **THEN** the local setting governs that repository
- **AND** the installer neither prevents nor repairs this

### Requirement: A foreign global hooks binding is reported, never overwritten

If `core.hooksPath` is already set globally to a directory this workflow did not
publish, the installer SHALL report it and SHALL NOT change it. The condition
SHALL be reported as skipped, so the run exits non-zero.

An operator who has bound a hooks directory has done so deliberately, and a tool
that silently rebinds it takes a decision that was already made. This is the
posture the git-hook installer already takes toward a foreign hook, applied one
level up.

#### Scenario: A foreign binding is present

- **WHEN** `core.hooksPath` is set globally to an unrecognised directory
- **THEN** the installer reports the existing value and the value it would have
  set
- **AND** the global configuration is unchanged
- **AND** the step is reported as skipped

#### Scenario: The binding is already ours

- **WHEN** `core.hooksPath` already resolves to the published directory
- **THEN** the installer reports it as satisfied and changes nothing

### Requirement: The published hook composes rather than monopolises

The published `pre-commit` SHALL dispatch to the gate and SHALL NOT assume it is
the only work a machine wants done before a commit.

`core.hooksPath` replaces the hooks directory rather than adding to it, so a
repository that later adopts another hook manager finds its hooks silently not
running. The set displaced was empty when measured, and a design that is correct
only while that stays true is a design with an expiry date nobody wrote down.

#### Scenario: The published hook runs the gate

- **WHEN** the published `pre-commit` runs
- **THEN** it invokes the gate and propagates its exit status

#### Scenario: A repository has hooks the global directory does not carry

- **WHEN** a repository's own hooks are displaced by the global binding
- **THEN** the condition is reportable by `--check` rather than silent

### Requirement: The check mode reports which enforcement surfaces are active

`--check` SHALL report whether `core.hooksPath` is set, whether it resolves to
the published directory, and whether the published `pre-commit` is current by
content against the checkout.

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

#### Scenario: The published hook has been hand-edited

- **WHEN** the published `pre-commit` differs by content from the checkout at
  the same version
- **THEN** `--check` reports it as modified rather than current
