## ADDED Requirements

### Requirement: One reviewer floor, stated once

The gate SHALL require at least one independent reviewer before allowing code
edits under an active change. This floor SHALL be stated once; the spec SHALL
NOT contain a second, different floor.

§18 currently mandates both: its truth table and prose say one reviewer, while
two later clauses say two. A section that mandates two floors is not
satisfiable, and "the tool is non-conformant" cannot be assessed against it.

#### Scenario: An active change carries one reviewer

- **WHEN** validation is green and `REVIEWS.md` carries one counted reviewer
- **THEN** the gate allows the edit

#### Scenario: An active change carries none

- **WHEN** validation is green and `REVIEWS.md` carries no counted reviewer
- **THEN** the gate blocks the edit

#### Scenario: The spec is read for the floor

- **WHEN** a reader or host implementer looks up the required reviewer count
- **THEN** every statement of it in the spec agrees

### Requirement: A reviewer counts only with a verdict

The gate SHALL count a reviewer section toward the floor only when that section
carries a verdict. A section without one SHALL NOT count.

The verdict format SHALL be: anchored at the start of a line, case-insensitive,
optional surrounding markdown emphasis, the label `VERDICT:` followed by one
value from a closed vocabulary. This matches the parser the gate already ships
in `pending_rejections()`, so no existing well-formed `REVIEWS.md` is
invalidated.

The gate's counting and reporting SHALL use the same predicate. They diverge
today: `reviewer_count()` matches headings while `pending_rejections()` parses
verdicts — the exact failure the gate's own source warns of, "the gate counts
one set of reviewers and reports on another".

#### Scenario: A section carries prose but no verdict

- **WHEN** a reviewer section contains commentary and no verdict line
- **THEN** it does not count toward the floor

#### Scenario: A verdict carries markdown emphasis

- **WHEN** a section's verdict is written `**VERDICT: REQUEST-CHANGES**`
- **THEN** it counts, as the shipped parser already accepts

#### Scenario: The verdict vocabulary is quoted mid-prose

- **WHEN** a reviewer writes the verdict vocabulary inside a sentence or a
  fenced block rather than as its own line
- **THEN** it does not register as a verdict

### Requirement: A rejection still counts as a review

A REQUEST-CHANGES verdict SHALL count toward the floor. The gate SHALL report
outstanding rejections without blocking on them.

An objection is a review. Discounting it would mean a change could be blocked
for lack of reviewers precisely because a reviewer engaged with it.

#### Scenario: The only reviewer requests changes

- **WHEN** one reviewer returns REQUEST-CHANGES and no other reviewer counts
- **THEN** the floor is met, the gate allows, and it reports the objection

### Requirement: Reviewers counted toward the floor are independent

The gate SHALL exclude the invoking host's own vendor from the count, and SHALL
count a repeated vendor once.

The invoking host's identity SHALL be supplied by the caller as an
authoritative input. A single host-agnostic binary cannot infer which host
invoked it, and a built-in default is correct on exactly one host.

When that identity is absent or invalid, the gate SHALL count no reviewers —
failing closed. Guessing would silently admit a self-review as the sole
independent opinion.

#### Scenario: The host's own review is present

- **WHEN** `REVIEWS.md` contains a section from the invoking host's vendor
- **THEN** it does not count toward the floor

#### Scenario: The host identity is not supplied

- **WHEN** the gate runs with no authoritative host identity
- **THEN** it counts no reviewers and blocks, rather than assuming a default

#### Scenario: A vendor appears twice

- **WHEN** the same vendor has two sections
- **THEN** it contributes at most one to the count

### Requirement: A review is bound to what it reviewed

`REVIEWS.md` SHALL record a digest of the change artifacts as they stood when
reviewed. The gate SHALL treat the review as stale, and not count it, when the
current artifacts no longer match.

Without this, amending a change after review silently retains evidence for text
nobody read. This is not hypothetical: during the session that wrote this
requirement, two open changes were substantially revised after being reviewed,
and both retained their prior `REVIEWS.md` with the gate unable to tell.

#### Scenario: A change is amended after review

- **WHEN** a proposal, design or spec delta is edited after `REVIEWS.md` was
  written
- **THEN** the recorded digest no longer matches, the review does not count,
  and the gate blocks until the change is reviewed again

#### Scenario: A change is unmodified since review

- **WHEN** the artifacts match the recorded digest
- **THEN** the review counts normally

#### Scenario: A review predates digest recording

- **WHEN** `REVIEWS.md` carries no digest because it was written by an earlier
  producer
- **THEN** the gate reports the review as unverifiable and does not count it,
  so old evidence cannot silently satisfy a new rule
