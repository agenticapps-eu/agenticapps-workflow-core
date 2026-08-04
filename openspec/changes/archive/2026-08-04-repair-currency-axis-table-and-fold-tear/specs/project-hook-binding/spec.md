## MODIFIED Requirements

<!-- Two requirements are modified. The normative footprint is ONE clause in the
     axes table (Edit 1). Everything else is placement: a paragraph severed by the
     archive fold at 09f829e is made whole, moving three lines out of the second
     requirement and back into the first. No scenario moves between requirements,
     nothing is added, renamed or removed. -->

### Requirement: A machine's provisioning is a triple, not a state name

**A machine's provisioning is reported on three independent axes, not as one list
of states.** A reviewer found the capability asserting, under publication, that
"no project binds a hook whose implementation is absent", while the
clone-before-install scenario below explicitly permits exactly that. Both
sentences were true of different conditions and neither said which, so the pair
read as a contradiction.

A previous revision answered that with a flat list of four states — unprovisioned,
partially provisioned, provisioned, drifted — and a reviewer showed the list is
**not mutually exclusive**: a manifest whose files are all absent is both
unprovisioned *and* drifted, and one unattested file beside one missing file is
both partially provisioned *and* drifted. A machine cannot be "in exactly one" of
a set whose members overlap. The things being conflated are **how much is
installed**, **whether what is installed can be attested**, and — added later,
after a machine was described as provisioned while running builds three fixes
behind — **whether what is installed is still what the authority ships**. All
three vary independently:

| Axis | Values | Observable definition |
|---|---|---|
| **Completeness** | `none` / `partial` / `complete` | how many shimmed implementations are present and executable: none of them, some of them, all of them |
| **Integrity** | `attested` / `drifted` | `attested` when every present implementation matches a manifest row; `drifted` when any present implementation's bytes disagree with its row, any row names an absent file, or any present implementation has no row |
| **Currency** | `current` / `stale` / `unknown` | judged over the **declared** artifact set only. `current` when every declared, present implementation is byte-identical to the authority's file **as it exists on disk at the time of the check**; `stale` when any differs, or the authority holds no file for a declared, present artifact; `unknown` when the authority cannot be read or is not an authority checkout |

**Currency is a third axis and not a value on either of the others**, for the
reason completeness and integrity were split from each other. Both of those are
computed from the machine alone: completeness asks how much is installed,
integrity asks whether what is installed still matches what was installed. Neither
can ask whether what was installed is still what the authority ships, because the
manifest records a publication that already happened. A machine can therefore be
`complete` + `attested` against a stale row indefinitely.

This was found by its consequence, not predicted. On 2026-08-03 a machine
reported `complete` + `attested` — "This machine is provisioned. The shims will
resolve." — while running `normalize-claude-md` 1.0.0 against core's 1.0.1 and
`database-sentinel` 1.0.0 against core's 1.1.0. Measured on the published copies:
`CLAUDE.md` went 0644 in and **0600** out, and `DELETE FROM public.users` was
**not** blocked. Both are defects the fleet believed were fixed. The check printed
`attested v1.0.0` throughout; the number was on screen and nothing compared it to
anything.

`stale` and `drifted` are deliberately **not** merged. They have different causes
and different remedies: `drifted` means a published file was edited or replaced
and the remedy is to investigate, `stale` most often means the machine did
exactly what it was told and the world moved on. Reporting both as `drifted`
would train an operator to answer every occurrence by re-running the installer,
which is the wrong response to real tampering — and, per the `stale` invariant
below, is also the wrong response to several kinds of staleness.

A machine's state is the **triple**. `none` + `drifted` is the all-files-deleted
case that broke the flat list, and it is now expressible: nothing is installed
*and* the manifest still claims otherwise, which is a different remedy from a
clean fresh clone. The vocabulary maps onto the old names where they were
unambiguous — *unprovisioned* is `none`+`attested`+any currency (no rows, no
files, so nothing to be stale), *provisioned* is `complete`+`attested`+`current`
— and those names MAY be used as shorthand for exactly those triples, never as a
classification in their own right. **`complete`+`attested`+`stale` is not
"provisioned"**, and calling it that is the specific error this revision exists
to stop.

The rule that a project must never bind a missing implementation applies to the
**provisioned** state only. It is a post-condition of a completed install, not a
property of the fleet at all times — which is what made it look like it
contradicted a usable fresh clone.

Invariants attach to a value on one axis, never to a state name:

- **`none`** — shims resolve nothing, report, and allow. Binding a hook whose
  implementation is absent is **expected and permitted**; it is what a fresh
  clone is.
- **`partial`** — each present implementation is complete rather than truncated.
  Mixed is legal; torn is not.
- **`complete`** — every shimmed implementation is present and executable.
- **`attested`** — every present implementation matches its row. This says the
  published bytes are the bytes that were published; it says nothing about
  whether those were the right bytes to publish.
- **`drifted`** — the check reports the specific disagreement and its direction,
  and SHALL NOT resolve it silently.

**All three axes are computed from what is on disk, never from what happened.** The
previous revision defined *provisioned* as "a publishing run completed" and
*partially provisioned* as "a publishing run was interrupted". A reviewer showed
that history is not evaluable after the fact — nothing on the machine records
it — and, worse, that a completed install later deleted, hand-edited, replaced
or half-removed classified as **provisioned** under that definition. That is
precisely the condition the manifest check exists to detect, and the state table
was the one place it could not be named.

#### Scenario: A project is cloned before the installer runs

- **WHEN** a project is cloned onto a machine where the installer has never run
- **THEN** the project is usable, every shimmed hook reports itself missing, and
  no protection is claimed that is not running

### Requirement: Currency is judged against an authority checkout

**Currency names a comparison the tooling already performs.** `--source-check`
compares each executed copy against the maintained implementation and its own
header states the case: *a machine can be perfectly attested against a manifest
that published last month's implementation.* What was missing is a **verdict**.
The comparison reported findings into a separate block, the summary was computed
without it, and so the tool printed "This machine is provisioned. The shims will
resolve." while that block read `DIFFERS` on every project hook. Reproduced. An
axis is what obliges the summary to agree with the comparison.

**The declared set, and nothing else.** The shared bin also holds artifacts
published by a different installer — the change gate, the reviewer CLI, the plan
review runner — which this manifest already reports as "not covered". They SHALL
NOT be judged for currency, and "the authority holds no such file" is a finding
only for an artifact this manifest declares. Stated because the opposite was
tried: an earlier revision of this delta made an absent authority file `stale`
without scoping it, and running it flagged three artifacts that were correctly
outside scope.

**The authority is a checkout, not a branch.** Currency is evaluated against the
content on disk in the authority path when the check runs — never against core's
`main` and never against any remote, because the check reads files and cannot
know what a branch elsewhere contains. A design implying otherwise would promise
something unimplementable.

The consequence is normative rather than hidden: **a stale checkout of the
authority yields a stale reading**, and that is the check being right about the
disk rather than wrong about the world. Currency against a *branch* is a
different question, answered by comparing `git show <ref>:<path>` — which is what
the fleet's own contract propagation used as its durable check.

Invariants on the currency axis:

- **`current`** — every **declared**, present implementation is byte-identical to
  the authority's file as it exists on disk when the check runs. It licenses the
  claim *"matches this authority checkout"* and never *"matches what core
  ships"*: an authority checkout that is itself behind agrees with an equally
  behind install, and the pair reports `current`. That limit SHALL be stated
  wherever the verdict is, rather than left for a reader to deduce — an
  unqualified `current` here would recreate, one level up, the false green this
  axis exists to remove.

- **`stale`** — the check names each artifact and SHALL name a remedy **chosen
  for that condition**. It SHALL name both versions and the direction **where
  both are readable**, and SHALL say the version could not be read rather than
  inventing one where either side carries no parseable marker; the verdict stands
  on bytes in both cases. The conditional matters because an authority file
  without a marker makes the unconditional form unimplementable, and a
  requirement that cannot be met is one an implementation quietly reinterprets.
  A single universal remedy is forbidden because it is wrong in most of them:
  re-running the
  installer cannot clear a published version *ahead* of the authority, since the
  installer refuses downgrades; cannot fix an authority checkout that is itself
  behind; and destroys evidence when a machine is `drifted` and `stale` at once.
  Direction is compared **component-wise numerically**, never lexically —
  a lexical compare places `1.10.0` below `1.9.0` and would point the operator at
  the opposite remedy.

- **`unknown`** — reported per its sub-cases, so that an unasked question is never
  dressed as a finding: the authority path is absent or unreadable; the path
  exists but holds no declared artifact at all, meaning it is not an authority
  checkout and reporting every artifact `stale` would be confidently wrong; or an
  individual file cannot be read, a failed read being distinct from a difference;
  or the comparison itself fails, which is likewise distinct from the two files
  differing and SHALL NOT be reported as a difference.
  Aggregation: any `stale` makes the machine `stale`, otherwise any `unknown`
  makes it `unknown` — a known finding outranks an unasked question.

  **Currency is judged over the declared artifacts that are PRESENT.** An
  artifact that is absent from the machine is completeness's finding and SHALL
  NOT also be reported by this axis, whether or not the authority holds it —
  reporting one fact on two axes is what made the flat four-state list
  unusable. The consequence is that `current` holds vacuously when nothing
  declared is installed, which is correct and harmless: the licence requires
  `complete` as well. It SHALL NOT install anything: this capability's
  tools report and the installer installs, and a check that silently rewrote the
  shared bin would be doing the one thing `drifted` is forbidden to do.
  `unknown` SHALL NOT be reported as `current`. A result is a statement about
  what was checked, never about the machine — the same rule the override scan
  follows when it reports *no known vector found* rather than *no override is
  set*. The report SHALL name the path it looked for and which question went
  unanswered, so an operator can tell an ordinary condition from a broken one.

**The licence to describe the fleet's protections as running as documented
requires `complete` + `attested` + `current`, and no other combination grants
it.** It previously attached to `attested` alone. That was too strong and was
observed to be false: a machine held `complete` + `attested` while running two
implementations missing three landed fixes, and was described as provisioned
throughout. `unknown` does not grant the licence either — an unchecked claim and
a verified one must not read the same.

**A strict mode SHALL fail on any currency value but `current`, `unknown`
included, and SHALL offer no flag that exempts it.** Declining to ask the
question and demanding a clean strict result are contradictory, and the
contradiction SHALL resolve as a failure rather than as a pass — an opt-out that
produced a green strict run would restore, in one flag, precisely the silent
pass this axis exists to remove. Two flags that contradict each other outright —
naming an authority while declining to consult one — SHALL be a usage error
rather than resolved by order of appearance, because last-one-wins silently
performs the opposite of half the instruction it was given.

#### Scenario: The installed build is older than the one the authority ships

- **WHEN** every declared implementation is present and matches its manifest row,
  but one of them differs from the authority's tracked source
- **THEN** the machine is `complete` + `attested` + **`stale`**, the check names
  that artifact with both versions and the direction, and the machine SHALL NOT
  be described as provisioned or as running its protections as documented

#### Scenario: The authority is not reachable from the machine

- **WHEN** the check runs where the authority's tracked source is not present
- **THEN** currency is reported `unknown` rather than `current`, and the licence
  to describe the protections as running as documented is withheld — an
  unchecked claim and a verified one must not read the same

#### Scenario: The versions agree and the bytes do not

- **WHEN** a present implementation's version marker equals the authority's while
  its bytes differ
- **THEN** it is reported `stale` and the report says the versions agree while the
  bytes do not, because that is a build error or a hand-edit rather than the
  ordinary lag a lower version indicates

#### Scenario: The comparison reports a difference and the summary does not

- **WHEN** the source comparison reports that an executed copy differs from the
  maintained implementation
- **THEN** the machine's summary SHALL reflect it. Reproduced before this
  revision: the comparison printed `DIFFERS` for every project hook while the
  summary printed "This machine is provisioned. The shims will resolve.",
  because the finding fed a separate block and no verdict

#### Scenario: The stronger question is never asked

- **WHEN** the currency comparison does not run
- **THEN** the report says which question went unanswered, and the summary does
  not read as it would had the question been asked and answered. A comparison
  that is optional and silently skipped is indistinguishable from one that passed

#### Scenario: The authority checkout is as old as the installation

- **WHEN** the authority checkout and the installed copies are equally behind, so
  they agree
- **THEN** the verdict is `current` **qualified as matching this authority
  checkout**, and SHALL NOT be stated as matching what the project ships — the
  check reads a checkout and cannot see a branch

#### Scenario: The authority holds no such artifact

- **WHEN** a **declared and installed** artifact has no counterpart in an
  authority that does hold other declared artifacts — the checkout predates it,
  or it was renamed upstream
- **THEN** it is reported `stale` with its own message and its own remedy, **not
  `unknown`**: the authority was reached and holds the rest, so "this one is not
  in it" is a finding rather than an inability to check
- **AND** a declared artifact that is absent from the machine *and* from the
  authority is **not** judged for currency at all — completeness already reports
  it, and a second report on a second axis says nothing new
- **AND** an artifact the manifest does not declare — one published by a
  different installer into the same directory — is **not** judged at all, because
  the authority was never expected to hold it

#### Scenario: The machine carries a build ahead of the authority

- **WHEN** a present implementation's version marker is higher than the
  authority's
- **THEN** it is reported `stale` in that direction — the machine holds a build
  the authority cannot account for — rather than passed as newer-and-fine, for
  the same reason a shim marker ahead of the template is `unrecognised`
