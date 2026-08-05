# installer-prerequisite-consent Specification

## Purpose
TBD - created by archiving change installer-prerequisite-consent. Update Purpose after archive.
## Requirements
### Requirement: An installer declares its prerequisites and reports which are missing

An installer SHALL declare the external tools it depends on and SHALL report
which of them are absent before doing work that requires them.

A *declared prerequisite* is a tool the installer names as a dependency —
`openspec`, `npm`, the host CLI. It is not every executable the script invokes.
Read literally, "every external tool" would include `mkdir`, `grep` and `sed`,
which no installer checks and which would make the requirement either
universally violated or interpreted four different ways. Scoping it to a
declared set is what makes it checkable, and declaring the set is the part that
does the work.

#### Scenario: A declared prerequisite is absent

- **WHEN** an installer runs and a declared prerequisite is not present
- **THEN** it SHALL report that prerequisite by name
- **AND** SHALL state what will not work without it

#### Scenario: Every declared prerequisite is present

- **WHEN** all declared prerequisites are present
- **THEN** the installer SHALL proceed without prompting about any of them

#### Scenario: The missing prerequisite is a system runtime

- **WHEN** a missing declared prerequisite is a system runtime or a host CLI —
  `npm`, `node`, `git`, or the agent's own command
- **THEN** the installer SHALL report it and state how to install it
- **AND** SHALL NOT offer to install it, regardless of the opt-in

A runtime is a different kind of act from a package installed through one.
Installing it is platform-dependent in ways a shell script handles badly — a
package manager per operating system, a version manager that may already own
the tool, and a `sudo` prompt the installer cannot reason about. What may be
offered is a package installed *through* a runtime that is already present,
which is the `@fission-ai/openspec` case the two unconsented installs actually
perform.

#### Scenario: A prerequisite is present but too old

- **WHEN** an installer requires a minimum version of a prerequisite and the
  installed version is older
- **THEN** it SHALL report the found and required versions
- **AND** SHALL treat upgrading it as an install requiring acceptance under the
  requirements below, since replacing a tool already on the machine changes
  software the operator did not ask this installer to touch

### Requirement: Consent is required to change software the workflow does not own

An installer SHALL obtain the operator's explicit acceptance before any write
that can affect software outside the workflow's own control surface. It SHALL
NOT require separate acceptance for writes the operator's request already
covers.

The boundary is **ownership — not location, and not size**:

| Write | Consent | Why |
|---|---|---|
| Files into the target repository | Not required | Running an installer against a repo is the request to change that repo |
| The workflow's own shared directory (`~/.agenticapps/bin/`) | Not required, but SHALL be reported | Created, owned and used exclusively by this workflow. Installing the workflow is what the operator asked for, and these files are what the workflow *is* |
| A third-party package manager's global namespace (`npm i -g`, `pip install --user`) | **Required** | Mutates a namespace shared with software this workflow did not install; it can upgrade or replace a package other projects resolve |
| A host's global configuration outside the repo | **Required** | Shared with the operator's other work on that host |

The test is: *could this write change software the operator did not install by
running this installer?* A file under `~/.agenticapps/bin/` cannot — nothing
else uses it. A global npm package can.

Drawing the line at "outside the repository" instead would catch all four host
installers on their `~/.agenticapps/bin/` write, which every one of them
performs unconditionally, and would put a prompt in front of the mechanism
`docs/PLAN-lightweight-fleet.md` step 2 designates as the primary way core
publishes an artifact — friction against the one operation that document wants
to stay cheap. Drawing it at "large installs" would need a size rule nobody can
state. Ownership separates the two real cases without appealing to either.

#### Scenario: A global package would be installed

- **WHEN** an installer finds a missing prerequisite it could install into a
  third-party package manager's global namespace
- **THEN** it SHALL name the prerequisite and the command it would run
- **AND** SHALL install it only after the operator accepts

#### Scenario: The workflow's own shared directory is written

- **WHEN** an installer writes the workflow's own artifacts into
  `~/.agenticapps/bin/` or an equivalent directory this workflow owns
- **THEN** no acceptance prompt SHALL be required
- **AND** the write SHALL be reported, naming each file

#### Scenario: The operator declines

- **WHEN** the operator declines an install offer
- **THEN** the installer SHALL NOT perform that install
- **AND** SHALL continue with work that does not depend on it
- **AND** SHALL NOT treat declining as an error in the operator's input

#### Scenario: The install command fails after acceptance

- **WHEN** the operator accepts and the install command exits non-zero
- **THEN** the installer SHALL report the failure and the command's exit status
- **AND** SHALL NOT proceed as though the prerequisite were present

#### Scenario: A conformance check finds an unguarded install

- **WHEN** a conformance check finds an install of the consent-requiring kind
  reachable without acceptance and without the opt-in flag
- **THEN** the check SHALL report it as a violation, naming the installer and
  the command

### Requirement: Repository-local writes are covered by the request but not unbounded

An installer SHALL treat provisioning into the target repository as covered by
the operator's request, and SHALL NOT overwrite or delete a file in that
repository which it did not provision without reporting the conflict.

Not requiring consent is not the same as permission to destroy. The operator
asked for the repo to be provisioned; they did not ask for an unrelated file
that happens to share a path to be replaced silently.

#### Scenario: Provisioning the target repository

- **WHEN** an installer writes skills, hooks or configuration it owns into the
  target repository
- **THEN** no acceptance prompt SHALL be required for those writes

#### Scenario: A repository file the installer did not provision is in the way

- **WHEN** provisioning would overwrite or delete a repository file the
  installer did not provision
- **THEN** it SHALL report the conflict naming the path
- **AND** SHALL NOT replace the file without acceptance

### Requirement: Consent is obtained interactively with a default of no

An installer requesting acceptance SHALL read the operator's answer from the
terminal, SHALL treat only an explicit affirmative as acceptance, and SHALL
treat empty input, unrecognised input, and end-of-input as declining.

Leaving the affirmative set and the default to each host produces four
different prompts with four different defaults, which is the divergence this
contract exists to remove. Defaulting to no fails safe: a declined install is
recoverable by re-running, an unwanted global install is not.

Acceptance SHALL be requested per install command, not once for the whole run.
A single blanket prompt makes the operator agree to a set they have not been
shown in full.

#### Scenario: The operator accepts

- **WHEN** the operator answers with an explicit affirmative (`y` or `yes`,
  case-insensitive)
- **THEN** the install SHALL proceed

#### Scenario: The operator gives empty or unrecognised input

- **WHEN** the operator submits an empty line, an unrecognised answer, or the
  input stream ends
- **THEN** the answer SHALL be treated as declining
- **AND** the install SHALL NOT proceed

#### Scenario: Several installs are offered

- **WHEN** more than one consent-requiring install is needed
- **THEN** each SHALL be offered separately with its own command shown

### Requirement: A non-interactive run reports rather than choosing

An installer SHALL detect that no interactive input is available, and in that
case SHALL NOT perform a consent-requiring install and SHALL NOT proceed as
though the prerequisite were satisfied. Standard input not being a terminal
SHALL be the detection rule.

Both silent answers are wrong the same way: each converts the absence of a
decision into a decision, and neither is visible afterwards. Reporting is the
only outcome an operator can act on. Naming the detection rule matters as much
as the behaviour — four hosts inventing four notions of "non-interactive"
reproduces the divergence rather than fixing it.

#### Scenario: No interactive input is available

- **WHEN** standard input is not a terminal and a consent-requiring install is
  needed
- **THEN** the installer SHALL NOT perform it
- **AND** SHALL report the prerequisite, the command that would install it, and
  the opt-in flag that authorises doing so unattended

#### Scenario: The run cannot complete without the prerequisite

- **WHEN** the missing prerequisite prevents the installer from completing its
  work
- **THEN** it SHALL exit non-zero
- **AND** SHALL NOT report success for work it did not do

### Requirement: A named opt-in flag substitutes for interactive acceptance

An installer capable of performing a consent-requiring install SHALL accept the
environment variable `AGENTICAPPS_INSTALL_PREREQS=1` and the command-line flag
`--install-prereqs`, and SHALL treat either as the operator's acceptance for
every install in that run. An installer that performs no such install is not
required to accept them.

The name is fixed by this requirement. Leaving it to each host guarantees four
spellings, which defeats "one answer stated once" and makes the non-interactive
report — which must name the flag that authorises the install — unscoreable.

Requiring the flag of every installer regardless would oblige an
install-nothing installer to advertise a capability it does not have, which is
why the obligation is scoped to those that can install.

#### Scenario: The opt-in is set

- **WHEN** an installer runs with `AGENTICAPPS_INSTALL_PREREQS=1` or
  `--install-prereqs` and a prerequisite is missing
- **THEN** it MAY perform the install without prompting
- **AND** SHALL report each thing it installed because of the opt-in

#### Scenario: The opt-in is absent

- **WHEN** neither the variable nor the flag is set
- **THEN** their absence SHALL NOT be interpreted as acceptance

#### Scenario: An installer that installs nothing

- **WHEN** an installer only detects and instructs, never installing a
  consent-requiring prerequisite
- **THEN** it SHALL NOT be required to accept the opt-in
- **AND** SHALL NOT be reported as non-conformant for lacking it

### Requirement: A reported command does not leak credentials

An installer SHALL NOT print a command containing a credential, token, or
registry secret. Where the real command carries one, it SHALL print the command
with the secret replaced by a placeholder.

The requirement to show the exact command exists so the operator can judge it,
and installer output routinely lands in CI logs. An unredacted registry URL with
an embedded token turns a transparency measure into a disclosure.

#### Scenario: The install command carries a secret

- **WHEN** the command that would be run contains a credential or token
- **THEN** the printed form SHALL replace it with a placeholder
- **AND** SHALL remain specific enough to identify what would be installed

### Requirement: Skipped work is reported and distinguished from completed work

An installer that continues after an install was declined or failed SHALL name
the steps it skipped and what the operator must do to complete them, and its
summary SHALL distinguish completed work from skipped work. It SHALL exit
non-zero when a step it was asked to perform was skipped.

An installer that silently omits a step exits 0 having done less than the
operator believes — the same failure as a harness certifying nothing and
returning green. Reporting alone is not sufficient, because a zero exit is what
an automated caller reads.

#### Scenario: A step is skipped for a missing prerequisite

- **WHEN** an installer skips a step because a prerequisite is absent
- **THEN** it SHALL name the skipped step and the prerequisite it needed
- **AND** SHALL state the command that completes it later

#### Scenario: The run finishes with steps skipped

- **WHEN** an installer completes with one or more steps skipped
- **THEN** its summary SHALL distinguish completed work from skipped work
- **AND** it SHALL exit non-zero

### Requirement: A prerequisite installed on the operator's behalf is left in place on removal

An uninstaller SHALL NOT remove a prerequisite that was installed on the
operator's behalf, and SHALL report what it is leaving installed together with
the command that removes it.

The ownership test runs in both directions. By the time the workflow is
removed, a package the operator accepted may be resolved by projects this
workflow never touched, so removing it changes software the workflow does not
own — the act consent exists to prevent. Reporting is what stops that from
becoming an unnoticed residue: the operator learns the machine still carries
something this workflow put there, and how to take it away themselves.

This governs prerequisites only. The workflow's own artifacts under
`~/.agenticapps/bin/` are the workflow, not a prerequisite, and removing them
is what uninstalling means.

#### Scenario: The workflow is removed after a prerequisite was installed for it

- **WHEN** an uninstaller runs and a prerequisite was installed on the
  operator's behalf during a previous install
- **THEN** it SHALL NOT remove that prerequisite
- **AND** SHALL report the prerequisite by name and the command that removes it

#### Scenario: The workflow's own artifacts are removed

- **WHEN** an uninstaller removes the workflow's own artifacts from a directory
  this workflow owns
- **THEN** those removals SHALL NOT be governed by this requirement

