## ADDED Requirements

### Requirement: An installer detects its prerequisites and reports what is missing

An installer SHALL check for every external tool it depends on before doing
work that requires it, and SHALL report which prerequisites are missing rather
than failing partway through on the first use.

Detection is the part all four current installers already do. Stating it makes
the report the observable, so an operator learns what is missing in one place
instead of discovering it at the point of failure.

#### Scenario: A prerequisite is absent

- **WHEN** an installer runs and a tool it depends on is not present
- **THEN** it SHALL report that prerequisite by name
- **AND** SHALL state what will not work without it

#### Scenario: Every prerequisite is present

- **WHEN** all prerequisites are present
- **THEN** the installer SHALL proceed without prompting about any of them

### Requirement: Installing outside the target repository requires the operator's acceptance

An installer SHALL NOT install software outside the target repository without
the operator explicitly accepting first. It SHALL offer, state what will be
installed and by what command, and wait for acceptance.

A global package install is not a repository-local side effect. It changes a
tool every other project on that machine resolves, and the operator asked for
one repository to be provisioned.

#### Scenario: A missing prerequisite can be installed automatically

- **WHEN** an installer finds a missing prerequisite it is capable of installing
- **THEN** it SHALL name the prerequisite and the exact command it would run
- **AND** SHALL install it only after the operator accepts

#### Scenario: The operator declines

- **WHEN** the operator declines the offer
- **THEN** the installer SHALL NOT install the prerequisite
- **AND** SHALL continue with the work that does not require it, or stop and
  report, but SHALL NOT treat declining as an error in the operator's input

#### Scenario: Installing without asking

- **WHEN** an installer installs software outside the target repository with no
  acceptance obtained and no explicit opt-in flag
- **THEN** the condition SHALL be reported as a violation naming the installer
  and the command it ran

### Requirement: Writes inside the target repository do not require separate acceptance

An installer SHALL treat provisioning files into the repository it was pointed
at as covered by the operator's request to run it, and SHALL NOT require
per-file acceptance for them.

The boundary is what distinguishes this requirement from an installer that
cannot install anything. Running an installer against a repository is a request
to change that repository; it is not a request to change the machine.

#### Scenario: Provisioning the target repository

- **WHEN** an installer writes skills, hooks or configuration into the target
  repository
- **THEN** no acceptance prompt SHALL be required for those writes

#### Scenario: Writing to a shared location outside the repository

- **WHEN** an installer writes to a location shared across projects — a global
  package root, a shared binary directory, or a host's global configuration
- **THEN** that write SHALL require acceptance, regardless of how small it is

### Requirement: A non-interactive run resolves the ambiguity by reporting, not by choosing

When no interactive input is available, an installer SHALL NOT install outside
the target repository and SHALL NOT proceed as though the prerequisite were
satisfied. It SHALL report what is missing and what the operator can do about
it, and exit non-zero if it cannot complete its work.

Both silent answers are wrong in the same way: each converts the absence of a
decision into a decision, and neither is visible afterwards. Reporting is the
only outcome an operator can act on.

#### Scenario: No interactive input available

- **WHEN** an installer runs with no interactive input — a pipeline, a CI job,
  or a piped shell
- **AND** a prerequisite it would offer to install is missing
- **THEN** it SHALL NOT install it
- **AND** SHALL report the prerequisite, the command that would install it, and
  the flag that authorises doing so unattended

#### Scenario: Non-interactive run cannot complete its work

- **WHEN** the missing prerequisite prevents the installer from completing
- **THEN** it SHALL exit non-zero
- **AND** SHALL NOT report success for work it did not do

### Requirement: An explicit flag substitutes for interactive acceptance

An installer SHALL provide an explicit opt-in flag or environment variable that
authorises installing prerequisites without a prompt, and SHALL treat its
presence as the operator's acceptance.

Without this, requiring consent would make unattended installation impossible
and invite a fork that skips the check entirely. The flag keeps automation
working while leaving the decision recorded at the call site, where it can be
read, rather than inside the installer, where it cannot.

#### Scenario: The opt-in flag is passed

- **WHEN** an installer runs with the documented opt-in flag set and a
  prerequisite is missing
- **THEN** it MAY install the prerequisite without prompting
- **AND** SHALL report each thing it installed because of the flag

#### Scenario: The flag is absent

- **WHEN** the flag is not set
- **THEN** its absence SHALL NOT be interpreted as acceptance

### Requirement: Proceeding without a prerequisite is reported, not assumed

When an installer continues after a prerequisite was declined or could not be
installed, it SHALL report which steps it skipped and what the operator must do
to complete them.

An installer that silently omits a step exits 0 having done less than the
operator believes. That is the same failure as a harness certifying nothing and
returning green.

#### Scenario: A step is skipped for a missing prerequisite

- **WHEN** an installer skips a step because a prerequisite is absent
- **THEN** it SHALL name the skipped step and the prerequisite it needed
- **AND** SHALL state the command that completes it later

#### Scenario: The installer finishes with steps skipped

- **WHEN** an installer completes with one or more steps skipped
- **THEN** its summary SHALL distinguish completed work from skipped work
