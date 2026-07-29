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
value SHALL be honoured.

The producer MUST NOT enforce a floor stricter than the spec's by default. A
stricter default converts a partial result into no result, which is the outcome
§18 changed the floor to avoid.

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

### Requirement: A partial result is reported, not discarded

When at least the floor is met but fewer reviewers succeeded than were
requested, the producer SHALL write the reviews it obtained and SHALL name each
vendor that failed, with the reason where known.

Silently discarding a completed review wastes the reviewer's work and hides
which opinions are missing.

#### Scenario: Two of three vendors fail

- **WHEN** three vendors are requested, one returns a review, and two time out
- **THEN** `REVIEWS.md` contains the one review, and the run's output names the
  two vendors that timed out

#### Scenario: The consumer inspects which opinions are absent

- **WHEN** a reader wants to know whether a change was seen by every vendor
- **THEN** the run's report distinguishes "did not review" from "reviewed and
  approved"
