## ADDED Requirements

### Requirement: The producer's implementation is tracked in core

The plan-review producer SHALL have a tracked implementation under
`reference-implementations/`, alongside the other shared-bin artifacts. The
copy installed at `~/.agenticapps/bin/` SHALL be derivable from it.

An artifact that exists only in an install directory has no source of truth: it
cannot be reviewed, diffed, or recovered.

#### Scenario: The producer is inspected for provenance

- **WHEN** a maintainer asks where the plan-review producer comes from
- **THEN** a tracked file under `reference-implementations/run-plan-review/`
  answers it, and its content matches what is installed

#### Scenario: The install directory is lost

- **WHEN** `~/.agenticapps/bin/` is deleted or the machine is replaced
- **THEN** the producer is recoverable from the repository and republishable
  without reconstruction

### Requirement: The producer carries a version marker

The producer SHALL declare a version marker that installers read before
overwriting a shared copy. An installer SHALL refuse to overwrite a higher
version, treating an unmarked file as `0.0.0`.

#### Scenario: An older host installer runs

- **WHEN** a host installer carrying an older producer runs against a shared
  copy at a higher version
- **THEN** the shared copy is left untouched

### Requirement: The reviewer floor matches the spec

The producer SHALL default its required-reviewer floor to the floor §18
specifies — one independent reviewer as of spec 1.1.0. An explicit caller-set
value SHALL be honoured only when it is an integer of 1 or greater.

The producer MUST NOT enforce a floor stricter than the spec's by default. A
stricter default converts a partial result into no result, which is the outcome
§18 changed the floor to avoid. It MUST NOT accept a floor below the spec's,
which would let a caller publish evidence of a review that did not happen.

#### Scenario: One reviewer succeeds, others time out

- **WHEN** a review run requests three vendors and exactly one returns a
  complete review
- **THEN** the producer writes `REVIEWS.md` containing that review and exits
  successfully, because one reviewer meets the floor

#### Scenario: No reviewer returns

- **WHEN** a review run requests reviewers and none returns a complete review
- **THEN** the producer does not write `REVIEWS.md` and exits non-zero, because
  zero reviewers does not meet the floor

#### Scenario: A caller demands a stricter bar

- **WHEN** a caller sets the floor explicitly above the spec default
- **THEN** the producer enforces the caller's value

#### Scenario: A caller sets the floor below the spec's

- **WHEN** a caller sets the floor to `0`, a negative value, or a non-integer
- **THEN** the producer exits with a usage error and writes nothing, rather
  than publishing a `REVIEWS.md` whose floor was never evaluated

### Requirement: Only a review with a verdict and a body counts

A reviewer section SHALL count toward the floor only if it carries a verdict and
at least one line of substance beyond that verdict. Output that is non-empty and
exited zero is not by itself a review.

The verdict grammar, the closed vocabulary, the section boundaries and the
conflict rule are those the gate enforces — the producer and the gate SHALL
apply the same predicate, so that a section the producer counts is a section the
gate counts. A producer that counted more loosely would publish evidence its own
verifier rejects.

A vendor that produced output without a verdict, or with a verdict and no body,
SHALL be recorded as failed with that specific reason.

Both halves were violated in observation on 2026-07-29. Reviewing this very
change, opencode emitted a preamble stating it would fact-check, produced no
verdict, and counted as one of three reviewers. Reviewing `shim-project-hooks`
at 07:52:54Z, gemini returned a bare `VERDICT: APPROVE` with no body, and that
counted too. With the floor at one, either alone opens the gate.

#### Scenario: A vendor returns prose with no verdict

- **WHEN** a vendor exits zero having written commentary that contains no
  parseable verdict
- **THEN** that section does not count toward the floor, and the vendor is
  reported as failed with the reason "no verdict"

#### Scenario: A vendor returns a verdict with no body

- **WHEN** a vendor exits zero having written only a verdict line
- **THEN** that section does not count toward the floor, and the vendor is
  reported as failed with the reason "no substance"

#### Scenario: A vendor returns a verdict requesting changes

- **WHEN** a vendor returns a parseable verdict of REQUEST-CHANGES
- **THEN** it counts toward the floor, because an objection is a review; the
  gate reports the objection separately rather than discounting the reviewer

### Requirement: The implementing host is declared, never defaulted

The producer SHALL require the implementing host's identity as an explicit
input, from the closed vendor vocabulary `claude` | `codex` | `gemini` |
`opencode`. It SHALL NOT supply a default. When the identity is absent or
outside the vocabulary, the producer SHALL exit with a usage error and write
nothing.

The implementing host's own vendor SHALL NOT count toward the floor, and a
vendor named more than once SHALL count once. At a floor of one, this is what
distinguishes an independent opinion from the implementer marking their own
work.

The producer SHALL record the identity in `REVIEWS.md`, because the party that
later evaluates the evidence is frequently not the party that produced it. CI, a
pre-commit hook, or another agent reads the artifact without any knowledge of
the host that wrote it.

A default is not a lesser version of this rule; it is the defect. The producer
today defaults to `claude` (`AGENT_SELF:-claude`), which is wrong on three of
the four hosts, and the gate defaults to empty, which applies no self-exclusion
at all.

#### Scenario: The identity is not supplied

- **WHEN** the producer is invoked without an implementing-host identity
- **THEN** it exits with a usage error and writes no `REVIEWS.md`, rather than
  assuming the host it was first written on

#### Scenario: The identity is outside the vocabulary

- **WHEN** the producer is given an identity that is not one of the four known
  vendors
- **THEN** it exits with a usage error and writes nothing

#### Scenario: The implementing host is among the requested reviewers

- **WHEN** the declared implementing host's vendor is among those requested and
  returns a review
- **THEN** that section does not count toward the floor, and is recorded as
  excluded rather than failed

#### Scenario: The same vendor is requested twice

- **WHEN** a caller names the same vendor more than once
- **THEN** it contributes at most one toward the floor

#### Scenario: The evidence is read on another host

- **WHEN** a `REVIEWS.md` produced on one host is evaluated on another
- **THEN** the implementing host is recoverable from the artifact, so
  self-exclusion applies to the host that authored the change

#### Scenario: The change was authored across a handoff

- **WHEN** more than one agent authored the change
- **THEN** the producer accepts and records every implementing host, and each is
  excluded from the floor

### Requirement: Downgrading a shared artifact is explicit, scoped and logged

The shared installer refuses to overwrite a copy whose version marker is higher
than the one being installed. That arbiter is what stops an older host installer
clobbering a newer artifact, and it also blocks every deliberate rollback.

A downgrade path SHALL therefore exist, and SHALL be:

- **opt-in per invocation** — never a configuration default, never inferred;
- **scoped to one named artifact** — not a mode that disables arbitration for a
  whole install run;
- **logged with the versions replaced and the reason given**, in a record that
  outlives the terminal.

This is specified in the capability rather than left to a migration task,
because it weakens the only protection the shared directory has against being
silently reverted. A reviewer objected that a security-relevant installer change
appearing only in a task list is not specified at all, and that is right.

The log is the audit trail. Routing it to a monitoring system was proposed and
is out of scope — this fleet has no such system, and naming one this change does
not build would be a requirement nobody can satisfy.

#### Scenario: A rollback is performed

- **WHEN** an operator republishes a lower version of a shared artifact
- **THEN** the downgrade is refused unless explicitly requested for that
  artifact, and the replacement is recorded with both versions

#### Scenario: An older host installer runs normally

- **WHEN** a host installer carrying an older artifact runs without the
  downgrade request
- **THEN** the arbiter refuses, exactly as before

### Requirement: Requiring the identity is a breaking interface change

Removing the identity default changes the producer's calling convention: an
invocation that succeeded before now exits with a usage error. Every existing
caller SHALL be inventoried and migrated in the same change that removes the
default.

The gate is unaffected — it reads the identity from the artifact, not from its
own environment, so no CI or pre-commit caller changes. That narrower claim is
the one this capability makes; an earlier revision stated it as "no flag day"
without qualification, which was wrong about the producer.

#### Scenario: An existing caller invokes the producer

- **WHEN** a script, skill or hook that invoked the producer before the change
  invokes it after
- **THEN** it has been updated to pass an implementing-host identity, because
  the inventory found it

#### Scenario: A caller is missed

- **WHEN** an un-migrated caller invokes the producer
- **THEN** it fails with a usage error naming the missing input, rather than
  producing evidence attributed to a guessed host

### Requirement: A partial result is reported, not discarded

When at least the floor is met but fewer reviewers succeeded than were
requested, the producer SHALL write the reviews it obtained rather than
discarding them.

Silently discarding a completed review wastes the reviewer's work and hides
which opinions are missing.

#### Scenario: Two of three vendors fail

- **WHEN** three vendors are requested, one returns a review, and two time out
- **THEN** `REVIEWS.md` contains the one review and the run exits successfully

### Requirement: REVIEWS.md is self-contained

`REVIEWS.md` SHALL record, in the artifact itself, which vendors were
requested, which produced a counted review, which were excluded, and which
failed with the reason. This record SHALL NOT exist only in the run's stderr.

It SHALL additionally record a trailer, in the grammar the gate specifies —
exactly one block, as the final content of the file, carrying:

- the **implementing host** identities, one or more from the closed vendor
  vocabulary;
- the **digest** of the artifacts reviewed, computed as the gate specifies;
- the **producer version** that wrote the file.

The producer and the gate SHALL use that one grammar. Specifying the trailer as
"something the gate can parse" is what this change spent a requirement fixing
elsewhere; two implementations need the format written down, whichever two they
are.

These three are what let a later reader — or the gate, on another machine —
establish who authored the change, what text was actually reviewed, and under
which rules the evidence was gathered. Without them the artifact is a
transcript, not evidence.

A consumer reading the artifact months later has no access to the terminal that
produced it. Without this, "two reviewers" is indistinguishable from "two of
five reviewers, three of which failed", and the artifact overstates the scrutiny
the change received.

A run that fails the floor writes nothing, so a fully-failed run leaves no
artifact and its diagnostics exist only on stderr. This is deliberate — a
`REVIEWS.md` recording only failures would be evidence of a review that did not
happen, and the gate reads presence as well as content — but it means the
audit trail has a hole exactly where a run went worst. Callers wanting that
record keep the run's output.

#### Scenario: A later reader audits coverage

- **WHEN** a reader opens an archived `REVIEWS.md`
- **THEN** it states which vendors were asked and what became of each, so
  "not requested" is distinguishable from "failed" and from "approved"

#### Scenario: A vendor fails for a reason other than timeout

- **WHEN** a vendor returns a non-zero exit, an error, or output with no verdict
- **THEN** it is recorded as failed with that specific reason, not as a timeout
  and not as absent

### Requirement: The egress boundary is declared as it actually is

The producer hands change content — proposal, design note and spec deltas — to
external vendor CLIs, which forward it beyond this machine. The capability SHALL
declare what is handed over and to which vendors.

It SHALL NOT describe the prompt as the boundary. The vendors are **agentic
CLIs**: they run with the operator's credentials and filesystem access, and they
**read, write and execute**. They read whatever they judge relevant — the
repository, the working tree, configuration and credential files under `$HOME` —
and they can also modify files and run commands as this user. The boundary is
what that vendor CLI can do on this machine while running as this user.

An earlier revision described reading only. A reviewer pointed out the omission
and it matters more than the read case: a reviewer CLI that edits the change it
is reviewing, or runs a command, is outside anything this capability models.
Stating the boundary as read-only would leave that unconsidered, and would let a
reader conclude that keeping secrets out of the proposal keeps them off the
wire, which is separately false.

Constraining vendors to a read-only sandbox would close this and is not
attempted here — the CLIs offer no uniform mechanism. The exposure is declared,
not mitigated.

Invoking the producer constitutes the operator's consent **to running the named
vendors**. It SHALL NOT be described as consent to a particular set of files,
because the producer does not control what the vendor reads.

The producer SHALL NOT pass change content as a process argument, on any vendor
arm, because the process table is readable by other local processes. The
delivery mechanism — a file path or standard input — is the implementation's
choice per arm; the requirement is the property, not the mechanism, because at
least one vendor arm cannot use stdin without hanging.

**No secret or PII screening is performed.** The capability SHALL say so
explicitly and SHALL recommend that the operator check change content for
secrets before invoking. Screening is deferred to the named follow-up change
`screen-review-egress`. Declaring the boundary is what makes that deferral
visible rather than silent.

Because invocation alone is the consent act, the producer SHALL print a notice
on stderr at invocation naming the vendors it is about to run and stating that
no screening is performed. Documentation the operator read once is a weak
consent record for an action that ships change content off the machine; a notice
at the moment of egress is not.

#### Scenario: An operator asks what leaves the machine

- **WHEN** an operator reads the capability documentation
- **THEN** it names the artifacts handed over and the vendors they reach, and
  states that the vendors may read beyond them

#### Scenario: An operator asks whether secrets are screened

- **WHEN** an operator reads the capability documentation
- **THEN** it states that no screening is performed and recommends checking
  before invoking

#### Scenario: Change content is passed to a vendor CLI

- **WHEN** the producer invokes any vendor CLI with the review prompt
- **THEN** the prompt does not appear in that process's argument list

### Requirement: Reviewer output is untrusted input

Reviewer output SHALL be treated as untrusted third-party input. It is written
verbatim into `REVIEWS.md`, which agents subsequently read as context, so it is
a path by which text from outside this machine reaches an agent's instructions.

The producer SHALL continue to reject a response containing a `## Reviewer:`
heading, which would forge additional reviewer sections, and SHALL continue to
strip vendor banner and hook-log noise from the response's edges without
altering its interior.

**Neither of those is an injection control, and the capability SHALL say so.**
The heading guard defends the reviewer *count*; it does nothing about
instruction-shaped prose in a review body, and reviewer text is written to
`REVIEWS.md` unaltered by design — a review that could be rewritten would not be
a review. Nor does anything screen a response for secrets or PII the agentic
CLI may have read from the filesystem and quoted back.

The mitigation available here is declaration, not sanitisation: the content is
marked as third-party, its provenance is recorded, and screening is deferred to
`screen-review-egress`, which covers the return path as well as the outbound
one. Claiming more would misdescribe a guard that counts headings as a guard
that reads meaning.

This requirement is stated in the capability rather than only in prose because
the property has to survive future edits to the producer. The previous revision
recorded it in the proposal and the task list, where nothing enforces it.

#### Scenario: A vendor response contains a reviewer heading

- **WHEN** a vendor's output contains a line matching `## Reviewer:`
- **THEN** the response is rejected in full and the vendor is recorded as
  failed, rather than being rewritten and recorded

#### Scenario: An agent reads REVIEWS.md as context

- **WHEN** an agent consumes `REVIEWS.md` while working on the change
- **THEN** the capability documents that its contents originate outside this
  machine and are not authored by the operator
