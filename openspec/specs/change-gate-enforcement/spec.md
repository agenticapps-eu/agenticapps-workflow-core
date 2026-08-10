# change-gate-enforcement Specification

## Purpose
Defines what the §18 change gate enforces and what it merely reports: it
blocks only on `openspec validate --all` not being green, while the reviewer
count, the verdict grammar, reviewer independence, the trailer format and the
binding of a review to what it reviewed are computed and reported, never
enforced.
## Requirements
### Requirement: Reviews are reported, never enforced

The gate SHALL NOT block a code edit on the state of `REVIEWS.md`. It SHALL
report that state — absent, short of the preferred count, unverifiable, stale,
or carrying REQUEST-CHANGES — on every invocation where it applies.

The gate SHALL block on exactly one condition: `openspec validate --all` is not
green (or the `openspec` CLI is unavailable, so the question cannot be
answered). The reviewer count remains defined, computed and reported, because a
report that miscounts is as wrong as a block that miscounts. What is removed is
the consequence, not the arithmetic.

**Why the enforcement was withdrawn.** The distinction that matters is between
an ERROR and an ABSENCE. A malformed spec delta is wrong on its own terms —
local, instant, deterministic, and knowable without asking anyone. A missing
review is a missing OPINION: the change is not more broken for the absence of
it, and the person best placed to judge whether that matters is the one being
interrupted.

Measured on this repository, blocking cost three rollbacks, a six-repository
outage on 2026-07-30, and a migration whose stated precondition was announcing
that outage in advance. What it prevented is not identifiable. Because the
reviewers are third-party CLIs that are variously slow, rate-limited, and prone
to returning nothing, the floor went unmet routinely for reasons bearing no
relationship to the quality of the change under review — so the block landed
almost exclusively on the wrong cases.

A plan review is worth running, and the gate says so every time it notices one
is missing. Saying so is the whole of the mechanism.

#### Scenario: An active change carries no review

- **WHEN** validation is green and `REVIEWS.md` carries no counted reviewer
- **THEN** the gate ALLOWS the edit and reports that no plan review has been run

#### Scenario: An active change carries a stale review

- **WHEN** the reviewed artifacts have changed since `REVIEWS.md` was written
- **THEN** the gate allows the edit and reports that the review no longer
  describes the current text — distinguishably from having no review at all

#### Scenario: Validation is not green

- **WHEN** `openspec validate --all` fails, whatever the review state
- **THEN** the gate blocks the edit

#### Scenario: The spec is read for the reviewer count

- **WHEN** a reader or host implementer looks up the reviewer count
- **THEN** every statement of it in the spec agrees, and every one describes a
  reported threshold rather than an enforced one

### Requirement: A reviewer counts only with a verdict and a body

The gate SHALL count a reviewer section toward the floor only when that section
carries exactly one verdict **and** at least one line of substance.

**Section boundaries.** A reviewer section runs from its `## Reviewer:` heading
to the **next `## Reviewer:` heading**, or to end of file. **No other heading
closes a section**, at any level. Content outside every reviewer section SHALL
NOT be attributed to any reviewer.

This bound has now been widened twice, each time after it discarded a review
that had actually been written. "Any heading" truncated a section at the first
`### Findings` a vendor wrote. "Level 1 or 2" truncated it at the first
`## Summary` — which is the commonest shape an LLM returns, so the rule
discarded verdicts routinely: the producer published two reviewer sections and
reported success while the gate counted zero. Each wording was chosen to
exclude producer-authored structure and each caught vendor prose instead.

**What this trades away, stated plainly.** Under the previous rule, content
following the last reviewer section was attributed to nobody. Under this one it
is interior to that reviewer. That is safe only because the placement rule below
is normative: the notice and the record precede the first section, and the
trailer is parsed before headings are considered, so in a producer-written file
there is nothing after the last section to misattribute. A hand-assembled
`REVIEWS.md` that appends prose after the last section will have it read as that
reviewer's body. The exchange is deliberate: a hypothetical misattribution in a
file the producer did not write, against a verdict-discarding failure that was
observed in production. Placement is what makes it sound, which is why it is
normative rather than conventional.

Vendor interiors are carried verbatim by design, and reviewers are told the
vocabulary, not the formatting, so headings inside a review are expected rather
than exceptional. At a floor of one, dropping such a section silently discards
the only review a change received.

**Timestamp line.** The producer writes exactly one line immediately after each
`## Reviewer:` heading, of the form `_generated <timestamp> · timeout <N>s_`.
It is not content for the substance rule. This grammar is stated because the
substance rule excludes the line, and an exclusion whose target has no
definition cannot be implemented — the same gap that made the trailer's format
necessary, one field over.

"ISO-8601" is not a grammar: it admits `2026-07-29T12:04:50Z`,
`2026-07-29T12:04:50.123+00:00` and `20260729T120450Z` alike. **One form is
required** — `YYYY-MM-DDThh:mm:ssZ`, matching
`[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z`: UTC, literal `Z`
suffix, no fractional seconds, no offset notation. `<N>` is one or more decimal
digits. This is the form the producer already emits, so no existing evidence is
invalidated by pinning it.

The separator is U+00B7 MIDDLE DOT, and the line is matched **bytewise under
`LC_ALL=C`** — as its UTF-8 encoding `0xC2 0xB7`, not as a character class. A
parser SHALL NOT depend on locale-aware regex to recognise it. The digest
contract already mandates C-locale byte semantics; a multi-byte character
matched under a character-class regex in that locale is a portability trap, and
recognising this line is load-bearing for the substance rule.

**Fences bound everything, and this is normative, not incidental.** A line
beginning (after optional leading whitespace) with ``` or `~~~` toggles fenced
state. While fenced state is on, a line SHALL NOT be recognised as a verdict, as
a `## Reviewer:` heading, as any other heading, as substance, or as a trailer
delimiter. Every construct in this section is defined *outside* fences.

This is stated because the alternative was to leave it to each implementation,
and four separate rules already depend on it. A vendor quoting this grammar back
inside a fenced block is the normal case, not an adversarial one — it is what a
reviewer does when asked to comment on the grammar itself — and an implementation
that read those quotations as live structure would let one review rename another
reviewer, forge a verdict, or present a second trailer. A reviewer objected that
deferring the fence grammar made these behaviours non-portable, which was
correct; deferring it is what this paragraph stops.

**Balance is defined, because a rule that refuses "unbalanced" fences without
defining balance is not implementable.** A body is balanced when the number of
fence-toggling lines in it is **even**. Marker type, marker length, and
indentation are deliberately NOT part of the test: they are not part of the
toggle either, so making them part of balance would mean two different fence
models in one document. ` ``` ` closes ` ~~~ `, and a four-backtick line closes
a three-backtick one. That is coarser than CommonMark, and it is the correct
trade here — the parser's only question is whether structure is live on a given
line, and one rule answers it everywhere.

The producer SHALL refuse a review body that is not balanced, recording the
reviewer as failed. The gate needs no equivalent rule: it never sees an
unbalanced body, because the producer will not publish one. A fence left open at
end of input is therefore a producer-side error, not a gate-side reading.

**Verdict grammar.** Outside fenced code blocks, a candidate line SHALL be
normalised and then matched, and both steps are normative:

1. **Normalise** — remove every `*` and `_` character from the line, then trim
   leading and trailing whitespace and collapse internal whitespace runs to one
   space.
2. **Match** — case-insensitively, and anchored at both ends of the normalised
   line: the label `VERDICT`, an optional space, a colon, an optional space, and
   exactly one value from the closed vocabulary **`APPROVE`** or
   **`REQUEST-CHANGES`**. Nothing else.

Normalising emphasis away, rather than permitting it in named positions, is what
makes the rule decidable. "Optional emphasis around the label or the value" —
the previous wording — does not say whether `**VERDICT: REQUEST-CHANGES**`,
`VERDICT: REQUEST-CHANGES**` or `VERDICT:** REQUEST-CHANGES` match, and a
reviewer showed that two conformant parsers would answer differently now that
end-anchoring is mandatory. Under the rule above all three match, and no parser
has to enumerate placements. No vocabulary member contains `*` or `_`, so the
normalisation cannot merge distinct values.

**It can, however, manufacture one, and that is accepted deliberately.** The
converse of "cannot merge" is not "cannot create": `VERDICT: REQUEST-_CHANGES`
and `V*E*R*D*I*C*T: APPROVE` both normalise to valid verdicts. This is judged
harmless and is stated rather than left for an implementer to discover. The
input is a vendor's own summary line, not an adversary's; a vendor that writes
`REQUEST-_CHANGES` meant `REQUEST-CHANGES`, and reading it as such is the right
answer. The alternative — restricting stripping to balanced emphasis runs —
reintroduces exactly the placement enumeration this rule removed, to defend
against a typo whose only effect is to be understood correctly. A section still
needs substance to count, so a manufactured verdict alone changes nothing.

The vocabulary is closed: a value outside it is not a verdict. Anchoring at the
end of the normalised line is required so that a value with a suffix —
`REQUEST-CHANGES-LATER` — does not match a bare vocabulary member.

**Conflict.** Exactly one *distinct* verdict value may appear in a section —
repetitions of the same value are one verdict, not a conflict. Two verdict lines
carrying **different** values make the section
malformed: it SHALL NOT count, and SHALL be reported as malformed rather than
silently resolved. Repetitions of the same value count once.

**Producer-authored blocks are placed, not floated.** `REVIEWS.md` carries
three producer-authored regions besides the reviewer sections: the
third-party-input notice, the coverage record (requested / counted / excluded /
failed), and the trailer. The notice and the record SHALL precede the **first**
`## Reviewer:` heading; the trailer SHALL be the file's final content.

Placement is normative because the section rule runs a section to the next
`## Reviewer:` heading **or EOF**, and none of these blocks is one. It carries
more weight under that rule than it did before: when any level-1/2 heading
closed a section, the record's own `# Review record` heading would have bounded
a trailing section by accident. Nothing bounds it now except placement. Placed
after the last reviewer section they would be *interior to it* — and the
substance rule would then count producer-authored lines as that reviewer's
body, so a bare `VERDICT: APPROVE` followed by a notice would acquire
substance and count. That is the 2026-07-29T07:52:54Z hole reopened through
the back door, by the very machinery built to close it. A reviewer identified
this in round 7.

**Substance.** A section SHALL additionally carry at least one non-blank line
that is not its heading, its generation timestamp, its trailer, a verdict
line, or any producer-authored block named above. The exclusion is by
construction as well as by rule: with the notice and record before the first
section, no section can contain them.

**Structural lines are not substance.** A line counts as a body only if, after
emphasis is stripped and whitespace collapsed, it **contains at least one
alphanumeric character** and is not a heading, a fence marker, an HTML comment,
the generation timestamp, or a verdict line. A reviewer that writes `### Findings`
above a bare verdict has still not written a review, and a section consisting
only of structure fails the rule exactly as a bare verdict does.

The rule is stated as a positive test because the previous wording — "carries
prose or data", plus a list of excluded constructs — was not implementable. The
list named headings, fences, comments and blanks; a thematic break (`---`) and a
bare blockquote marker (`>`) are in none of those categories, counted as
substance, and turned `VERDICT: APPROVE` followed by `---` into a review that
passed. Any enumeration of Markdown structure has the same problem, because the
next construct is always missing from it. Requiring one alphanumeric character
has nothing to keep in sync: no reviewer writes a finding without a letter or a
digit, and no arrangement of punctuation is one. A reviewer identified that
"carries prose or data" had no grammar; this is the grammar. A verdict with no body is not a review: on 2026-07-29T07:52:54Z a vendor
returned a bare `VERDICT: APPROVE` with no body and it counted toward the floor.

**One predicate.** The gate's counting and its reporting SHALL use the same
predicate. They diverge today — `reviewer_count()` matches headings while
`pending_rejections()` parses verdicts — which is the exact failure the gate's
own source warns of: "the gate counts one set of reviewers and reports on
another."

#### Scenario: A section carries prose but no verdict

- **WHEN** a reviewer section contains commentary and no verdict line
- **THEN** it does not count toward the floor

#### Scenario: A section carries a verdict but no body

- **WHEN** a reviewer section contains a verdict line and no other content
- **THEN** it does not count toward the floor, and is reported as carrying no
  substance rather than as absent

#### Scenario: A verdict carries markdown emphasis

- **WHEN** a section's verdict is written `**VERDICT: REQUEST-CHANGES**`,
  `VERDICT: **REQUEST-CHANGES**`, `VERDICT:** REQUEST-CHANGES` or
  `**VERDICT:** REQUEST-CHANGES`
- **THEN** each counts, because emphasis is normalised away before matching
  rather than permitted in enumerated positions

#### Scenario: A verdict value carries a suffix

- **WHEN** a section's verdict line reads `VERDICT: REQUEST-CHANGES-LATER`
- **THEN** it is not a verdict, because the value is outside the closed
  vocabulary and the match is anchored at the end of the line

#### Scenario: A verdict is written in lower case

- **WHEN** a section's verdict line reads `verdict: approve`
- **THEN** it counts, because the match is case-insensitive

#### Scenario: A section carries two different verdicts

- **WHEN** a reviewer section contains both an APPROVE and a REQUEST-CHANGES
  verdict line
- **THEN** the section is malformed, does not count, and is reported as such

#### Scenario: A verdict appears under a later non-reviewer heading

- **WHEN** a verdict line appears under a heading that is not a `## Reviewer:`
  heading, below a reviewer section
- **THEN** it IS attributed to that reviewer, because no heading but
  `## Reviewer:` closes a section

This scenario previously asserted the opposite, and the opposite is what
discarded real reviews: a vendor writing `## Summary` above its verdict had the
verdict land outside every section. The rule it protected — that producer text
after the last section is not attributed to a reviewer — is now carried by
placement instead, which is normative for exactly this reason.

#### Scenario: A reviewer heading appears inside a fenced block

- **WHEN** a `## Reviewer:` line appears inside a fenced code block, as it does
  whenever a vendor quotes this grammar back
- **THEN** it does not open a section, is not counted as a reviewer, and does
  not close the section that encloses it

#### Scenario: A trailer delimiter appears inside a fenced block

- **WHEN** a review quotes the trailer grammar inside a fenced code block, and a
  real trailer also appears at end of file
- **THEN** the file carries exactly ONE trailer — the real one — and the quoted
  block is ordinary section content; the fields read are the real trailer's, not
  the quoted ones

#### Scenario: A review body leaves a fence open

- **WHEN** a vendor returns a body whose fence markers do not balance, as a
  token-capped or timed-out CLI does
- **THEN** the producer refuses that body and records the reviewer as failed,
  rather than publishing a section that would swallow every later section and
  the trailer

#### Scenario: The verdict vocabulary is quoted mid-prose

- **WHEN** a reviewer writes the verdict vocabulary inside a sentence or a
  fenced block rather than as its own line
- **THEN** it does not register as a verdict

### Requirement: A rejection still counts as a review

A REQUEST-CHANGES verdict SHALL count toward the floor. The gate SHALL report
outstanding rejections without blocking on them.

An objection is a review. Discounting it would mean a change could be blocked
for lack of reviewers precisely because a reviewer engaged with it.

**Stated plainly: the reviewer count is a presence gate, not an approval gate.**
No verdict value is required to proceed. A change may be implemented over an
unresolved REQUEST-CHANGES, and nothing in this capability prevents it. A
reviewer asked three times for this to be said outright rather than left to be
inferred from the truth table, and the request is correct — a rule that reads
like approval enforcement but is not will be relied on as though it were.

One thing bounds it: the gate SHALL name each objecting reviewer in its report,
on every invocation, for as long as the objection stands — so proceeding is a
**repeated and unmissable** act rather than a silent one.

An earlier revision claimed a second bound — that amending a change in response
to an objection invalidates the digest and *forces* a re-review, "so the only
route past an objection is to leave the change unamended." **That is withdrawn.**
It was true only while a stale review blocked. Since reviews stopped blocking,
invalidating the digest changes what the gate SAYS and not what it permits: the
author may amend and carry on, and the report merely changes from "objection
outstanding" to "reviewed, but the artifacts have since changed." Both are
nags. Leaving the sentence in would have described a barrier that no longer
exists, in the requirement whose entire subject is that the barrier is gone.

**It is not an audit trail, and an earlier revision called it one.** The report
goes to stderr. It has no durable sink, records no operator identity, carries no
timestamp, and requires no acknowledgement; the console it printed to is gone by
the time anyone asks who proceeded and why. What it actually provides is
narrower and still worth having: an objection cannot be dismissed once and
forgotten, because it reappears on every subsequent invocation until the change
is amended or re-reviewed. That is a *nag*, not a record.

A real audit trail here would need the same shape as the downgrade log —
appended, timestamped, attributed to a user — and would belong with it rather
than on stderr. It is not built here. A reviewer twice identified the claim as
overstated; rather than defend it, the claim is withdrawn and the residual
protection is described as what it is. No separate acknowledgement artifact is
required because none is specified, not because the report substitutes for one.

Promoting a verdict to blocking is a §18 decision, not a gate decision, and is
not made here.

#### Scenario: The only reviewer requests changes

- **WHEN** one reviewer returns REQUEST-CHANGES and no other reviewer counts
- **THEN** the floor is met, the gate allows, and it reports the objection

#### Scenario: The change is amended to address an objection

- **WHEN** a reviewer returns REQUEST-CHANGES and the author edits a reviewed
  artifact in response
- **THEN** the digest no longer matches, the review no longer counts, and the
  gate reports the change as amended since review — it does not block, so the
  bound above is a re-review PROMPT, not a barrier

### Requirement: Reviewers counted toward the floor are independent

The gate SHALL exclude the **implementing host's** own vendor from the count,
and SHALL count a repeated vendor once.

The implementing host is the host that authored the change under review. It is
**not** the host running the gate: CI, a pre-commit hook, or a different agent
routinely evaluates evidence some other host produced. An identity read from the
evaluating process's environment therefore describes the wrong party.

The gate SHALL read the implementing host's identity from `REVIEWS.md` itself,
recorded there by the producer at the time the reviews were obtained. Each
identity SHALL be one of `claude`, `codex`, `gemini`, `opencode`, `pi` — the
union of hosts and reviewer vendors. `pi` is a host with no reviewer arm and
MUST be accepted, or every pi-authored change reads as malformed and counts
zero reviewers forever.

**The reviewer heading name SHALL be constrained to the vendors that can
actually produce a review** — `claude`, `codex`, `gemini`, `opencode`. This is
the narrower set: a `## Reviewer: pi` section cannot exist, because there is no
pi reviewer arm to write one. A
`## Reviewer:` heading naming anything else — `codex-2`, `gpt`, `anonymous` —
SHALL NOT count, and SHALL be reported as an unrecognised reviewer rather than
ignored. Without this the exclusion rule is defeated by spelling: the
implementing host is excluded by name, so a section headed `codex-2` on a
`codex`-authored change counts as an independent reviewer while being the
implementing host's own output. The heading name and the identity value are
compared **case-sensitively after trimming surrounding whitespace**, both being
lowercase vocabulary members.

This also bounds what the producer may write. The producer names sections from
its own vendor list, which is the same vocabulary, so no legitimate section is
lost; a name outside it means the file was edited by something other than the
producer, which is exactly the case that should not silently count.

**More than one host may be named**, and every named host SHALL be excluded. A
change may be authored across a handoff or by several agents, and a single
identity would then mark a genuine co-author as independent. Naming all of them
costs nothing and removes that case.

It does not remove the general one. The identity describes **agent** authorship
only: a human editing the change directly is invisible to it, and the value is
self-reported by whoever ran the producer. This narrows accidental self-review,
which is the observed failure. It is not an authorship record and SHALL NOT be
presented as one.

**Independence here means a different CLI, not a different model.** The
vocabulary names vendor CLIs, and a CLI is not a model: `opencode` can be
configured to route to the same provider and model as the implementing host, in
which case two counted "independent" reviewers are one model answering twice.
The capability SHALL make that claim in its weaker, true form. Recording
provider and model identity would strengthen it and is not attempted here — the
CLIs do not report it uniformly — so the limitation is documented rather than
closed.

When a vendor is named as an implementing host **and** returns a review, that
section SHALL be reported as excluded rather than silently dropped, so the
exclusion is visible in the artifact that claims independence.

When `REVIEWS.md` records no identity, or records one outside the vocabulary,
the gate SHALL count no reviewers — failing closed. Guessing would silently
admit a self-review as the sole independent opinion, and there is no default
that is correct on more than one host.

The gate SHALL NOT take this identity from an environment variable. Two sources
for one fact is how the producer and the gate came to hold different answers:
the producer defaults it to `claude`, correct on one host of four, while the
gate defaults it to empty, applying no self-exclusion at all.

This binds accidental self-review, which is the observed failure. It does not
resist a deliberate one: the identity is self-reported by the producer and a
hand-written `REVIEWS.md` may name any host.

#### Scenario: The implementing host's own review is present

- **WHEN** `REVIEWS.md` records an implementing host and contains a section from
  that same vendor
- **THEN** that section does not count toward the floor

#### Scenario: The gate runs on a different host than produced the reviews

- **WHEN** CI evaluates a `REVIEWS.md` produced on a developer's host
- **THEN** self-exclusion applies to the host recorded in the artifact, not to
  whatever is running the gate

#### Scenario: The recorded identity is absent or unrecognised

- **WHEN** `REVIEWS.md` carries no implementing-host identity, or one outside
  the closed vocabulary
- **THEN** the gate counts no reviewers, rather than assuming a default, and
  reports the identity as absent or unrecognised. Failing closed here is failing
  closed on the COUNT — it does not block, because no review state does

#### Scenario: Several hosts are named

- **WHEN** `REVIEWS.md` names two implementing hosts
- **THEN** neither vendor's sections count toward the floor

#### Scenario: A vendor appears twice

- **WHEN** the same vendor has two sections
- **THEN** it contributes at most one to the count

#### Scenario: A vendor's two sections carry conflicting verdicts

- **WHEN** one vendor has two well-formed sections, one APPROVE and one
  REQUEST-CHANGES
- **THEN** it contributes one to the count and the gate reports
  REQUEST-CHANGES, because at a floor of one the report is the only signal and
  discarding the objection would be the unsafe resolution

### Requirement: The trailer has a grammar

`REVIEWS.md` SHALL carry exactly one trailer, as the final content of the file,
in this form:

```
<!-- openspec-review-trailer v1
implementing-host: <vendor>[,<vendor>...]
digest: sha256:<64 lowercase hex digits>
producer-version: <semver>
-->
```

- The opening and closing delimiters SHALL be exactly as shown.
- Each field SHALL occupy one line, as a lowercase key, a colon, a single
  space, and the value. The three keys above are REQUIRED and SHALL appear
  **exactly once each**; a repeated required key makes the trailer malformed
  rather than resolving to the first or last occurrence, because first-wins and
  last-wins are both defensible and two parsers would split.
- **Field order is not significant.** An unrecognised key SHALL be ignored
  wherever it appears, so a later producer may add fields without invalidating
  evidence for an older gate.
- A fourth key, `tasks-digest`, MAY appear. It is informational — see the
  advisory tasks-drift rule below — and its absence SHALL NOT invalidate the
  trailer. If present it SHALL appear **exactly once**, on the same footing as
  the required keys: two `tasks-digest` lines make the trailer malformed rather
  than resolving first-wins or last-wins. Leaving repetition undefined for the
  one optional field is the same parser-divergence hole this grammar closes
  everywhere else. Its value SHALL match the `sha256:<64 lowercase hex>` form
  or the trailer is malformed; `absent` is also accepted, and means the
  producer found no `tasks.md`.
- `implementing-host` SHALL list one or more vendors from the closed vocabulary,
  separated by a single comma with **no surrounding whitespace**:
  `claude,codex`, never `claude, codex`. Whitespace around a list element makes
  the value malformed; it is not trimmed. Trimming and rejecting are both
  defensible, so one is chosen and stated — a parser that trims and a parser
  that rejects would disagree about the same file, which is the failure this
  grammar exists to prevent. A value naming a vendor outside the closed
  vocabulary is malformed on the same footing.
- **A required field present but malformed SHALL be treated exactly as absent.**
  A `digest` that does not match `sha256:` followed by 64 lowercase hex digits, a
  `producer-version` that is not exactly three dot-separated runs of decimal
  digits (`N.N.N` — no pre-release or build metadata; the trailer records a
  published artifact version, which is always that shape), an `implementing-host` violating the
  list grammar — each makes the trailer malformed. Specifying only *missing*
  fields left a parser free to accept a garbage value, which fails open in the
  one place this requirement fails closed everywhere else.
- **The trailer is the final content, with whitespace tolerance stated.** After
  the closing `-->` the file SHALL contain at most whitespace: any number of
  newlines, spaces or tabs, and a final newline is optional. Anything else means
  the trailer is not final. Without this, a file differing only in a trailing
  blank line is accepted by one parser and rejected by another.
- A file carrying no trailer, more than one trailer, a trailer that is not the
  final content, or a trailer with a required field missing **or malformed**
  SHALL count zero reviewers. This fails closed: a malformed trailer is
  indistinguishable from an absent one for the purpose it serves.
- The trailer is an HTML comment so that it does not render, cannot be read as
  reviewer prose, and is unambiguously delimited for the substance rule that
  must exclude it.

This requirement exists because the change that introduced the trailer specified
it as "a trailer the gate can parse" — the same "parseable without a grammar"
formulation that produced four divergent-parser defects and that this delta
elsewhere specifies to the byte. A reviewer caught the repetition. A producer
and a gate are two implementations; they need the grammar as much as any other
pair would.

#### Scenario: The trailer is well-formed

- **WHEN** `REVIEWS.md` ends with a single trailer carrying all three required
  fields
- **THEN** the gate reads the implementing hosts, the digest and the producer
  version from it

#### Scenario: A required field is missing

- **WHEN** the trailer omits `digest`, `implementing-host` or `producer-version`
- **THEN** the gate counts zero reviewers and reports the trailer as malformed

#### Scenario: A required field carries a malformed value

- **WHEN** `digest` is not `sha256:` plus 64 lowercase hex digits, or
  `producer-version` is not semver, or `implementing-host` carries a space after
  a comma or names a vendor outside the closed vocabulary
- **THEN** the gate treats the field as absent: zero reviewers, reported as
  malformed

#### Scenario: The file ends with trailing blank lines

- **WHEN** `REVIEWS.md` has one or more blank lines after the closing `-->`
- **THEN** the trailer still counts as the final content, and the file is
  treated identically to one ending immediately after `-->`

#### Scenario: Two trailers are present

- **WHEN** `REVIEWS.md` carries more than one trailer block
- **THEN** the gate counts zero reviewers rather than choosing between them

#### Scenario: A later producer adds a field

- **WHEN** a trailer carries a key the gate does not recognise, alongside all
  required fields
- **THEN** the unknown key is ignored and the review counts normally

#### Scenario: A required key appears twice

- **WHEN** a trailer carries two `digest` lines
- **THEN** the trailer is malformed and the gate counts zero reviewers, rather
  than choosing the first or the last

#### Scenario: A bare verdict is followed by a producer-authored block

- **WHEN** a section carries a verdict line and no body, and a producer-authored
  notice, record or trailer appears later in the file
- **THEN** the section still fails the substance rule and does not count

#### Scenario: A vendor emits the trailer delimiter

- **WHEN** a reviewer's response body contains the trailer's opening delimiter
- **THEN** the producer rejects that response and records the vendor as failed,
  because publishing it would produce a second trailer and invalidate the whole
  artifact — a one-vendor denial of service on an otherwise good review set

### Requirement: A review is bound to what it reviewed

`REVIEWS.md` SHALL record a digest of the change artifacts as they stood when
reviewed. The gate SHALL treat the review as stale, and not count it, when the
current artifacts no longer match.

Without this, amending a change after review silently retains evidence for text
nobody read. This is not hypothetical: during the session that wrote this
requirement, two open changes were substantially revised after being reviewed,
and both retained their prior `REVIEWS.md` with the gate unable to tell.

**The digest SHALL cover exactly the artifacts transmitted to reviewers**, so
that it invalidates evidence when and only when reviewed content changes. The
computation SHALL be:

- **Set** — `proposal.md`, `design.md`, and every `specs/**/*.md`, addressed
  by path relative to the change directory and ordered bytewise under `LC_ALL=C`.
  A file not present on disk is not in the digest, so deleting a spec delta
  changes it. This set SHALL be identical to the set the producer transmits to
  reviewers — one rule, stated once. An implementation whose prompt and digest
  cover different files satisfies neither. The producer today globs
  `specs/*/spec.md`, a single level; it is corrected to match, rather than the
  digest being narrowed, because a nested spec delta is part of the change and
  must be both reviewed and bound.
- **Enumeration** — the set SHALL be gathered and ordered with **NUL**
  delimiters, never line delimiters. A path may legally contain a newline, and
  a line-based pipeline splits such a path into two paths that do not exist:
  the file silently leaves the set, or the digest is refused for a wrong
  reason. Framing record boundaries is worthless if the boundary is lost
  during enumeration. `**` is not delegated to a shell glob — shells differ on
  `**`, zero-level matches and dotfiles — but defined as: every `*.md` at any
  depth under `specs/`, found by directory traversal.
- **Members** — regular files only. A symlink or non-regular file in the set
  SHALL make the digest uncomputable, and the producer SHALL refuse to publish
  rather than resolve it. Following a link would hash bytes from outside the
  change directory while attesting to a path inside it.
- **Canonicalisation** — CRLF sequences become LF; a trailing LF is appended if
  absent. No other transformation: each additional rule is another place two
  conformant implementations can disagree.
- **Framing** — for each file in order: the byte length of the relative path in
  decimal, LF, the path bytes, LF, the canonical content length in decimal, LF,
  then the canonical bytes. **Both** path and content are length-prefixed: a
  path may legally contain a newline, and framing only the content would let
  such a path forge a record boundary.
- **Algorithm** — SHA-256, rendered lowercase hex.

**The prompt, the digest and the published file SHALL derive from one
snapshot.** The producer SHALL capture the artifact set once, build the reviewer
prompt and compute the digest from those captured bytes, and SHALL verify the
artifacts are unchanged before publishing, refusing to publish if they are not.

Without this the three are separate reads of a mutable tree: reviewers can
receive one revision, the digest attest to a second, and the gate compare
against a third, with every individual step conformant and the binding
worthless.

The pre-publication check is **best-effort drift detection, not a guarantee**:
a write landing between the verification and the publication is not caught. It
converts a silent, minutes-wide window into a narrow one, and SHALL be described
that way rather than as atomicity.

`tasks.md` SHALL NOT be in the digest, and `REVIEWS.md` SHALL NOT be in the
digest. `tasks.md` is excluded because it is not sent to reviewers and because
it is edited continuously during implementation — binding it would stale a
review on every checked box and deadlock the gate. `REVIEWS.md` is excluded by
construction: it carries the digest.

The consequence SHALL be stated rather than discovered: a task list may change
without invalidating a review.

The previous revision justified that by asserting a task change altering what
the change promises must also alter a bound artifact. **That assumption is
unsafe and is withdrawn.** A reviewer supplied the counter-example: a task such
as "add a debug endpoint" can be added post-review without contradicting a word
of the proposal, design note or spec delta. The gap is real, and the reason for
accepting it is deadlock avoidance, not an argument that nothing can slip
through it.

**Advisory tasks-drift detection.** The producer MAY record a `tasks-digest` in
the trailer, computed over `tasks.md` by the same algorithm. When it is present
and no longer matches, the gate SHALL report that the implementation plan has
changed since review — and SHALL NOT block. This makes the blind spot visible at
the point of use without staling a review on every ticked checkbox.

A digest is used rather than a modification time because mtime does not survive
a fresh clone or a branch checkout, and would warn constantly in CI while
missing an in-place edit that preserved it.

#### Scenario: The task list changes after review

- **WHEN** `tasks.md` is edited after `REVIEWS.md` was written and a
  `tasks-digest` was recorded
- **THEN** the gate reports that the implementation plan has changed since
  review, and allows the edit

#### Scenario: The change has no design note

- **WHEN** a change omits `design.md`
- **THEN** it is absent from both the transmitted set and the digest, which
  agree because they are one set; its absence is not an error

A digest detects drift, not forgery. It is computable by anyone holding the same
artifacts, so it SHALL NOT be described as evidence that a review is authentic.

#### Scenario: A change is amended after review

- **WHEN** a proposal, design or spec delta is edited after `REVIEWS.md` was
  written
- **THEN** the recorded digest no longer matches, the review does not count, and
  the gate reports the change as reviewed-but-since-amended — distinguishably
  from never reviewed — and allows the edit

#### Scenario: A change is unmodified since review

- **WHEN** the artifacts match the recorded digest
- **THEN** the review counts normally

#### Scenario: A spec delta file is deleted after review

- **WHEN** a `specs/**/*.md` present at review time is removed
- **THEN** the digest no longer matches and the review does not count

#### Scenario: Implementation ticks a checkbox in tasks.md

- **WHEN** `tasks.md` is edited during implementation and no reviewed artifact
  changes
- **THEN** the digest still matches and the review continues to count

#### Scenario: A review predates digest recording

- **WHEN** `REVIEWS.md` carries no digest because it was written by an earlier
  producer
- **THEN** the gate reports the review as unverifiable and does not count it,
  so old evidence cannot silently satisfy a new rule

#### Scenario: The reasons for not counting are distinguished

- **WHEN** the gate declines to count a change's reviews
- **THEN** it reports which of these applies — no `REVIEWS.md`, a malformed or
  absent trailer, a digest that no longer matches, or no section meeting the
  verdict-and-substance rule — because the scheduled re-review wave is
  debuggable only if "stale" is distinguishable from "absent"

### Requirement: The gate carries no review escape hatch

The gate SHALL NOT read `GSD_SKIP_REVIEWS`, and SHALL NOT provide any other
environment variable whose purpose is to suppress or bypass the review report.
After this change the name SHALL be absent from the gate's source: it is not
read, not defaulted, and not named in its documentation.

A hatch made sense while reviews blocked. Since 2.0.0 they do not, so there is
nothing to escape and the variable's only remaining effect is to hide the NOTE
lines — reviewer count, verdicts, independence, and the names of objectors. That
inverts its stated purpose: it is presented as a way to proceed despite missing
evidence, and it operates as a way to not be shown evidence that is present.

Removing it is not a loss of control. The operator retains the decision the hatch
appeared to offer, because nothing blocks: the gate reports, and the operator
proceeds or does not.

**On not specifying behaviour-when-set.** An earlier revision required the gate to
"behave as if unset" when the variable was present, and separately forbade a test
asserting exactly that. Both cannot hold: guaranteeing behaviour for a name is
keeping the name in the interface. The requirement is absence, and absence is
verified by reading the source, not by exercising a variable the gate does not
know about.

#### Scenario: The gate's source is inspected

- **WHEN** the gate implementation and its documentation are searched for
  `GSD_SKIP_REVIEWS`
- **THEN** there SHALL be no occurrence

#### Scenario: An operator wants to proceed without a review

- **WHEN** an active change carries no review, `openspec validate --all` is green,
  and the operator intends to write code anyway
- **THEN** the gate SHALL allow the edit and report the absence, requiring no flag

#### Scenario: Validation is not green and no review exists

- **WHEN** `openspec validate --all` fails and no review exists
- **THEN** the gate SHALL block, on the validation condition alone

#### Scenario: No bypass path replaces the removed one

- **WHEN** the gate's source is inspected for any environment variable that can
  turn a blocking outcome into a permitting one
- **THEN** there SHALL be none

*An earlier revision folded this into the scenario above as "with no environment
variable able to alter that outcome" — a universal behavioural claim backed only
by a grep for one name, which a differently-named override would have passed. It
is separated here and stated as what is actually verified: inspection of the
source for any bypass path, not a test of one variable.*

#### Scenario: Conformance rows assert the hatch

- **WHEN** the conformance harness or migration tests carry rows asserting hatch
  behaviour
- **THEN** those rows SHALL be removed with the hatch rather than retained
  against an interface that no longer exists

#### Scenario: A shipped code path recommends the hatch

- **WHEN** any shipped executable advises an operator to set `GSD_SKIP_REVIEWS`,
  including at a failure path where too few reviewers responded
- **THEN** that recommendation SHALL be removed, and the failure path SHALL state
  what actually follows — that reviews do not block and the operator may proceed

#### Scenario: A specification still describes the hatch

- **WHEN** `spec/18-retargeted-change-gate.md` carries a truth-table row or prose
  stating the gate keeps the hatch
- **THEN** those statements SHALL be removed, because a spec describing a removed
  interface is how the stale claim survived the last time

### Requirement: The gate documents its thresholds as what they are

The gate's own header and inline documentation SHALL describe `MIN_REVIEWERS` and
`PREFERRED_REVIEWERS` as governing what is reported. Neither SHALL be described as
blocking, as a floor that fails a surface, or as a MUST that gates an edit.

The gate currently documents `MIN_REVIEWERS` as a "blocking floor (spec 1.1.0
MUST)" and applies it, five lines later, only to select which NOTE prints — under
a comment reading `REPORTED, NOT BLOCKED`. A reader who stops at the header leaves
with the model the capability was rewritten to remove.

#### Scenario: A reader consults the gate's header

- **WHEN** a reader looks up what `MIN_REVIEWERS` does
- **THEN** the header SHALL state that it selects which NOTE is emitted, and SHALL
  NOT describe it as blocking

#### Scenario: An operator raises the threshold expecting enforcement

- **WHEN** an operator sets `MIN_REVIEWERS=2` intending to restore blocking
- **THEN** the documentation SHALL state plainly that no value of it blocks, so
  the expectation fails at the point of reading rather than at a missed block

#### Scenario: Header and code disagree

- **WHEN** the gate's documentation and the code beneath it describe different
  behaviour for the same variable
- **THEN** this SHALL be treated as a defect and the documentation corrected

### Requirement: No published copy of the gate contradicts this capability

This repository SHALL NOT ship a copy of the gate that enforces a review
threshold, or that provides an escape hatch from one. A copy that no installer,
tool, or hook resolves SHALL be removed rather than brought into line.

`gate/openspec-change-gate.sh` is such a copy. It defaults `MIN_REVIEWERS=2`,
returns a blocking exit when reviewers are insufficient, treats
`GSD_SKIP_REVIEWS=1` as a live bypass of that live block, and reports *"BLOCKED —
no code edits until validate is GREEN and every active change has >= N
reviewers"*. `gate/README.md` documents this as contract. It has been superseded
since 2.0.0 and nothing points at it: `resolve-core-artifact.sh` maps the shared
install to the reference implementation, and `~/.agenticapps/bin/` holds a
byte-identical copy of that.

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

### Requirement: The gate fails a commit whose two instruction files differ

Where a repository carries both `AGENTS.md` and `CLAUDE.md`, the gate SHALL
compare them and SHALL fail the commit when they are not byte-identical. It
SHALL also fail when either name is unreadable, and when either is a symlink.

**The comparison SHALL read the staged index — blob and mode — and never the
working tree.** A pre-commit check that compares worktree files asserts
something other than what is about to be committed: an unstaged edit to one
name can make a genuinely divergent pair look equal, and an unstaged edit can
fail a commit whose staged content is fine. Both failure directions are worse
than no check, because both teach the operator that the check is noise.

**Where the repository is enrolled, both names SHALL be present.** The gate
SHALL fail a commit that stages the deletion of either one. Enrolment is the
existing predicate `agenticapps.workflow.enrolled` in the repository's local
git config, which the initializer writes and the floor already resolves — so
the check needs no new state to decide whether a repository ever had two names
to keep.

This is the only enforcement in this workflow that **blocks** besides
`openspec validate --all`, and it earns that by replacing a guarantee rather
than adding one. Until now the two names were the same inode, so divergence was
impossible by construction; two regular files make it possible, and a check that
merely reported would leave the fleet exactly where the previous synced-block
mechanism left it.

That precedent is the reason for the strength. Six "auto-synced" blocks lived in
fleet instruction files under a syncer that was retired on 2026-07-28; the blocks
went on declaring themselves auto-synced for months while nothing synced them,
and nothing reported it because nothing was looking. A writer without a blocking
check reproduces that outcome with a different marker.

Symlinks are rejected rather than resolved. A resolved link compares equal to
itself and would pass this check while reintroducing the arrangement the
initializer no longer produces.

#### Scenario: The two names have diverged

- **GIVEN** a repository where `AGENTS.md` and `CLAUDE.md` differ
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail
- **AND** it SHALL name both files and report that they must be identical

#### Scenario: One name is a symlink to the other

- **GIVEN** a repository where either name is a symlink
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail
- **AND** it SHALL report that both names must be regular files

#### Scenario: Only one name is present, and the repository is not enrolled

- **GIVEN** a repository carrying exactly one of the two names
- **AND** `agenticapps.workflow.enrolled` is not set in its local git config
- **WHEN** a commit is attempted
- **THEN** the gate SHALL NOT fail on this check

Not every repository uses this workflow, and one that never ran the initializer
has nothing to compare. The gate does not create work for repositories that
never opted in.

#### Scenario: An enrolled repository stages the deletion of one name

- **GIVEN** an enrolled repository carrying both names
- **WHEN** a commit stages the deletion of either one
- **THEN** the gate SHALL fail
- **AND** it SHALL name the file being removed

Without this, the pair is trivially escapable: delete one name and the equality
check has nothing to compare, so the strictest requirement in this capability is
satisfied by removing its subject. The staged-deletion case is the one an
ordinary `git rm` reaches by accident.

#### Scenario: A staged divergence hidden by an unstaged edit

- **GIVEN** an enrolled repository whose staged `AGENTS.md` and `CLAUDE.md`
  differ
- **AND** a working-tree edit that makes the two paths equal on disk
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail, because the staged blobs differ

#### Scenario: An unreadable instruction file

- **GIVEN** a repository where either name cannot be read
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail, reporting which name could not be read

A read is the only check that catches this. Structural inspection reports a
plausible file for both halves of a symlink cycle, which is how two repositories
carried unreadable instruction files for about 36 hours with every check green.

