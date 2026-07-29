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

### Requirement: Only a review with a verdict counts

A reviewer section SHALL count toward the floor only if it carries a parseable
verdict. Output that is non-empty and exited zero is not by itself a review.

A vendor that produced output without a verdict SHALL be recorded as failed,
with that as the reason.

This requirement exists because it was violated in observation: reviewing this
very change on 2026-07-29, opencode emitted a preamble stating it would
fact-check, produced no verdict, and was counted as one of three reviewers.
With the floor at one, such a section alone would open the gate.

#### Scenario: A vendor returns prose with no verdict

- **WHEN** a vendor exits zero having written commentary that contains no
  parseable verdict
- **THEN** that section does not count toward the floor, and the vendor is
  reported as failed with the reason "no verdict"

#### Scenario: A vendor returns a verdict requesting changes

- **WHEN** a vendor returns a parseable verdict of REQUEST-CHANGES
- **THEN** it counts toward the floor, because an objection is a review; the
  gate reports the objection separately rather than discounting the reviewer

### Requirement: Reviewers counted toward the floor are independent

The host's own vendor SHALL NOT count toward the floor, and a vendor named more
than once SHALL count once. Self-exclusion SHALL be determined by rule, not by
an environment variable whose default is correct on only one host.

At a floor of one, this is what distinguishes an independent opinion from the
implementer marking their own work.

#### Scenario: The host requests itself as a reviewer

- **WHEN** the running host's own vendor is among those requested and returns a
  review
- **THEN** that section does not count toward the floor, and is recorded as
  excluded rather than failed

#### Scenario: The same vendor is requested twice

- **WHEN** a caller names the same vendor more than once
- **THEN** it contributes at most one toward the floor

#### Scenario: The producer runs on a non-default host

- **WHEN** the producer runs on a host other than the one its environment
  default names
- **THEN** self-exclusion still applies to the actual running host

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

A consumer reading the artifact months later has no access to the terminal that
produced it. Without this, "two reviewers" is indistinguishable from "two of
five reviewers, three of which failed", and the artifact overstates the scrutiny
the change received.

#### Scenario: A later reader audits coverage

- **WHEN** a reader opens an archived `REVIEWS.md`
- **THEN** it states which vendors were asked and what became of each, so
  "not requested" is distinguishable from "failed" and from "approved"

#### Scenario: A vendor fails for a reason other than timeout

- **WHEN** a vendor returns a non-zero exit, an error, or output with no verdict
- **THEN** it is recorded as failed with that specific reason, not as a timeout
  and not as absent

### Requirement: The egress boundary is declared

The producer sends change content — proposal, design note and spec deltas — to
external vendor CLIs, which forward it beyond this machine. The capability
SHALL declare this: what is sent, to which vendors, and that invoking the
producer constitutes the operator's consent.

The producer SHALL NOT pass change content as a process argument, because the
process table is readable by other local processes.

Secret and PII screening of change content before egress is explicitly NOT
required by this requirement and is deferred to its own change. Declaring the
boundary is what makes that deferral visible rather than silent.

#### Scenario: An operator asks what leaves the machine

- **WHEN** an operator reads the capability documentation
- **THEN** it names the artifacts transmitted and the vendors they reach

#### Scenario: Change content is passed to a vendor CLI

- **WHEN** the producer invokes a vendor CLI with the review prompt
- **THEN** the prompt is passed by file, not as a command-line argument, so it
  does not appear in the process table
