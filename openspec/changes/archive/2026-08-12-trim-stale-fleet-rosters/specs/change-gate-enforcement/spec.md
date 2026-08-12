## MODIFIED Requirements

### Requirement: No published copy of the gate contradicts this capability

This repository SHALL NOT ship a copy of the gate that enforces a review
threshold, or that provides an escape hatch from one. A copy that no installer,
tool, or hook resolves SHALL be removed rather than brought into line.

`gate/openspec-change-gate.sh` is such a copy. It defaults `MIN_REVIEWERS=2`,
returns a blocking exit when reviewers are insufficient, treats
`GSD_SKIP_REVIEWS=1` as a live bypass of that live block, and reports *"BLOCKED —
no code edits until validate is GREEN and every active change has >= N
reviewers"*. `gate/README.md` documents this as contract. It has been superseded
since 2.0.0 and nothing points at it: `install.sh` publishes the reference
implementation into `~/.agenticapps/bin/` through `install-shared-artifact.sh`,
and that directory holds a byte-identical copy of the implementation.

*The clause naming the resolver was corrected on 2026-08-12. It read
"`resolve-core-artifact.sh` maps the shared install to the reference
implementation", which was never true of **core's** installer — core has always
published directly. `resolve-core-artifact.sh` served a **host** repository's
installer, letting it publish core's artifacts from a pinned commit instead of
vendoring their bytes, which is why it read as part of the publish story. All
four host repositories were deleted on 2026-08-12, leaving it with no caller, and
it was retired in the same change. The scenario below requires the resolver
mapping be read and named rather than assumed; reading it is what found this
sentence naming the wrong one. What the sentence supports does not move — nothing
resolved `gate/openspec-change-gate.sh` before the correction either.*

#### Scenario: A published copy enforces a withdrawn threshold

- **WHEN** a shipped copy of the gate blocks on reviewer count
- **THEN** it SHALL be removed, and its removal SHALL record which installer or
  hook resolved it, or that none did

#### Scenario: A reader consults a published copy for the gate's contract

- **WHEN** a reader opens a published gate or its README to learn what blocks
- **THEN** what they find SHALL agree with the reference implementation, or SHALL
  not exist

#### Scenario: The resolution path is asserted rather than assumed

- **WHEN** a published copy is removed on the grounds that nothing resolves it
- **THEN** the resolver mapping SHALL be read and named, and the installed
  artifact compared against the implementation it claims to publish
