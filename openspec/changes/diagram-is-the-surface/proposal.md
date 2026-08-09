## Why

The repository still carries the surface of things it already decided to remove.
GitNexus went on 2026-07-28 and six of its skills still load in core's own
`.claude/skills/`. `database-sentinel` went on 2026-08-07 and its implementation
and declaration entry still ship. `GSD_SKIP_REVIEWS` stopped escaping anything at
gate 2.0.0 and is still read, still advertised across twenty files, and still
recommended to the operator by `run-plan-review.sh` at a failure path.

Largest of all: **`gate/` publishes a pre-2.0.0 gate that nothing resolves.** It
defaults `MIN_REVIEWERS=2`, blocks on insufficient reviewers, treats
`GSD_SKIP_REVIEWS` as a live bypass of that live block, and `gate/README.md`
documents this as contract. Every installer, tool and hook resolves
`reference-implementations/` instead, and the installed copy at
`~/.agenticapps/bin/` is byte-identical to it. So `gate/` enforces nothing — it
only tells readers the gate works a way it has not worked since 2.0.0.

`CLAUDE.md` already states the test: *"If a thing is not on that diagram and is
not required to make a step on it work, it does not belong in this repo."* Nothing
here is a new judgment. It is that test applied to what is on disk, once.

The cost is not tidiness. A vestigial flag documented as an escape hatch gets
reached for as one. A published gate that contradicts the spec teaches the wrong
model to everyone who reads it. And a diagram that still says *"REVIEWS ≥ 2"* is
the specification of the loop, so it is wrong at the source.

## What Changes

**Removed — dead surface**

- `gate/` — the orphaned published gate and its README. Nothing resolves it;
  `resolve-core-artifact.sh` maps the shared install to
  `reference-implementations/openspec-change-gate/openspec-change-gate.sh`.
- **BREAKING** `GSD_SKIP_REVIEWS` — the variable, its conformance rows, the
  `run-plan-review.sh` failure-path recommendation, and the twenty files that
  advertise it. Vestigial since 2.0.0 by the gate's own header.
- `reference-implementations/project-hooks/database-sentinel.sh` and its
  `SHIMMED-HOOKS` entry.
- Core's own `.claude/skills/gitnexus/` — six skills.
- The dangling `~/.claude/skills/ts-declare-first` symlink, pointing into
  `~/.claude/skills/agenticapps-workflow`, which no longer exists.
- The `gitnexus` MCP server entry in `~/.config/opencode/opencode.json`.
- Four stale `SKILL.md.pre-0034` files in fleet repositories.

**Corrected — wrong, not dead**

- `workflow.mmd` line 7 states *"no code edits until validate GREEN and REVIEWS
  ≥ 2"*. Reviews have not blocked since 2.0.0.
- `workflow.mmd` line 13 routes *"db-sentinel if SQL/RLS · design + qa if UI"* to
  a removed hook and to two gate bindings this change removes. The diagram wins
  where it and the prose disagree, so it is corrected in the same change rather
  than after it.
- `spec/18-retargeted-change-gate.md` line 104 carries a truth-table row for the
  hatch and line 235 states the gate keeps it deliberately.
- The gate header documents `MIN_REVIEWERS` as a blocking floor. It is not; it
  selects which NOTE prints.
- Global `CLAUDE.md` warns that two skills claim the `agentic-apps-workflow`
  name. One of the two no longer exists.

**Removed — gate bindings, and this half is a policy change, not a cleanup**

Named separately because bundling it under "dead surface" would hide it. One of
these two skills is gone; the other is not, and unbinding it is a decision.

- **`database-security` → `database-sentinel`.** The skill is gone from every
  host — checkout and both aliases removed 2026-08-09, and no host declares the
  name. The gate table still routes every SQL, RLS and migration change to it.
  This is the stale-binding half.
- **`design` → `impeccable`.** The skill **exists and stays installed**,
  resolving by canonical name on every host. It is unbound because it is wanted
  on demand rather than fired automatically on every UI change. This is the
  policy half, and it removes a control that ADR-0011 made automatic.

The `qa` binding and all seven always-on gates are untouched. Neither gate leaves
§02's taxonomy; core stops binding a skill to each, and §02 and §17 are amended
where they oblige otherwise.

**Version: 2.0.0.** Two gates lose their bindings and §02 and §17 are amended
where they oblige those gates to be bound and to fire. An earlier draft argued
1.7.0 on the grounds that §09's "gate removed" means removed from the taxonomy;
two independent reviewers called that self-serving and they were right. A team
pulling this loses an automatic security control, and the number has to say so.
Per §09 the release entry states the conformance impact, so `CHANGELOG.md` is in
scope — see the corrected exclusion below.

**Not touched.** `openspec/changes/archive/` and the change documents recording
these removals. Deleting the record of a decision is not minimizing; it is
losing the reason.

**Two entries left this exclusion list and both were wrong to be on it.**
`adrs/` — no ADR is edited or deleted, but ADR-0030 is *added*, superseding
ADR-0011 (`impeccable` at two gate points) and ADR-0012 (`database-sentinel`
findings block branch close, and `db-pre-launch-audit` with it). Both are
Accepted and both mandate behaviour this change removes, so leaving them
standing would leave the repository contradicting itself. `CHANGELOG.md` — §09
requires the release entry to state conformance impact, which a 2.0.0 cannot
skip.

**Honest scope on installed copies.** Removing an artifact from
`~/.agenticapps/bin` on this machine does not remove it from any other machine's
install. The installer publishes an allowlist and has **no retired-artifact
sweep**, so an existing installation keeps an orphan indefinitely. This change
does not build that sweep. The claim is therefore limited to this machine, and
the missing mechanism is recorded as a gap rather than implied to be solved.

**§13 is retired in this change — on the fourth argument, and the first sound
one.** The three that failed are recorded in full below, because the pattern is
the point and the reasoning is what stops a fifth.

1. The first proposed retiring `spec/13-ts-declare-first.md` on the claim that no
   host bound it. False, and reached by checking `~/.claude/skills` and stopping.
   `reference-implementations/README.md` records **three** hosts binding it —
   `codex-ts-declare-first`, `opencode-ts-declare-first`, `pi-ts-declare-first` —
   and pi reached `full` conformance at host v0.6.0 *by* binding §13.
2. The second, on 2026-08-09, read the deleted `~/.claude/skills/ts-declare-first`
   symlink as evidence about the section. §13 makes the skill name **explicitly
   host-discretionary** — "commonly named `ts-declare-first`, but the name is at
   the host's discretion" — so no directory's absence on one machine says
   anything about it at all.
3. The third argued that the three hosts are on `install.sh`'s
   `ARCHIVED` list and so protect no live consumer. Also false. That list
   identifies **legacy symlink targets to strip**, and says so: "a tombstone
   list, **not a dependency**." It is not a statement about repository
   lifecycle. Measured 2026-08-09: all four host repos have live `origin`
   remotes and commits dated 2026-08-05, and `agenticapps/CLAUDE.md` lists three
   of them under *"Active repos"*.

Every one of those read a **local artifact** — a skills directory, a symlink, an
installer variable — as evidence about a **normative section with a
host-discretionary implementation**. It never is, and the hosts they dismissed
are real.

**The argument that works is about marginal cost, not usage, and it only became
available once this release went major.** Removing the two gate bindings already
obsoletes every prior-major conformance claim under §09. The three hosts binding
§13 must re-assert against 2.0.0 either way. Retiring §13 in this release
therefore adds no break the release does not already impose, while retiring it in
any later release would impose a second one on the same three hosts. One accepted
break is strictly cheaper than two.

So the section file is deleted, the number stays **vacant**, and nothing is
renumbered — §15's rule applied a second time. `reference-implementations/README.md`
keeps its record of the three bindings: those are true facts about what those
repos contain, and only their status changes.

**On BREAKING and the version, which two reviewers found in tension.** Both
readings were in this document: `GSD_SKIP_REVIEWS` marked **BREAKING**, and the
design claiming nothing here breaks the `spec/` surface. They are not the same
claim, and the document should not have left them adjacent without saying so.

Removing a documented environment variable an operator may have exported is
breaking **to the gate's interface**, and it is labelled so.

**The open question that used to sit here is now closed, and closed the other
way.** It read: no `spec/` section is removed, no `implements_spec` claim is
invalidated, only §18 is edited, so whether that is minor or major is undecided.
Every clause of that is now false. §13 **is** removed. Two gate bindings **are**
removed. §02 and §17 are amended. Host claims citing §13 **are** invalidated —
which is acceptable only because every host that holds one is on this
repository's own archived list, not because no claim moves.

So this lands at **2.0.0**, and the §18 edit rides along inside it rather than
needing its own verdict.

An earlier draft of the folded scope argued 1.7.0, reading §09's "gate removed"
as meaning removed from §02's taxonomy while a binding could go quietly. Two
independent reviewers rejected it in the same words — *self-serving* — and they
were right: a consumer who loses an automatic security control and a normative
contract has had something broken, whatever the taxonomy still lists. The
classification is taken from §09 against behaviour lost, and never from a
requirement this change writes about itself.

## Capabilities

### New Capabilities

- `vestigial-surface-removal`: what makes a *shipped enforcement or interface*
  artifact vestigial, and the obligation to remove it rather than carry it with a
  comment explaining that it does nothing. Deliberately scoped to that class —
  see design; an earlier revision stated it over all artifacts and condemned the
  repository's own records.

### Modified Capabilities

- `change-gate-enforcement`: `GSD_SKIP_REVIEWS` is removed from the gate's
  interface rather than retained-but-inert; the gate's documentation of
  `MIN_REVIEWERS` must match its behaviour; and no published copy may contradict
  the capability.

*Not `project-hook-binding`.* An earlier revision listed it for
`database-sentinel` leaving `SHIMMED-HOOKS`. That is already specified by
`projects-bind-not-copy`, whose "No project binds any fleet hook once the surface
is closed" subsumes the single entry. A second delta would compete with a
twice-reviewed one.

## Impact

- **`gate/`** — removed entirely. The one item that changes what a reader believes
  about enforcement.
- **`reference-implementations/openspec-change-gate/`** — the hatch branch, its
  header block, the `MIN_REVIEWERS` documentation, the README, the CI yml.
- **`reference-implementations/run-plan-review/`** — line 677 recommends the
  hatch to the operator. This refutes "the conformance rows are its only live
  consumers", which an earlier revision asserted.
- **`reference-implementations/project-hooks/`** — `database-sentinel.sh`,
  `SHIMMED-HOOKS`, the gate shim.
- **`spec/18`** — two statements of the hatch.
- **`skills/agentic-apps-workflow/SKILL.md`** — core's own trigger skill
  advertises it.
- **`tools/`** — conformance rows asserting the hatch.
- **`workflow.mmd`** — two lines, both load-bearing, both currently false.
- **Published artifacts** — `OpenSpec-Change-Cheatsheet.html`, `publish/index.html`,
  `docs/HOW-IT-FITS-TOGETHER.md`, `WORKFLOW-EXPLAINED.md`, `GATE-INVENTORY.md`,
  `PILOT-REPORT.md`.
- **Outside the repository** — the dangling host symlink and the opencode MCP
  entry, recorded as steps rather than shipped.

**Sequencing.** `database-sentinel`'s removal is decided in
`projects-bind-not-copy` and executed here. That change is unmerged, so the
dependency is a hard block with a stated fallback, not an ordering preference —
see design.
