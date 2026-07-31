## Context

Two copies of the plan-review producer exist, and neither is a tracked source:

| Location | Lines | Version marker | Behaviour below floor | Tracked |
|---|---|---|---|---|
| `~/.agenticapps/bin/run-plan-review.sh` | 227 | `1.0.0` | refuses to write `REVIEWS.md` | no |
| `gate/run-plan-review.sh` (core) | 66 | none → `0.0.0` | warns, continues | no (`gate/` untracked) |

The installed copy is the real implementation: it carries the stdout sanitiser
(vendor banners and session-hook logs were landing in `REVIEWS.md` as review
prose), the `## Reviewer:` forge guard, and per-code reporting of reviewer-cli
1.1.0's 3/4/5 exit codes. The `gate/` copy predates all of that.

The producer's own header warns about exactly the situation it is now in:

> The producer sat in the same shared directory, installed by the same script,
> three lines below the gate's arbitration block — and was left blind. Nothing
> has broken yet only because no sibling host ships a producer to overwrite it
> with; that is luck, not design.

Something has now broken, in a different way: the floor drifted from the spec.

## Goals / Non-Goals

**Goals**

- Give the producer a tracked home so it can be reviewed, diffed and recovered.
- Make its default floor match §18.
- Stop discarding completed reviews **at the default floor**. Reviews are still
  discarded when an explicitly raised floor is missed (`MIN_REVIEWERS=2` with one
  good review writes nothing), because there is nowhere to put partial evidence
  that the gate would not read as satisfying the floor. The case that actually
  bit on 2026-07-29 is closed; the general case is not, and the goal says so
  rather than claiming both.

**Non-Goals**

- **Re-litigating the floor.** §18 lines 88–102 decided one reviewer, with
  reasoning. This change implements that decision.
- **Changing the sanitiser, forge guard, or exit-code reporting.** Carried
  across byte-for-byte; they are why 1.0.0 is the real implementation.
- **Classifying the rest of `gate/`.** Only `run-plan-review.sh` is resolved
  here. `gate/`'s other contents (`openspec-change-gate.sh`, `pre-commit`,
  `hooks/`, `README.md`) duplicate tracked reference-implementations and need
  their own keep/track/delete call.
- **Re-vendoring workflow content to the four hosts.** Per plan step 2, publish
  rather than re-vendor. This non-goal is about pushing content *out* to hosts.
  It does not cover the one edit this change makes in `claude-workflow` —
  repointing its installer away from a vendored producer copy and at core, which
  *removes* vendored content. A reviewer read the non-goal as unqualified and
  was right to: it was.
  This non-goal is load-bearing and was violated by the previous revision, which
  required every host's gate shim to export its own identity. Decision 5 now
  carries the identity in the artifact instead, so no host file changes. If a
  future revision reintroduces a per-host environment requirement, it has left
  this non-goal and must say so.

## Decisions

### Decision 1: Promote the installed 1.0.0, not core's `gate/` copy

**Chosen:** `reference-implementations/run-plan-review/run-plan-review.sh` is
seeded from the 227-line installed copy.

*Alternative — seed from `gate/run-plan-review.sh`, the in-repo copy.*
Superficially the tidier story: the repo copy becomes canonical. Rejected on
inspection — it is a 66-line ancestor missing every fix made since. Choosing it
would silently revert the sanitiser and the forge guard, reintroducing the bug
where vendor banners were recorded as review prose.

The lesson generalises: "the copy in the repo" and "the current implementation"
were not the same file, and only reading both revealed which was which.

### Decision 0: Fix §18 rather than conform to it

§18 currently mandates two different floors. Line 73's truth table and line 80
say one reviewer; lines 146 and 174 say two. Spec 1.1.0 changed the truth table
and wrote the rationale, and left the two prose clauses behind.

**Chosen:** correct lines 146 and 174 to one, matching the truth table.

*Alternative — conform the producer to the ≥2 clauses.* Rejected: it
contradicts the truth table the gate implements, and reverses a decision §18
argues for at length over fifteen lines.

*Alternative — treat this as out of scope and file it separately.* Rejected as
the more dangerous kind of tidiness. This change's entire premise is "the
producer disagrees with the spec"; leaving the spec self-contradictory means
the next reader cannot tell which half the producer was made to match. The
reviewer that caught it was right that the change must own the spec edit.

The gate binary already enforces ≥1, so no running enforcement changes. This
aligns the text with behaviour that has been live since **spec 1.1.0**, which
changed the truth table but updated only part of §18.

**Two version namespaces are in play throughout this document and are always
named.** `spec N.N.N` is this repo's `spec_version` (currently 1.2.0, in
`spec/00-overview.md:4`). Artifact versions are named with their artifact —
`gate 1.4.0`, `producer 1.0.0`, `reviewer-cli 1.1.0`. A bare version number is a
defect in the text: the floor is described in one place as live "since 1.1.0"
(spec) and in another as defaulted "since 1.4.0" (gate), and both are true of
different things. That ambiguity is the same class this change faults §18 for.

### Decision 2: Default the floor to 1, keep the override, reject below 1

**Chosen:** `MIN_REVIEWERS` defaults to 1; an explicit value of 1 or more wins;
0, negatives and non-integers are usage errors.

The existing guard rejects only empty and non-digit values, so `0` passes,
`[ 0 -lt 0 ]` is false, and the producer publishes and exits 0 — announcing a
floor it never evaluated. That is the same failure the comment directly above
that guard was written to prevent, reintroduced one value to the left.

*Alternative — default to 1 with no override.* Simpler surface. Rejected
because §18 distinguishes a floor from a preference: the floor is one, but a
caller may legitimately want more for a risky change. Removing the override
would make the stricter posture unreachable.

*Alternative — leave the default at 2 and document the override.* This is the
status quo, and it failed in practice on 2026-07-29: the operator did not know
the override was needed until a review was already lost. A default that
contradicts the spec is a trap, not a configuration.

### Decision 3: Report failures into the artifact, not just stderr

A run that met the floor SHALL succeed, and `REVIEWS.md` itself SHALL record
which vendors were requested, counted, excluded and failed. Previously a
shortfall against the *requested* count produced no artifact at all, which is
what discarded gemini's completed review.

*Alternative — report failures on stderr only,* as first proposed. Rejected on
review: the terminal is gone by the time anyone reads an archived `REVIEWS.md`,
so "two reviewers" cannot be distinguished from "two of five, three failed".
The artifact would systematically overstate the scrutiny a change received.

### Decision 4: A section counts only if it carries a verdict

Counting any non-empty, exit-zero output as a review is what let opencode's
"I'll fact-check this change before issuing a verdict" preamble count as one of
three reviewers on this very change. At a floor of one, such a section alone
would open the gate for a change nobody reviewed.

**Chosen:** a section counts only with a parseable verdict; output without one
is a failure with that reason. REQUEST-CHANGES counts — an objection is a
review, and the gate reports objections separately.

**A verdict alone is still not a review.** On 2026-07-29T07:52:54Z gemini
returned a bare `VERDICT: APPROVE` with no body at all, and it counted. The
verdict requirement as first written would count it again — necessary, not
sufficient. A counted section therefore also SHALL carry at least one content
line beyond its heading, timestamp, trailer and verdict.

*Trade-off:* a reviewer with genuinely nothing to add is discarded and must be
re-run. Accepted — at a floor of one, a bare token from a vendor that engaged
with nothing is indistinguishable from a vendor that read carefully and
approved, and the gate must not treat them alike.

**Rejected — block on an unresolved REQUEST-CHANGES.** Raised twice by codex:
that a rejection which opens the gate is a presence check, not a decision. §18
decides otherwise deliberately, and the gate's own source records why — blocking
on a verdict needs a re-review trigger, a staleness rule and an override path.
Two of those three now exist (Decisions 7 and 8), but the answer to codex is
narrower and does not need them: **once reviews are digest-bound, amending a
change in response to an objection stales the review and forces a re-review.**
The only way to proceed past an objection is to *not* amend — and that path is
reported by the gate on every invocation, by name. The operator stepping over a
recorded objection is a visible act, which is what §18 asks of it.

### Decision 5: Identity is recorded in the artifact, not read from the environment

*This decision was rewritten after round 3. The previous text said "determine
the running host and exclude it by rule" while the proposal said the caller
supplies it — two different normative rules for one behaviour, which opencode
correctly reported as unimplementable. Neither was right.*

The situation on disk, verified rather than assumed:

| Consumer | Identity source | Default | Effect of the default |
|---|---|---|---|
| `run-plan-review.sh:68` | `AGENT_SELF` | `claude` | wrong on three of four hosts |
| `openspec-change-gate.sh:150,183` | `OPENSPEC_GATE_SELF` | *empty* | **no self-exclusion at all** |

The producer's default is wrong; the gate's is absent. The handoff recorded only
the first. At a floor of one, the gate as shipped will count a host's review of
its own change as the sole independent opinion, on every host including this
one.

Both fixes were proposed as environment inputs, and codex's objection to that is
decisive: **the evaluator is frequently not the producer.** CI, a pre-commit
hook, or a different agent evaluates `REVIEWS.md` that some other host wrote.
An environment variable describes the process reading the file, which is not the
fact the rule needs. The fact needed is *who authored the change being
reviewed*, and that is knowable only at production time.

**Chosen:** the producer requires an explicit implementing-host identity, from a
closed vocabulary (`claude` | `codex` | `gemini` | `opencode` | `pi` — the union
of hosts and reviewer vendors), with **no
default**; absent or unrecognised, it exits with a usage error and writes
nothing. It records that identity in a trailer in `REVIEWS.md`. The gate reads
the identity **from the trailer** and excludes that vendor's sections; a
`REVIEWS.md` with no valid trailer is unverifiable and counts zero. Duplicate
vendors count once.

Three things fall out of this, all of them objections from round 3:

- **No host file changes.** The gate needs no per-host environment, so the
  "not touching the four hosts" non-goal holds — where the previous revision
  contradicted it by requiring seven shim edits.
- **No fail-closed flag day.** The previous design would have blocked every
  existing CI and pre-commit caller the moment the identity default was removed.
  Reading the trailer instead means an unmigrated caller behaves identically.
- **`OPENSPEC_GATE_SELF` is retired as an identity source**, rather than being
  given a better default. A second source of the same fact is how the producer
  and gate came to disagree in the first place.

*Alternative — infer the host from the runtime.* Rejected: one host-agnostic
shell script has no reliable signal, and a wrong inference fails silently open,
which is the failure being fixed.

*Alternative — keep the environment variable and fix its default.* Rejected: it
is unfixable by construction. There is no default that is correct on more than
one host, and the gate's correct answer depends on the host that ran the
producer, possibly weeks earlier on a different machine.

### Decision 6: Declare the egress boundary honestly; defer screening

*Also rewritten after round 3. The previous text claimed the prompt bounded the
egress. It does not, and saying so was the more dangerous error — a reader would
have concluded that keeping secrets out of the proposal kept them off the wire.*

The vendors are **agentic CLIs**, not completion endpoints. They run with the
operator's credentials and filesystem access and read whatever they judge
relevant: the repository, the working tree, and configuration under `$HOME`
including their own credential and tool-config files. The prompt is what the
producer *hands* them; it is not a boundary. The real boundary is "what that
vendor CLI can reach on this machine while running as this user."

Three claims are corrected rather than deferred:

- **What is sent** is named — proposal, design note and spec deltas — but named
  as a *floor*, not a bound.
- **Invocation is consent, scoped.** Naming a vendor consents to running that
  vendor. It does not narrow what that vendor may read, and it must not be
  written as though it did. The operator's consent act is vendor selection.
- **Reviewer output is untrusted third-party input.** It is written verbatim
  into `REVIEWS.md`, which agents later read as context. This is the same trust
  boundary §14 governs, and it belongs in the capability rather than in prose —
  the previous revision left it in the proposal and tasks only, where nothing
  enforces it.

**Chosen:** declare the boundary as above, state plainly that **no secret or PII
screening is performed**, recommend the operator check before invoking, and
require that change content never appear in the argv of any process **the
producer or the wrapper launches**. Screening is deferred to a named follow-up
change, `screen-review-egress`, owned by whoever implements this one.

That scoping is a correction, not a hedge. An earlier revision required that
change content "never appear in any process's argv" full stop, which is not a
property this change can deliver: the vendor CLIs are agentic and spawn their
own children, and what they put on those command lines is theirs to decide. The
requirement is enforceable exactly as far as the processes we start, and stating
it wider made it unverifiable — an unfalsifiable requirement in the security
section of a change about evidence integrity. A reviewer named this.

*Alternative — full screening now.* Rejected on scope: it turns a conformance
fix into a security feature and delays a floor repair that is losing reviews
today. Declaring the boundary is what makes the deferral auditable instead of
silent — the gap is now written down, and written down accurately.

### Decision 7: The digest covers exactly the bytes that were reviewed

All three reviewers rejected "a digest of the change artifacts" as
unimplementable, and they were right: no algorithm, no canonicalisation, no
artifact set. opencode found the trap in the obvious reading — if `tasks.md` is
in scope, ticking a checkbox during implementation stales the review and the
gate deadlocks; if it is out of scope, nothing said so.

The deadlock dissolves against a fact neither the proposal nor any reviewer
checked. `run-plan-review.sh:101-102` builds the prompt from **`proposal.md`,
`design.md` and `specs/*/spec.md`**. `tasks.md` is never sent. Reviewers have
never seen it.

**Chosen:** the digest covers exactly the artifacts the producer transmits.
Binding more than was reviewed would invalidate evidence over text nobody read;
binding less would let reviewed text change unnoticed.

The contract, stated so two implementations cannot disagree:

- **Set:** `proposal.md`, `design.md`, and every `specs/**/*.md`, paths
  relative to the change directory, sorted bytewise under `LC_ALL=C`. A file
  absent from disk is absent from the digest — so deleting a spec delta changes
  it, which is the required behaviour.

  Round 5 caught this stated **three different ways** across the change:
  `specs/**/spec.md` here and in the proposal, `specs/**/*.md` in the normative
  requirement, `specs/*/spec.md` in the producer. All three reviewers flagged
  it, and in a change whose thesis is that under-specification is the defect it
  is the worst possible place to have one. The set is `specs/**/*.md`
  everywhere, chosen because it is the glob `openspec status` already reports
  for the change's spec artifact — adopting the tool's definition rather than
  minting a fourth.
- **Canonicalisation:** CRLF → LF; a trailing LF appended if missing. Nothing
  else — no whitespace stripping, no Unicode normalisation. Every additional
  rule is another place two implementations diverge.
- **Framing:** per file, the byte length of the relative path in decimal, LF,
  the path bytes, LF, the canonical content length in decimal, LF, then the
  canonical bytes. **Both** path and content are length-prefixed.

  This bullet previously framed only the content, while the normative
  requirement framed both — so a producer built from this decision and a gate
  built from the requirement computed different digests for identical input.
  Two conformant implementations disagreeing, in the one mechanism this change
  specified to the byte precisely to prevent that. A reviewer caught it in
  round 7. The requirement's form is authoritative and is now restated here
  verbatim rather than paraphrased, because paraphrase is what drifted.
- **Enumeration:** the set is gathered and ordered **NUL-delimited**, never
  line-delimited. A path may legally contain a newline; a line-based pipeline
  splits `specs/x/a<LF>b.md` into two paths that do not exist, so the file
  silently leaves the set — or the digest is refused for a wrong reason.
  Framing the record boundaries is pointless if the boundary is already lost
  on the way in. This was a live defect in the first implementation, found by
  its own harness row.
- **Algorithm:** SHA-256, lowercase hex.
- **`REVIEWS.md` is excluded by construction**, being outside the set. It cannot
  be otherwise: it contains the digest.

Two limits are stated in the spec rather than left for a reader to discover:

- **`tasks.md` can change without invalidating a review.** That is a real hole
  and it is the price of not deadlocking. It is bounded by the fact that a task
  change which alters what the change *promises* must also appear in the
  proposal, design or spec delta — all bound. A task change that alters nothing
  promised is one nobody reviewed anyway.
- **A digest detects drift, not forgery.** It is computable by anyone holding
  the same public artifacts, so it cannot distinguish a real review from a
  fabricated one. The previous revision's framing — that hardening the producer
  alone was cosmetic because forged files open the gate — implied this mechanism
  answered forgery. It does not. Authenticity would need a signature and is not
  attempted here.

### Decision 8: The verdict grammar is specified against the shipped parser

"Parseable verdict" was not a contract. codex enumerated four bypasses in the
regex the gate actually ships at `openspec-change-gate.sh:205`; all four
reproduce:

```
cur != "" && /^[[:space:]]*[*_]*[[:space:]]*VERDICT[[:space:]]*:[[:space:]]*[*_]*[[:space:]]*REQUEST-CHANGES/
```

- **Not end-anchored** — `VERDICT: REQUEST-CHANGES-LATER` matches.
- **Not case-insensitive** — awk regexes are not; `verdict: request-changes`
  does not match, though the producer's own prompt does not require caps.
- **No section delimiter** — `cur` is set at a `## Reviewer:` heading and
  cleared at no other heading, so a verdict under an unrelated `##` section
  later in the file is attributed to the last reviewer named above it.
- **Conflicting verdicts are unresolved** — two verdict lines in one section
  have no defined meaning.

**Chosen:** specify the grammar, and specify resolution:

- A reviewer section runs from its `## Reviewer:` heading to the **next
  `## Reviewer:` heading**, or EOF. No other heading closes a section, at any
  level. This bound was widened twice, each time after it discarded a review
  that had been written: bounding at *any* level excluded a verdict below a
  vendor's `### Findings`, and bounding at level 1 or 2 excluded one below
  `## Summary` — the commonest shape an LLM returns, so the rule discarded
  verdicts routinely. Each wording was chosen to exclude producer-authored
  structure and caught vendor prose instead. The
  normative statement is in `specs/change-gate-enforcement/spec.md`; this line
  restates it and must not diverge from it.
- Fenced code blocks are skipped (the shipped parser already does this, and this
  is also what makes "quoted in a fenced block must not count" implementable —
  it is fence tracking, not regex cleverness).
- A verdict line matches, case-insensitively and **anchored at both ends**, the
  label `VERDICT`, a colon, and one value from the closed vocabulary
  **`APPROVE` | `REQUEST-CHANGES`**, with optional markdown emphasis around
  either. Nothing else on the line.
- Exactly one distinct verdict per section counts. **Two conflicting verdicts
  make the section malformed** — not counted, reported as such. Repeats of the
  same verdict are one.
- A verdict outside every reviewer section is ignored.

Widening the shipped regex would count things it counts today; narrowing it
could discount an existing well-formed review. Both directions are checked by
the migration against every `REVIEWS.md` in the repo.

### Decision 9: Publish in dependency order, or every change blocks

The previous revision's Migration Plan covered the producer alone. It ships
three binaries and a spec edit, and two of them are coupled: **gate 1.6.0
requires a trailer that only producer 1.2.0 writes.** Publishing the gate first
blocks every change in every project until each is re-reviewed.

**Chosen order:** spec §18 → producer 1.2.0 → re-review the in-flight changes →
announce the block (8b.7) → gate 1.6.0 → wrapper 1.2.0. The wrapper is last because it is independent: no
other artifact reads its output format.

The re-review wave is not a side effect to be discovered later. Every
`REVIEWS.md` in existence predates the trailer, so **every one of them becomes
unverifiable the moment gate 1.6.0 lands** — including the two on this branch,
which is exactly the behaviour task 9b.13 tests for. It is scheduled, not
tolerated.

### Decision 10: Specify the trailer the way the digest is specified

The round-4 reviews agreed on one finding above the others, and it is the
uncomfortable kind: **this change specified the digest to the byte, argued at
length that "parseable" without a grammar is what produced four parser defects,
and then introduced the trailer as "a trailer the gate can parse."** Producer
1.1.0 writes it; gate 1.5.0 reads it. Two implementations, no shared format —
the same shape as the defect, in the mechanism built to fix it.

Worse, two rules already depended on the missing grammar. The substance rule
excludes "its generation timestamp" and "its trailer" from counting as body,
and neither exclusion is implementable without a way to recognise those lines.

**Chosen:** an HTML comment block, single, file-final, with named lowercase
fields — specified in the capability alongside the digest. HTML comment because
it does not render, cannot be mistaken for reviewer prose, and gives the
substance rule an unambiguous span to exclude. Unknown fields are ignored so a
later producer can extend it; missing required fields fail closed.

Two further findings from the same round are folded into the digest contract
rather than given their own decisions, because both are corrections to it:

- **The digest and the prompt must come from one snapshot.** Nothing required
  the bytes hashed to be the bytes sent, or either to be the bytes on disk at
  publication. Three reads of a mutable tree, each conformant, can disagree.
- **Length-frame the path, not only the content.** A path may contain a newline,
  and framing only the content leaves the record boundary forgeable — the same
  reasoning that put a length prefix on the content in the first place, applied
  one field short.

The general lesson is narrow and worth keeping: a change that fixes an
under-specification is the most likely place to introduce another, because the
new mechanism is the part nobody has had to implement twice yet.

## Risks / Trade-offs

- **A lower default floor is a weaker signal.** One reviewer catches less than
  three. §18 accepts this explicitly and argues the alternative — zero
  reviewers whenever a vendor is slow — is worse. This change does not add
  risk; it stops the producer enforcing a stricter rule than the spec while
  reporting itself as conformant.
- **Promoting the installed copy imports whatever is in it**, including any
  undiscovered defect, into the tracked source. Mitigated by the fact that it
  is already the code every review on this machine has run through; tracking it
  makes those defects reviewable rather than invisible.
- **`gate/` remains partly unclassified** after this change, so core still
  carries untracked material that looks authoritative. Narrowing the scope here
  is deliberate — classifying the rest requires per-file judgement that would
  swamp a conformance fix.
- **Every existing `REVIEWS.md` becomes unverifiable** when gate 1.5.0 lands.
  This is a one-time re-review wave across every project with an open change,
  not just this repo. Decision 9 sequences it; it cannot be avoided without
  grandfathering, and grandfathering would mean the new rule never applies to
  the evidence that motivated it.
- **Requiring substance discards a terse approval.** A vendor that approves in
  one line must be re-run. Cheaper than the alternative it replaces, which was
  counting a content-free token as an independent opinion.
- **The identity trailer is self-reported.** A producer run can name any host,
  and a hand-written `REVIEWS.md` can name a host that never ran. This narrows
  accidental self-review, which is the observed failure; it does not resist a
  deliberate one. Stated here so the requirement is not read as an authenticity
  control.
- **`implementing-host` accepts the UNION of hosts and reviewer vendors, so it
  accepts `gemini`, which is not a host.** A reviewer asked for two separate
  vocabularies. Declined, with the cost named: the union exists so `pi` — a host
  with no reviewer arm — can be declared, and validating the host against the
  *reviewer* set is precisely the defect that made pi-authored changes
  permanently unreviewable. Two vocabularies would be more precise and would
  need to stay in sync across the spec, the producer, the gate and at least one
  host skill, which is the coupling this change is already faulted for.
  What the imprecision buys an adversary is nothing: declaring `gemini` as the
  implementing host *excludes* a gemini review, which lowers the counted total.
  It cannot manufacture a reviewer, only discard one — a footgun for an honest
  operator, not a bypass. It is recorded here rather than closed, and the
  single-source vocabulary is the follow-up that would close it properly.
- **A raised `MIN_REVIEWERS` is neither persisted nor enforced by the gate.**
  `MIN_REVIEWERS=2` is a property of one producer run. If that run falls short
  it writes nothing, so an *earlier* one-reviewer `REVIEWS.md` survives and the
  gate — whose floor is one — accepts it. The operator who asked for two can be
  left believing they got two. Accepted, because the floor is a §18 decision and
  a gate that inferred a stricter floor from an artifact would let any producer
  invocation silently raise the bar for every later reader. The honest fix is to
  record the requested floor in the trailer and have the gate report a shortfall
  the way it now reports tasks drift; that is a §18 change, not a gate change,
  and it is not in this one. A reviewer identified this.

## Migration Plan

Ordered per Decision 9. The load-bearing coupling is **step 4 before step 8** —
gate 1.6.0 requires a trailer that only producer 1.2.0 writes, so publishing the
gate first blocks every change in every project until each is re-reviewed.
Steps 3 and 4 are merely sequential (seed the reference implementation, then
modify and publish it); reversing those two blocks nothing.

**Spec first**

1. Correct §18 lines 146 and 174 to the one-reviewer floor; add the verdict,
   substance, identity and digest terms; bump the spec version and record it in
   `CHANGELOG.md`.
2. Correct every other site that states a `≥2` floor, enumerated in `tasks.md`
   §1.7 rather than left to a grep: `spec/17`, `spec/02`, both
   `openspec-gate.ci.yml` copies, the change-gate README, the reviewer-cli
   README and script comments, and the producer's own header.

**Producer — must precede the gate**

3. Add `reference-implementations/run-plan-review/`, seeded byte-identically
   from the installed 1.0.0, with README and install contract.
4. Apply the floor, reporting, identity and digest changes; bump to 1.1.0; add
   the `resolve-core-artifact.sh` mapping; point the Claude installer at core
   rather than its vendored copy; publish to `~/.agenticapps/bin/`.
5. Verify against the recorded failure: one vendor returning and two timing out
   must now produce a written `REVIEWS.md` carrying a trailer.

**Re-review — before the gate, not after**

6. **Inventory every active change across the whole fleet**, not just this
   branch. The previous revision re-reviewed this repo's two changes and left
   every other project to discover the incompatibility when the global gate
   landed and blocked it — which is a flag day announced by an outage. The gate
   is shared; the migration has to be too.

   **Then resolve each one — by re-review OR by recorded acceptance.** This step
   originally said "re-review each", and the inventory made that unsatisfiable:
   37 active changes across six repositories, three of them outside this
   family, where a change in this repo has no authority to edit. **Taken
   2026-07-31: all 37 are accepted as blocked**, recorded in `tasks.md` 8b.4
   with the reasoning. That is a resolution of this step, not an evasion of it —
   what the step exists to prevent is the fleet being *surprised*, and the
   inventory plus the acceptance record plus step 6b is what prevents it.

6b. **Announce the block before the gate ships** (task 8b.7). Acceptance moved
   this precondition; it did not remove it. Six repositories will each hit a
   hard `PreToolUse` block at their next code edit, and nobody has been told.
   Publishing with this open reschedules the 2026-07-30 outage rather than
   avoiding it — the failure this whole ordering exists to prevent, arrived at
   by a different route.
7. Re-run the producer over both open changes on this branch.

**Gate**

8. Publish gate 1.6.0: verdict-and-substance counting, trailer-sourced identity,
   digest staleness, reviewer-heading-only section bounds, and the advisory
   tasks-drift report. ONLY after task 8b.7 has announced the block — 8b.4
   accepted 37 changes across six repos as blocked rather than clearing them,
   so publication now surprises six repositories unless the notice precedes it. Run `tools/change-gate-conformance.sh` green — every case
   passing, none inconclusive, which is what the harness's own `TOTAL:` line
   reports. (A previous revision cited a "52-case harness"; the harness states
   no case count anywhere, so the number was unverifiable and is dropped rather
   than guessed.)
9. Confirm the re-reviewed changes read as current, and that **the
   verdict-and-substance predicate alone** discounts no section that was
   well-formed before. Note the qualifier: the previous revision said "confirm
   every `REVIEWS.md` carrying a well-formed verdict still counts", which the
   trailer rule makes impossible — every pre-1.1.0 file counts zero by design,
   as the Impact section says. The two clauses contradicted each other; the
   predicate check is the one that can actually run.

**Wrapper — independent, last**

10. Publish reviewer-cli 1.2.0 with the prompt out of argv on all four arms.

**Rollback**, per artifact, in reverse dependency order:

| Artifact | Rollback | Consequence |
|---|---|---|
| reviewer-cli 1.2.0 | republish 1.1.0 | prompts return to the process table |
| gate 1.6.0 | republish 1.4.0 | trailers ignored; pre-trailer evidence counts again |
| producer 1.2.0 | republish 1.0.0 from the reference implementation's history | floor returns to 2; trailers stop being written |
| shared-install 1.0.1 | republish 1.0.0 | `--allow-downgrade` glob-expands again — **and this row must roll back LAST**, because it is the tool every other row runs |
| §18 | revert the commit | the section is self-contradictory again |

The shared-install row was missing until a reviewer asked for it, and its
absence was not cosmetic: it is the only artifact whose rollback is
self-referential. Downgrading the arbiter first would leave the remaining rows
to be executed by the version being rolled back, so it goes last in a table
that otherwise runs in reverse dependency order. Rolling gate 1.6.0 back to
1.4.0 rather than 1.5.0 is deliberate — 1.5.0 was published once, blocked six
repositories, and is not a state to return to.

Rolling back the producer while gate 1.5.0 is live blocks every change — the
same coupling as the forward order, and the reason the table is ordered.

**Every row of that table is currently unexecutable, and a reviewer caught it.**
`install-shared-artifact.sh:148` refuses to overwrite a copy whose version
marker is higher than the one being installed — the arbiter that exists to stop
an older host installer clobbering a newer shared artifact. Rollback is exactly
that operation performed deliberately, and the installer cannot tell the two
apart.

So rollback needs an explicit downgrade path: an opt-in flag that overrides the
arbiter, logging what it replaced and with what. Without it "rollback: republish
the previous version" is a plan that fails at the first command. The flag is
part of this change rather than a follow-up, because a migration whose rollback
does not run is not a migration with a rollback.

## Open Questions

- Should the producer refuse to run when *every* requested vendor is the
  implementing host's own? Out of scope here; reviewer-cli ships all vendor arms
  deliberately, and exclusion is the producer's job. With identity now required
  rather than defaulted, this case at least fails loudly instead of silently.
- **`screen-review-egress`** — secret and PII screening before change content
  reaches a vendor CLI. Named and deferred by Decision 6, owned by whoever
  implements this change. Not an open question about *whether*, only about when.
