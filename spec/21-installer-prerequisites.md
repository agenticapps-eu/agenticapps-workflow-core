---
id: 21-installer-prerequisites
section_type: declarative-contract
spec_version: 1.6.0
---

# 21 — Installer prerequisites and consent

**Section type**: declarative-contract. Host implementations satisfy the
requirements below in whatever idiom is natural for the host runtime. The
keywords MUST, MUST NOT, SHALL, SHALL NOT, SHOULD and MAY are used per
[RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

This section binds any script a host ships that provisions the workflow onto a
machine — conventionally `install.sh`. It says nothing about *which*
prerequisites a host needs. `codex-workflow` needing `codex` and
`pi-agentic-apps-workflow` needing `pi` is legitimate host-specific variation;
what is shared is what an installer does when one of them is absent.

## Why this section exists

Four host installers detect prerequisites and then disagree about what to do
next:

| Installer | On a missing `openspec` |
|---|---|
| `claude-workflow` | prints `npm i -g …`, never installs |
| `codex-workflow` | runs `npm i -g` automatically, no consent |
| `opencode-workflow` | runs `npm i -g` automatically, no consent |
| `pi-agentic-apps-workflow` | prints `npm i -g …`, never installs |

Two of the four change a tool every other project on the machine resolves,
without asking. Their own comments say this is deliberate — "the front end's
core dependency — auto-install it rather than only instructing" — so it is a
considered position rather than an oversight, and it deserves an argument
rather than a quiet repair. None of the four offers, which is the option the
operator would most likely want.

Nobody decided this. It accumulated, exactly as the three unscoreable-target
behaviours did before §20, and the same remedy applies: state the contract,
then score it.

## Terms

A **declared prerequisite** is an external tool the installer names as a
dependency — `openspec`, `npm`, the host CLI. It is not every executable the
script invokes. Read literally, "every external tool" would include `mkdir`,
`grep` and `sed`, which no installer checks and which would make the
requirement either universally violated or interpreted four different ways.
Scoping it to a declared set is what makes it checkable, and declaring the set
is the part that does the work.

A **consent-requiring install** is any write that can affect software outside
the workflow's own control surface. The test is stated once, and everything
below refers back to it:

> *Could this write change software the operator did not install by running
> this installer?*

A **system runtime** is a tool other software is installed *through* or *by* —
`npm`, `node`, `git` — together with a host's own CLI. A package installed
through a runtime already present is not a system runtime.

## The boundary is ownership, not location

| Write | Consent | Why |
|---|---|---|
| Files into the target repository | Not required | Running an installer against a repo is the request to change that repo |
| The workflow's own shared directory (`~/.agenticapps/bin/`) | Not required, but MUST be reported | Created, owned and used exclusively by this workflow. Installing the workflow is what the operator asked for, and these files are what the workflow *is* |
| A third-party package manager's global namespace (`npm i -g`, `pip install --user`) | **Required** | Mutates a namespace shared with software this workflow did not install; it can upgrade or replace a package other projects resolve |
| A host's global configuration outside the repo | **Required** | Shared with the operator's other work on that host |

A file under `~/.agenticapps/bin/` cannot change software the operator did not
install by running this installer — nothing else on the machine uses it. A
global npm package can.

Drawing the line at "outside the target repository" instead would catch all
four host installers on their `~/.agenticapps/bin/` write, which every one of
them performs unconditionally, and would put a prompt in front of the mechanism
`docs/PLAN-lightweight-fleet.md` step 2 designates as the primary way core
publishes an artifact — friction against the one operation that document wants
to stay cheap. Drawing it at "large installs" would need a size rule nobody can
state. Ownership separates the two real cases without appealing to either.

The exemption is paired with a reporting obligation, and the pairing is not
decorative. An exemption that also made the write invisible would be a loophole
rather than a boundary.

## Requirements

### Declaring and reporting

An installer:

- **MUST** declare the external tools it depends on, and **MUST** report by
  name each declared prerequisite that is absent, together with what will not
  work without it. This is the observable the rest of this section is scored
  against; all four installers already satisfy it, and it is stated so that
  remains true rather than to change anything.
- **MUST NOT** prompt about a prerequisite that is present. Consent is a
  question about a write that is going to happen, not a checkpoint.
- **MUST** report every file it writes into a directory this workflow owns,
  naming each file. No acceptance is required for those writes.
- **MUST** report the found and the required version when it requires a minimum
  version of a prerequisite and the installed version is older, and **MUST**
  treat upgrading it as an install subject to every requirement below.
  Replacing a tool already on the machine changes software the operator did not
  ask this installer to touch, which is the same act the consent rule governs;
  arriving at it through a version comparison does not make it a different one.

### Offering, and what is never offered

An installer:

- **SHOULD** offer to install a missing declared prerequisite that it is
  capable of installing. An installer that only detects and instructs is
  conformant with this section and **MUST NOT** be reported as violating it.
  Instructing is not the divergence this section closes; installing without
  asking is.
- **MUST NOT** offer to install a system runtime, and **MUST** instead report
  it and state how to install it. This holds regardless of the opt-in below.

  A runtime is a different kind of act from a package installed through one.
  Installing it is platform-dependent in ways a shell script handles badly — a
  package manager per operating system, a version manager that may already own
  the tool, and a `sudo` prompt the installer cannot reason about. What may be
  offered is a package installed *through* a runtime that is already present,
  which is the `@fission-ai/openspec` case the two unconsented installs
  actually perform.

### Consent

An installer:

- **MUST** obtain the operator's explicit acceptance before a consent-requiring
  install, and **MUST** name the prerequisite and print the command it would
  run before asking.
- **MUST NOT** require separate acceptance for writes the operator's request
  already covers — provisioning the target repository, and writing the
  workflow's own artifacts into a directory this workflow owns.
- **MUST** read the answer from the terminal, treat only an explicit
  affirmative (`y` or `yes`, case-insensitive) as acceptance, and treat empty
  input, unrecognised input and end-of-input as declining.

  Leaving the affirmative set and the default to each host produces four
  prompts with four defaults, which is the divergence this contract exists to
  remove, reintroduced one level down. Defaulting to no fails safe: a declined
  install is recoverable by re-running, an unwanted global install is not.

- **MUST** request acceptance once per install command rather than once for the
  whole run. A single blanket prompt makes the operator agree to a set they
  have not been shown in full.
- **MUST NOT** perform an install the operator declined, **MUST** continue with
  work that does not depend on it, and **MUST NOT** treat declining as an error
  in the operator's input.
- **MUST** report the failure and the exit status when an accepted install
  command fails, and **MUST NOT** proceed as though the prerequisite were
  present.

### Repository-local writes

An installer:

- **MUST** treat provisioning into the target repository as covered by the
  operator's request.
- **MUST** report the conflict, naming the path, and **MUST NOT** replace the
  file without acceptance, when provisioning would overwrite or delete a
  repository file the installer did not provision.

  Not requiring consent is not permission to destroy. The operator asked for
  the repository to be provisioned; they did not ask for an unrelated file that
  happens to share a path to be replaced silently. Without the first clause the
  consent rule would read as forbidding installation altogether; without the
  second, as licensing anything inside the repo.

### Non-interactive runs

An installer:

- **MUST** detect that no interactive input is available, and **MUST** use
  standard input not being a terminal as the detection rule. Naming the rule
  matters as much as the behaviour — four hosts inventing four notions of
  "non-interactive" reproduces the divergence rather than fixing it.
- **MUST NOT**, in that case, perform a consent-requiring install, and **MUST
  NOT** proceed as though the prerequisite were satisfied.

  Both silent answers are wrong the same way: each converts the absence of a
  decision into a decision, and neither is visible afterwards. This is the rule
  §20 settled for an unscoreable target — an unanswerable question is reported,
  never answered by assumption.

- **MUST** report the prerequisite, the command that would install it, and the
  opt-in that authorises doing so unattended.
- **MUST** exit non-zero when the missing prerequisite prevents it from
  completing its work, and **MUST NOT** report success for work it did not do.

### The opt-in

An installer capable of performing a consent-requiring install:

- **MUST** accept the environment variable `AGENTICAPPS_INSTALL_PREREQS=1` and
  the command-line flag `--install-prereqs`, and **MUST** treat either as the
  operator's acceptance for every install in that run.
- **MUST** report each thing it installed because of the opt-in.
- **MUST NOT** interpret the absence of both as acceptance. Otherwise the
  opt-in is decoration.

An installer that performs no consent-requiring install **MUST NOT** be
required to accept either, and **MUST NOT** be reported as non-conformant for
lacking them. Requiring the flag regardless would oblige an install-nothing
installer to advertise a capability it does not have.

The names are fixed by this section rather than left to each host. Four
spellings would defeat "one answer stated once", and would make the
non-interactive report — which has to name the flag that authorises the
install — unscoreable.

### Reported commands

An installer:

- **MUST NOT** print a command containing a credential, token or registry
  secret, and **MUST** print such a command with the secret replaced by a
  placeholder, in a form still specific enough to identify what would be
  installed.

  Showing the exact command exists so the operator can judge it, and installer
  output routinely lands in CI logs. An unredacted registry URL with an
  embedded token turns a transparency measure into a disclosure.

### Skipped work

An installer that continues after an install was declined or failed:

- **MUST** name each step it skipped, the prerequisite it needed, and the
  command that completes it later.
- **MUST** distinguish completed work from skipped work in its summary.
- **MUST** exit non-zero when a step it was asked to perform was skipped.

  An installer that silently omits a step exits 0 having done less than the
  operator believes — the same failure as a harness certifying nothing and
  returning green (§20). Reporting alone is not sufficient, because a zero exit
  is what an automated caller reads.

### Removal

An uninstaller:

- **MUST NOT** remove a prerequisite that was installed on the operator's
  behalf, and **MUST** report what it is leaving installed together with the
  command that removes it.

  The ownership test runs in both directions. By the time the workflow is
  removed, a package the operator accepted may be resolved by projects this
  workflow never touched, so removing it changes software the workflow does not
  own — the act consent exists to prevent. Reporting is what stops the residue
  from going unnoticed.

- Is not governed by this requirement when removing the workflow's own
  artifacts from a directory this workflow owns. Those are the workflow, not a
  prerequisite, and removing them is what uninstalling means.

## Conformance

Everything above is MUST-level except one clause, and the exception is the
load-bearing one: **offering to install a prerequisite is SHOULD**. An
installer that detects a missing `openspec` and prints the command is
conformant with this section. What is forbidden is installing without asking,
not declining to install at all — so `claude-workflow` and
`pi-agentic-apps-workflow` conform today on the consent requirement, and gain
only the reporting obligation on their `~/.agenticapps/bin/` write.

The rest are MUST because each has a silent failure mode that a SHOULD would
leave available. A prompt with a host-chosen default is a divergence; a
non-interactive run that picks an answer is an invisible decision; a zero exit
after a skipped step is a lie an automated caller reads; an unredacted command
is a disclosure. None of these is a matter of host idiom, which is the usual
ground for SHOULD in this spec.

Two hosts are non-conformant today. `codex-workflow` and `opencode-workflow`
both reach `npm i -g @fission-ai/openspec` with no prompt and no opt-in. This
section does not change them — each host adopts on its own schedule, as with
`host-neutral-instruction-files` — and their current behaviour is preserved
exactly, as what the opt-in now does.

Scored by `tools/installer-prereq-conformance.sh`, which takes one installer
path and is subject to §20: it aborts on a target it cannot use, reports every
row it cannot decide statically as inconclusive rather than passing, and emits
a coverage line on every run. Consent behaviour is only fully observable by
running an installer, and running a host's installer is not something core can
do safely — it writes to the operator's machine, which is the very thing under
discussion. So the harness scores what is statically checkable and declines to
claim the rest.
