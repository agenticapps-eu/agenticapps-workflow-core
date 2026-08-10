## ADDED Requirements

### Requirement: The one-entry-point installer declares openspec and superpowers

`install.sh` SHALL declare `openspec` and `superpowers` as prerequisites, and
SHALL report either as absent before completing.

It currently declares only `git` and `bash` — the two tools allowed to hard-fail
it. That is the *tier 1* rule, which governs what may abort the install, and it
was mistaken for the *declaration* set, which governs what is reported. The two
answer different questions, and conflating them produced an installer that
reports success on a machine where the gate cannot run.

`openspec` is not incidental. The gate's one blocking condition is
`openspec validate --all`, and without the CLI the gate cannot answer it. An
install that binds every host and publishes every artifact on a machine with no
`openspec` has produced a workflow that reports rather than enforces, and said
nothing about it.

#### Scenario: openspec is absent

- **WHEN** `install.sh` runs and the `openspec` CLI is not present
- **THEN** it SHALL name `openspec` and state that the change gate cannot verify
  a change without it
- **AND** the install SHALL NOT be reported as fully successful

#### Scenario: superpowers is absent

- **WHEN** `install.sh` runs and `superpowers` is not installed for any detected
  host
- **THEN** it SHALL name `superpowers` and state which parts of the loop depend
  on it

#### Scenario: Both are present

- **WHEN** both prerequisites are present
- **THEN** the installer SHALL proceed without prompting about either

### Requirement: A prerequisite owned by a host is reported, never installed

A prerequisite that a host installs in its own idiom SHALL be reported with the
command that host uses, and SHALL NOT be installed by this workflow, regardless
of any opt-in flag.

`superpowers` is the case. It is a Claude *plugin* on this machine, a git install
on pi, and something else again elsewhere. Installing it on a host's behalf means
this workflow guessing at another tool's package model, and being wrong there
leaves the host holding two copies — the outcome this workflow removes everywhere
else.

This is the same distinction the capability already draws for system runtimes,
extended to the case that motivated it: what may be offered is a package
installed *through* a runtime already present, which `@fission-ai/openspec` is
and `superpowers` is not.

#### Scenario: A host-owned prerequisite is missing

- **WHEN** `superpowers` is absent for a detected host
- **THEN** the installer SHALL report the command that host uses to install it
- **AND** SHALL NOT offer to run it

#### Scenario: The opt-in flag is set

- **WHEN** the named opt-in flag is passed and a host-owned prerequisite is
  missing
- **THEN** it SHALL still be reported rather than installed, because the flag
  substitutes for consent and not for ownership

#### Scenario: A host-owned prerequisite is present for one host and not another

- **WHEN** a prerequisite is installed for one detected host and missing for
  another
- **THEN** the report SHALL name the hosts separately rather than reporting a
  single presence, because per-host installs succeed and fail per host
