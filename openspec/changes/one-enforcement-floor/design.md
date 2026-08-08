# Design — one enforcement floor

## Context

Three decisions arrive together because they are one decision seen from three
sides: *how much of this workflow has to know which agent is running it?*

Today the answer is "one hook, three implementations, 320 lines". The claim here
is that the answer can be "none", and that the enforcement it provides survives
the removal because it was never the load-bearing surface.

## Decision 1 — remove the host hook

### Alternatives considered

**A. Remove it entirely.** *(chosen)*

**B. Keep it for claude only.** claude is the host with the most session time on
this machine, so the argument is that the wiring cost falls by two thirds while
most of the benefit is retained.

Rejected. It reintroduces per-host divergence for one host's convenience, which
is the shape this repository exists to remove — and it makes the enforcement
story different depending on which agent you happen to open. It also fails the
standing constraint that there is always more than one agent: a design whose
value depends on one host being dominant is a design that breaks when the mix
changes, and the mix has changed twice already.

**C. Keep all three (status quo).**

Rejected on the measurements in `proposal.md`: it does not enforce
spec-before-code, the condition it does enforce is caught twice more downstream,
and it carries every host-specific line in the repository.

**D. Keep the hook and set `OPENSPEC_GATE_STRICT=1`,** so it blocks edits when
no change is open and becomes genuinely load-bearing.

Rejected, but it is the strongest alternative and deserves its refutation
written down. Strict mode makes the hook enforce something the other surfaces
do not *currently* enforce — but not something they *cannot*. `pre-commit` can
refuse a commit that stages code with no active change using the same
`gate_check` call and the same env var. Choosing the host hook for it buys
earliness and costs three implementations; choosing `pre-commit` buys the same
rule at one. If "no code without a change" is wanted, it should be turned on at
the floor, not used to justify the ceiling.

### What is actually lost

In-session latency, and nothing else. An agent can now write a feature against a
malformed spec delta and learn at `git commit` rather than at the first `Edit`.

This is a real loss and it is accepted rather than argued away. Two things bound
it: the loop runs `openspec validate --all` at step 2, before code, so a
malformed delta is normally caught before an edit is ever attempted; and the
gate is fast, local and deterministic, so the commit-time failure is instant and
legible rather than a delayed CI red.

## Decision 2 — the git floor becomes global

### Alternatives considered

**A. `git config --global core.hooksPath <dir>`, one published hook.** *(chosen)*

**B. Keep the per-repository install (status quo).**

Rejected by measurement. Nine repositories carry the gate's `pre-commit`. They
are **883, 1201, 2270 and 5844 bytes** — four versions of one authority, and
nothing on the machine reports the divergence. A per-repository copy is a fork
that nobody notices has forked, which is the same argument that makes skills
symlinks rather than copies.

**C. Global hooksPath, with per-repository opt-out via a local
`core.hooksPath`.**

Not rejected — this *is* the chosen design, because git already provides it.
Local configuration overrides global, so any repository needing different hooks
sets its own path and is unaffected. It costs nothing to support because it is
not a feature we implement.

**D. Drop the git hook too and rely on CI.**

Rejected. CI is the slowest surface and does not run on most of these
repositories at all. Removing both the host hook and the git hook leaves the
workflow with no local enforcement whatsoever, which is a different and much
larger claim than the one this change makes.

### The displacement risk, measured — and the first measurement was wrong

`core.hooksPath` **replaces** the hooks directory; it does not add to it.
Verified rather than read: with `core.hooksPath` set, a `pre-commit` in
`.git/hooks/` does not run at all — the global one runs instead, and nothing
reports that the local one was skipped. So a global setting could silently
disable every existing per-repository hook on the machine. That is the objection
that would kill this decision if it held.

**An earlier revision of this section said it did not hold, and that was false.**
It claimed exactly nine repositories, all `pre-commit`, all this gate, and "no
husky, no lefthook, no lint-staged, no `pre-push`, no `commit-msg`". Re-measured
2026-08-07 across `~/Sourcecode`, resolving each repository's hooks directory
with `git rev-parse --path-format=absolute --git-path hooks`:

- **11 repositories** carry a `pre-commit`, over 10 distinct hooks directories —
  `agenticapps-dashboard-add-agent-board` is a linked worktree sharing the
  dashboard's.
- **15 hook types** are present, not one: `pre-push`, `commit-msg`,
  `post-checkout`, `post-commit`, `post-merge`, `post-rewrite`,
  `prepare-commit-msg`, `pre-rebase` and more.
- **husky ^9.1.7 with lint-staged ^17.0.7** is installed in `fbc-platform`,
  hooks dated 15 July — they predated the original measurement.
- Sizes are **1376, 1201, 2270, 5844 and 39**. Nothing is 883 bytes.

The correction is recorded rather than quietly applied, because this change's
stated virtue is being measured rather than assumed, and on its central safety
claim it was assumed.

### Why the decision survives the correction — for a different reason

Husky is not displaced, and the reason is not that it is absent. `fbc-platform`
sets a **local** `core.hooksPath` of `.husky/_`, and git resolves local before
global. Alternative C — per-repository opt-out via local configuration — is
already doing the work, unprompted, for the one repository that needed it.

So the design is right and its stated grounds were wrong. The premise it
actually rests on is *local overrides global*, not *the set displaced is empty*.

### What that premise costs, which the earlier version did not see

Six repositories already set a local `core.hooksPath`: `claude-workflow`,
`callbot`, `fx-signal-agent`, `agenticapps-dashboard` and its linked worktree at
their own `.git/hooks`, and `fbc-platform` at `.husky/_`.

Local beats global, so **the global binding reaches none of them** — including
three of the five repositories currently carrying the 1201-byte gate. The
override was framed above as a rare escape for a repository that wants different
hooks. It is the majority condition among repositories that carry hooks at all,
and five of the six point at their own *default* directory, which is a no-op
setting that reads as tool-written rather than chosen.

Two consequences follow, and they point in opposite directions:

1. A repository can opt out of the enforcement floor by accident, and nothing
   reports that it has. This is the mirror image of the displacement risk and it
   is the more likely failure, because it is already true.
2. Those five redundant bindings are **safe to unset** — they name the directory
   git would resolve anyway — so the sweep restores global reach without
   changing behaviour in any of them today. `fbc-platform`'s is a real opt-out
   and stays.

The remaining caveat is unchanged and now better founded: a repository that
later adopts a hook manager sets its own path and leaves the floor silently,
so `--check` must report the **effective** binding per repository rather than
assert the global one.

### The composition contract

The published hook must be composable, and the two reviewers who raised this
disagreed about how. One asked that it exec the repository's original
`.git/hooks/`; the other objected that doing so re-enables execution of
repository-controlled code at commit time, which is precisely what `hooksPath`
takes away. Both are right about their own half.

The contract is therefore: the published `pre-commit` dispatches to the gate and
then to an **operator-owned, machine-level `hooks.d`** alongside the published
directory. It SHALL NOT exec anything resolved from inside a repository. That
buys composition for the operator, who is the party that actually wanted it,
without making a clone's contents executable at commit time. A repository that
needs its own hooks has git's local override, which is the supported answer and
costs us nothing to support.

## Decision 3 — drop `--project`

`--project` was deferred from `core-installer-one-entry-point` because it turned
out to be two things: a project-shim installer, and an instruction-file
provisioner core does not have.

Decisions 1 and 2 remove the first of those. Once the gate's `pre-commit` is
bound machine-wide, there is no per-repository hook for `--project` to install.

What remains is the provisioner — writing a workflow section into a project's
`AGENTS.md`. That is not dropped by this change so much as **exposed as the only
thing `--project` was ever going to be**, and it is deliberately left
unaddressed, because whether that section should exist at all is now an open
question rather than a settled requirement (below).

Dropping `--project` also **releases the sequencing constraint** recorded in
`core-installer-one-entry-point`: that `--project` had to land before Phase 5b
deleted the archived checkouts. It no longer does. Phase 5b's remaining blocker
is the codex adapter and opencode plugin — which this change deletes.

## The scope predicate — open, and the reviewers found it

A global binding means the published hook runs in **every repository on this
machine**, including every repository that never opted into this workflow. Two
reviewers raised this independently; it was measured on 2026-08-07 rather than
argued, by installing the reference `pre-commit` into throwaway repositories and
committing staged code:

| Repository shape | Result |
|---|---|
| No `openspec/` directory at all | exit 0, no output |
| `openspec/` present, unrelated content, empty `specs/` and `changes/` | exit 0 |
| `openspec/` containing anything that fails `openspec validate --all` | **exit 1 — commit blocked** |

The first two are the reassuring cases and they behave correctly. **The third is
the defect.** A repository acquires a blocking commit hook by the accident of
containing a directory called `openspec` — a test fixture, a vendored example,
an abandoned experiment, a sample copied from documentation. Nobody in that
repository opted in, and the failure arrives as `commit BLOCKED` with a message
about spec deltas that will mean nothing to them.

This is the difference between the floor being *reachable* everywhere and being
*imposed* everywhere, and the change currently specifies only the first.

### Decided 2026-08-07 — an explicit opt-in marker

A repository is in scope when it carries a local git config key,
`agenticapps.workflow.enrolled`. The published hook checks it first and exits 0
otherwise:

```sh
git config --get agenticapps.workflow.enrolled >/dev/null 2>&1 || exit 0
exec "$GATE" --pre-commit
```

The third row above becomes exit 0, because a fixture repository has no marker.
An enrolled repository with a malformed delta still blocks, which is the whole
point of the floor.

**Alternatives rejected.** *An ownership check on the `openspec/` tree* — in
scope if the tree looks like ours — needs no enrolment step and works on
existing repositories immediately, but it infers intent from shape, so a
vendored example that happens to match still blocks. It makes the failure rarer
without making it impossible, and the failure is silent for the person hit by
it. *A declared repository list* is auditable in one file but is state that
drifts: a new repository is ungated until someone remembers to add it, so it
fails open silently, which is the one posture the floor exists to remove.

The marker wins because enrolment is an act, not an inference. It also makes
`--check` honest — "not enrolled" is a fact it can report, where "does not look
like ours" is a guess.

**What it costs, named rather than discovered later.** Enrolment is a step, so
a repository that should be governed and is not enrolled is silently ungated —
the same failure the declared-list option was rejected for. The difference is
where it can be caught: enrolment happens at project initialisation, which is
already a deliberate act with an owner, and `--check` can name an unenrolled
repository that carries `openspec/`. That check is required, not optional; it is
what keeps the marker from becoming the drifting list under another name.

**Its owner is `init-project.sh`, and that amends the script's stated
contract.** Today its header promises it writes "exactly two things:
`openspec/`, and one instruction file ... No skills, no hooks, no host
configuration." A local git config key is none of those, but it is a third
write, so the header is wrong the moment enrolment lands. The contract is
amended deliberately — to two files and one local git config key — rather than
left to read as a guarantee the script no longer keeps. Recorded as task 2.8b.

## Decision 4 — the floor supersedes core's per-repository hook installer

`install.sh` calls `tools/install-core-git-hooks.sh` on every run, and that call
is what puts a `pre-commit` into whatever repository the installer happens to be
run from. Once the floor is bound machine-wide, that call is the collision
described in the risk table: the helper resolves its destination with
`git rev-parse --git-path hooks`, which honours `core.hooksPath`, so a globally
bound machine redirects it into the published directory.

### Alternatives considered

**A. Supersede: `install.sh` stops calling it.** *(chosen)*

The floor binder takes the helper's variable and its call site — one variable
for one variable, one call for one call. `install-core-git-hooks.sh` is not
deleted. It survives as **core's own tool**, invoked by core rather than by the
machine installer, and the refusal added in the `core-self-enforcement` delta
covers a by-hand run on a globally bound machine.

This is the right shape independent of the budget. Installing a *per-repository*
hook from the *machine-level* installer was always a category error: it wrote
into whichever repository the operator's shell happened to be sitting in, which
is not a property of the machine. The floor is the machine-level act; the local
hook is core's business.

**B. Retarget: keep both call sites.**

Rejected. It preserves the category error, keeps two surfaces writing hooks with
no arbitration between them, and grows the installer by roughly three lines
against zero headroom — so it also forces a budget raise, which A does not.

### The measured consequence

The installer is at **217** with a budget of 217. Under A the arithmetic is
217 → 217 and no raise is claimed. Under B it is 217 → ~220 and the escape
clause would have to be invoked. The budget did not decide this, but it is the
cheaper option on the axis the specification actually constrains.

### What A costs, and it is not nothing

Nothing then establishes core's own local binding. `install.sh` was doing it as
a side effect, and `core-self-enforcement` now *requires* core to carry a local
`core.hooksPath` and makes its absence a CI failure. The delta says core SHALL
have one; it does not say who creates it. That is a real gap this decision
opens, and it is recorded as task 3.5 rather than assumed to resolve itself.

## Decision 5 — the migration enrols before it removes, and never the reverse

Raised as 9.4 by codex and opencode independently in the second review round,
and it was the largest hole in the change. §3 removes the per-repository gate
copies. The published hook exits 0 without `agenticapps.workflow.enrolled`.
2.8b enrols only *future* projects, through `init-project.sh`. Composed, those
three take every repository that is gated **today** from gated to **silently
ungated at install time** — which is the precise failure this change was written
to eliminate.

### The population was wrong, and that changes the size of the problem

Re-measured 2026-08-07 by resolving each repository's hooks directory rather
than assuming `.git/hooks`. Nine repositories carry a gate `pre-commit`, and
they are not nine migration candidates:

| Repository | Bytes | Disposition |
|---|---|---|
| `agenticapps-workflow-core` | 1376 | core itself — keeps a **local** binding, tasks 3.3/3.5 |
| `claude-workflow` | 1201 | archived checkout, deleted wholesale by Phase 5b |
| `codex-workflow` | 5844 | archived checkout, deleted wholesale by Phase 5b |
| `opencode-workflow` | 2270 | archived checkout, deleted wholesale by Phase 5b |
| `agenticapps-dashboard` | 5844 | retired 2026-08-05 |
| `agenticapps-roadmap` | 1201 | retired 2026-08-08 |
| `agents-task-viewer` | 1201 | **live** |
| `callbot` | 1201 | **live** |
| `fx-signal-agent` | 1201 | **live** |

`fbc-platform` carries husky, not the gate, and is the one genuine opt-out.

**The live migration set is three repositories.** The six excluded are excluded
on a precedent this fleet already set: `fleet-carries-only-current` holds that
"cleaning a repository scheduled for deletion" is out of scope. Enrolling a
checkout that Phase 5b deletes is work whose only product is a config key in a
directory that will not exist.

`agenticapps-roadmap`'s retirement was decided by the operator and confirmed
2026-08-08. It was recorded nowhere — not in the family instruction file's
retired-repos section, not in its own ADRs — which is why the first census read
it as live off the machine's own evidence. That is this change's subject matter
appearing in its own working notes: a decision with no artifact is a decision
the next reader cannot find, and the census is a reader.

### The existing hook is evidence of enrolment, and is not enrolment

The tempting reading is that a repository carrying the gate has already opted
in, so the migration should simply translate the old representation of
enrolment — a file on disk — into the new one — a config key — and ask nobody.

**That reading is unsafe, and Decision 4 is why.** `install.sh` called
`install-core-git-hooks.sh` on *every* run, and that call wrote a `pre-commit`
into whichever repository the operator's shell happened to be sitting in. This
population is that category error's residue. Some of these nine were enrolled
deliberately and some were enrolled by standing in the wrong directory, and
**nothing on disk distinguishes them** — note that four of the live and
near-live repositories carry byte-identical 1201-byte copies, which is what a
run of drive-by installs looks like.

So carrying a hook is good evidence for *proposing* enrolment and is not itself
the act. Translating it silently would enshrine the accidents as policy, and do
it at the exact moment the change is claiming to make enrolment deliberate.

### The decision

The migration proposes, the operator accepts once, and removal is conditional:

1. The preflight names every repository carrying a gate copy, classified, with
   what will happen to each. This is the **same report** as task 2.9's — what
   the binding will newly govern, what publishing will replace (2.1a) and what
   will be enrolled belong in one acceptance, not three.
2. On acceptance, per repository, in this order: enrol → **verify the global
   binding actually governs it, by resolving its hooks directory rather than by
   inference** → then remove the local hook.
3. **A repository that is not enrolled does not have its hook removed.** Any
   step failing leaves the hook in place and is reported.

The invariant, stated so it can be tested rather than hoped for: **no repository
ends the migration with neither surface.** After it, each is enrolled and
governed by the floor, or still carrying its own hook, or explicitly declined
and reported. Never hook-removed-and-unenrolled.

The ordering is not cosmetic. Removing first and enrolling second leaves a
window where the repository has no gate at all, and a migration interrupted in
that window — a laptop closed, a terminal killed — leaves it there permanently
with nothing reporting it. Enrol-first's worst interruption leaves a repository
enrolled with a redundant local hook, which is the state it is already in today.

### Alternatives considered

**B. Two separate acts — the sweep removes only from already-enrolled
repositories.** Rejected, though it satisfies the invariant. It is the same
guarantee reached by leaving the operator four manual steps and a half-migrated
machine, and a migration that requires remembering is one that stops halfway.

**C. Translate the hook into a marker with no acceptance.** Rejected above: it
cannot tell a deliberate enrolment from a drive-by install, and it manufactures
consent at the moment the change is asserting consent is required.

**D. Leave the per-repository copies in place.** Rejected, and already rejected
in the risk table for a reason unchanged by this: with `core.hooksPath` set the
copies are inert, and an executable hook on disk that never runs is read by the
next person as the one that does.

### What this costs

The preflight grows a third thing to report and the sweep gains an ordering
constraint with a per-repository failure path. Both are real work, and both were
already implied by 2.9 and 3b.5 — this decision names them as one act rather
than three that have to agree with each other.

## Decision 6 — the binder establishes core's binding, because every other owner disclaims it

Closes 9.13's establisher half, 9.11 and 9.6. All three were measured on
2026-08-08 before being decided; two of the three findings understated what was
there.

### Core's binding has no owner because four correct boundaries meet

3.5 demanded a named artifact and was right to. Searching for one turns up four
candidates and every one of them **excludes this in its own text**:

| Candidate | Its own words |
|---|---|
| `install.sh` | Decision 4 removed exactly this — a machine installer writing hooks into whatever repository the shell stands in |
| `init-project.sh` | "No skills, no hooks, no host configuration, no CI workflow. Those are the machine's business" |
| `fresh-clone-needs-nothing` | a repository carries `openspec/` and one instruction file — "**Nothing else.** No skills, no hooks, no shims" |
| core's CI | detects the absence, which 3.5 already called a detector rather than an establisher |

That is not one oversight repeated four times. It is a hole produced by four
boundaries that are individually right, which is why naming an owner kept
failing: the honest answer is that nobody had the job, not that somebody had it
and forgot.

**So the binder takes it.** Setting the global binding *is* the moment core's
own hook stops being preferred, the binder is the only artifact that knows both
facts at once, and it runs from inside core's checkout by construction —
`SELF_DIR` is `reference-implementations/global-floor/`. It sets core's local
binding and its declaration first, and refuses to set the global one if that
fails.

*Alternative rejected: a fifth artifact owning only this.* Honest, and it makes
a one-line git config into a published script with a version marker, a test
suite and a place in the installer's inventory. The cost is not the line, it is
the surface.

**This is not Decision 4 returning.** Decision 4 forbade a machine installer
reaching into an arbitrary repository it happened to be standing in. This is the
binder repairing the single, known, deterministic casualty of its own act, in
the one repository it is by definition running from. Same shape as publish-then-
bind: the two orders are not symmetric and the safe one costs nothing.

### The sweep was never a no-op, and 3b.2 proved the wrong thing

3b.2 confirmed all five swept bindings equal `<common-dir>/hooks` exactly and
concluded "the sweep is a proven no-op". The measurement is right and the
conclusion does not survive the change that motivates it.

Unsetting a local binding that names the default directory is a no-op **while no
global binding exists**. That is the state 3b.2 measured — global `core.hooksPath`
is still unset on this machine today. The instant the floor is bound, those same
five unsets are what hand five repositories to it. That is the intent, and it is
the opposite of a no-op: the sweep is the mechanism, not a tidy-up beside it.

This matters beyond wording, because "provably a no-op" is the argument that
made writing to another repository's git config feel safe enough to need no
authorization boundary — which is 3b.5's open question, arrived at from the
other side.

### 9.6 was understated: the asymmetry is publish-file, bind-directory

The finding read as ownership-and-permissions not proving intent, which is true.
The sharper statement is structural: **the installer publishes one file and binds
a directory.** Git runs every entry it finds there by name, so a `pre-push` or
`commit-msg` nobody published becomes machine-wide the moment the binding lands,
and the existing guards cannot see it — they establish that no *other account*
could have written the directory, never that the operator meant its contents to
run on every commit.

The instance on this machine made the point better than the argument.
`~/.agenticapps/git-hooks/` held one file, dated 2026-07-25: a 46-line
`pre-commit` vendored from `opencode-workflow` — an archived repository — with no
version marker, exporting `OPENSPEC_GATE_SELF=opencode` and describing the
pre-2.0.0 rule in which `REVIEWS.md` blocks. Publishing replaces it, because
unmarked reads as 0.0.0 and the floor is 1.1.0, so that entry self-heals. Had it
been named `pre-push` it would have run unchallenged on every commit on the
machine, under an archived host's identity and a rule retired at gate 2.0.0.

It is also a fifth instance of the pattern the fleet keeps hitting: a **copy**,
not a symlink, so every sweep scoped to symlinks walked straight past it.

### 9.11 is fixed by amending the requirement, not by an exception

The durable `core-self-enforcement` requirement mandates three interposition
points and names the first as "a `PreToolUse` hook registered in
`.claude/settings.json`" — which this change deletes. codex called it HIGH and
offered two routes: a core-only exception, or amend every affected requirement.

*Exception rejected.* A core-only carve-out would say core keeps a hook the same
change removes everywhere else, which inverts what core is for: core gates
itself with the bytes it ships, so it should be the *first* repository to live
under the floor, not the one exempted from it.

So the requirement is amended: two interposition points core owns —
`pre-commit` and CI — and the floor for everything else. The amendment carries
the cost rather than netting it out. The removed hook gated an edit before it
was written, regardless of commit flags; both remaining local points are
commit-time and `--no-verify` bypasses one. Core keeps CI so core is the
best-covered case, which is precisely why the sentence has to name what a
repository *without* CI is left with — that is 9.8, and this is where the
honest version of it goes.

## Decision 7 — the migration set is named, and discovery is unnecessary

Closes 9.10 and 3b.5, which are the same finding raised twice. Decided
2026-08-08, after measuring the whole of `~/Sourcecode` rather than reasoning
about it.

Decision 6 left this open in as many words: "provably a no-op" was the argument
that made writing to another repository's git config feel safe enough to need no
authorization boundary. Take that argument away and the boundary is owed. This
is it.

### Discovery is not deferred, it is unnecessary

The tempting reading of 9.10 is that repository discovery is a hard problem the
change keeps postponing. It is not a hard problem. It is a problem the change
already dissolved and did not notice.

**Enrolment is itself the consent.** The floor governs only enrolled
repositories, and enrolling is a deliberate act performed inside the repository
it applies to. So the binding owes no separate consent for a repository that
already enrolled — it delivers exactly what that repository asked for. What the
preflight owes is the set this run will **newly** enrol, and that set is the one
it was handed. Nothing needs to be searched for.

A walk would therefore search the machine to reconstruct a list the binder has
in a variable. That is not merely wasteful; it is the drifting-declared-list
failure 2.8 rejected, arriving through the filesystem instead of through a file.

**The first draft of this decision claimed more than that and was wrong.** It
said the binder "already holds the complete set of repositories a new binding
will newly govern". codex refuted it: `init-project.sh` is an independent
enrolment source, so a repository enrolled last month becomes governed the moment
the binding lands, without appearing in any report and without being named. The
census showing zero enrolled repositories is a measurement of today, not an
invariant, and a decision that rests on it expires silently the first time
someone runs `init-project.sh`.

The correction is to separate two sets the draft had merged. The **mutation
set** is what this run will enrol, sweep and strip — named, reported, accepted.
The **impact set** is every repository the binding governs, which is the mutation
set plus everything enrolled earlier. The preflight speaks only to the first and
says so. The second needs no acceptance precisely because enrolment already was
one, and `--check` is where an operator goes to enumerate it — which is the half
of 9.10 this decision deliberately leaves open, and it is no coincidence that the
half needing enumeration is the read-only one.

### The measurement is what settles it

`~/Sourcecode` was walked on 2026-08-08: **61 repositories**, of which seven
carry a gate `pre-commit` and **none is enrolled**. Reducing 61 to the migration
set of three took four judgements, and not one of them is a property of any file
on disk:

| Judgement | Where the answer actually lives |
|---|---|
| archived vs live | GitHub's archived flag, and a family instruction file |
| husky vs our gate | `fbc-platform`'s `.husky/_` is a deliberate opt-out |
| deliberate binding vs drive-by install | nothing on disk separates them — the delta says so already |
| retired checkout vs current | `fleet-carries-only-current`'s precedent |

A walk can find seven hooks. It cannot make one of those four calls, so it would
hand back seven candidates and require the operator to classify them anyway —
having first read 61 repositories to do it. Naming three is the same act with
the search removed.

### What the census corrected in the ordering

The delta's order is enrol → verify → remove. Measurement showed that is
incomplete for two of the three: `callbot` and `fx-signal-agent` each carry a
local `core.hooksPath` naming their own default hooks directory. Git prefers the
local binding, so the verification step — resolve the repository's hooks
directory and confirm the floor governs it — **fails for two of three** unless
the redundant binding is swept first.

So §3b's sweep is not a tidy-up running beside the migration but a step inside
it. This is the second time in this change that treating the sweep as cosmetic
produced a wrong ordering; Decision 6 caught the first.

**Where the sweep goes in that order took a second correction, and both
reviewers caught it independently.** The draft said sweep → enrol → verify →
remove, reasoning that the verification cannot pass while a local binding still
wins. True, and it built the exact window this requirement exists to forbid:
sweeping an unenrolled repository hands it to the global dispatcher, whose first
act is to exit 0 because the marker is absent. Between the sweep and the
enrolment the repository has a hook file, a global binding, and no enforcement —
and an interruption inside that window leaves it there permanently.

The order is **enrol → sweep → verify → remove**. Enrolment is inert while the
local binding stands, because the repository is still gated by its own hook and
that hook predates the enrolment predicate and never consults it. So the marker
costs nothing until the sweep makes it load-bearing, and the repository is gated
at every instant: by its own hook before the sweep, by the floor after it.

That the failure is the same one this requirement already forbids — reached
through the binding instead of through the file — is the part worth keeping. The
requirement was written against remove-before-enrol and the draft reintroduced it
in a form the words did not literally cover. Two vendors found it independently
before any code existed, which is the whole argument for step 2b in one example.

Removal stays last. The state the delta forbids — removed-and-unenrolled, gating
nothing — is unreachable when removal is the final act on a repository processed
to completion before the next one begins.

### The four questions 3b.5 asked, answered without inventing policy

| 3b.5 asks | Answer |
|---|---|
| What set is walked? | None. The set is given by name. |
| Who authorises writing to another repository's config? | The operator, twice: by naming the path, and by accepting a preflight that says what will happen to it |
| What happens on partial failure? | That repository keeps its hook and is reported; the run continues to the next |
| Is there a dry-run? | The preflight **is** the dry-run — every act is printed before the single acceptance |

### One report, one acceptance

This is 9.4a's substance. What the binding will newly govern, what publishing
will replace (2.1a) and what will be migrated are one report under one
acceptance, rather than three acceptances that have to agree with each other.
Three prompts asking about the same act is how an operator learns to answer
`y` without reading, which is the failure the per-entry inventory in 9.6 was
written to avoid — and it would be undone by re-introducing it one level up.

Refusing refuses everything downstream of it: nothing is published into the
hooks directory, `core.hooksPath` is not set, and no repository is touched. The
binder already takes exactly this posture for an unaccepted entry in the hooks
directory.

The guarantee is scoped rather than absolute, and codex was right to press on
it. "Declining leaves the machine untouched" is a promise the binder cannot
keep: `install.sh` publishes its payload before it ever reaches the binder, so a
decline at the preflight leaves that payload published. Either the preflight
moves to the top of the installer, ahead of every mutation, or the guarantee
names what it actually covers. The second is the honest one and the smaller
change, and it keeps the acceptance next to the acts it authorises instead of
asking an operator to consent to a hook migration before the installer has
established there is an installer.

### What naming a repository does and does not establish

Three consequences the draft left implicit, each of which is the same mistake in
a different place: treating an operator's input as evidence about the disk.

**A typed path is not an identity.** Names are canonicalised, rejected without
writes if they do not resolve to the top of a repository, and deduplicated by git
common directory — otherwise a relative path and a symlink to the same repository
are two entries and it is processed twice.

**A checkout is not a repository.** Linked worktrees share one common directory,
so they share one local configuration and one hooks directory. Naming any of them
acts on all of them, which makes "a repository it was not given is left entirely
alone" false for an unnamed sibling unless the preflight reports the worktrees it
touches. This change already resolves core's own hooks directory through
`--git-common-dir` for the neighbouring reason; the migration owes the same care.

**A path is not evidence about the hook at the end of it.** Naming a repository
says the operator believes it carries our gate; it does not establish that the
`pre-commit` there is ours rather than something they wrote. Removing it on the
strength of a generic acceptance would delete an operator's own hook. So
recognition comes from the file, and an absent, foreign or ambiguous hook refuses
that repository without writes — which is 10.7's finding, one level down: a
file's location proves who *could* have written it, never who did.

### What is deliberately still open

`--check`'s "names any repository the floor cannot reach" is the other half of
9.10 and this does **not** close it. `--check` is read-only and reports about a
machine rather than acting on one, so a declared root is defensible there in a
way it is not here. It is called out rather than folded in, because answering
half a finding and marking the whole thing closed is how the other half
disappears.

## Decision 8 — the fleet's gate copies are unmarked, so the repository adopts its own

Found 2026-08-08 by running the binder against the migration set for the first
time and declining its preflight. It refused all three, and every earlier
measurement in this change had missed why.

### The measurement that was taken, and the one that mattered

Task 0.3a classified nine gate copies by **byte size**, noted "five
byte-identical 1201-byte copies", and drew the right conclusion about drive-by
installs from it. What it never asked is whether any of them carries the
ownership marker the removal predicate actually tests. None of the live three
does. All three are byte-identical to `claude-workflow/bin/git-hooks/pre-commit`
— md5 `3c871ab36f01f6fed650417fcecec23a` — whose own header documents its
installation as `install -m 0755 bin/git-hooks/pre-commit`, a **host** repository
path. Core's history has never contained that file.

So the four sizes are not one installer drifting. They are four installers:
1201 from `claude-workflow`, 2270 from `opencode-workflow`, 5844 from
`codex-workflow`, 1376 from core. Core's is the only one carrying core's marker,
and core's is the only one excluded from the migration set by ADR-0028.

The consequence is total rather than partial. `install-core-git-hooks.sh`
refuses an existing unmarked hook at line 219, and the migration refuses to
remove one; the two refusals share a rule, so a repository in this shape can
neither be brought up to a marked hook nor migrated off the one it has. **Every
repository this change exists to migrate is unreachable by every tool this
change ships.** The census could not have caught it, because it was measuring
files and the predicate is about provenance.

### Both refusals are right, which is what makes this a design gap

The tempting fix is to loosen recognition — accept a hook that "looks like the
gate", or hash-pin the three host vintages. Decision 5 already rejected the first
and the security pass already rejected the reasoning behind the second: a
comment cannot establish who wrote a file, and a file's location proves who could
have written it and never who did. Nothing about these hooks changed those
arguments. What changed is the discovery that the predicate has no true positives
in the fleet — it answers *who wrote this*, the migration needs *may this be
removed*, and for a host-installed fleet the file cannot answer either.

The evidence the file cannot supply is the operator's. Decision 5 already said
so in the general case — "carrying a hook is good evidence for proposing
enrolment and is not itself the act" — and left the act as a single acceptance of
the preflight. This decision says where the act is written down for a hook whose
provenance is unrecorded.

### The decision

The repository adopts its own hook, by carrying `agenticapps.hooksadopt` in its
local git configuration **set to the SHA-256 digest of the hook being adopted**.
The migration removes an unmarked `pre-commit` only from a repository whose
adoption matches the file in front of it.

**The digest, rather than a boolean, because a boolean is a standing licence.**
`hooksadopt=true` authorises deleting whatever occupies that path whenever the
migration next runs — including a hook written after the operator adopted, by
somebody else, for another purpose. The requirement's title says "a gate copy
this workflow did not write" and a boolean predicate cannot mean that; it means
"an unmarked regular file, plus a key". The digest makes the assertion be about
the artifact the operator actually read, and expires it by construction: change
the file and the adoption stops matching. It is also what closes the substitution
window between the preflight and the delete, which the marked path already closes
by re-recognising the marker there.

This is not alternative B arriving through the back door. B has core recognise
other repositories' files by a checksum list core maintains; here the checksum is
supplied by the operator, for one repository, about a file they read — the
difference between core deciding what counts as its own and an operator saying
what they consent to lose.

**Not a command-line flag, and the honest reason is scope rather than quoting.**
An earlier draft argued that a flag "cannot be made safe because a list is
shell-expanded", and a reviewer correctly pointed out that path arguments are
shell-expanded too and that the `GLOBAL_FLOOR_ACCEPT='*'` incident was unquoted
expansion inside the script rather than a property of command lines. The
argument that survives is different: an assertion written into the subject
repository is scoped to one repository by where it lives, outlives the command
that acted on it, and can be audited later by reading that repository. A list
passed to one invocation has none of those properties, and the value of this
particular consent is precisely that it persists and can be checked afterwards.
The `GLOBAL_FLOOR_ACCEPT` incident is still worth remembering here, as a reason
to distrust acceptance lists that arrive through a shell — not as proof that a
flag could not have been written correctly.

It also inverts a mechanism this change already has. `agenticapps.hooksbinding=
declared` protects a repository's local binding from the sweep; adoption exposes
one repository's hook to removal. Same placement, same strictness about the
value, opposite direction — which is a good sign the placement is the natural
one rather than a convenience.

**Adoption widens one predicate.** It does not enrol, does not sweep, does not
replace the preflight or its acceptance, and does not relax the refusals that
exist because the report cannot name what the delete would reach — a symlinked
hook, a symlinked hooks directory, a missing file. Those are about the operator
accepting a path and the removal landing elsewhere, and an assertion about
ownership says nothing about that.

### Alternatives considered

**B. Hash-pin the three known host vintages.** Rejected. It works today and the
list is closed only because the host repos are scheduled for deletion, so its
correctness rests on a schedule rather than on an argument. A fourth vintage on
any other machine — or a host repo that ships one more revision before it goes —
walks into the same wall with nothing to say. It also puts core in the business
of recognising other repositories' files by checksum, which is the "translate the
hook unasked" move Decision 5 refused, reached by a different road.

**C. Remove the three hooks by hand and bind with no arguments.** Rejected as
the change's own subject matter: an act performed outside the tool built for it,
leaving no artifact and no repeatable path, at the moment the change is asserting
that enforcement should stop depending on somebody remembering.

**D. Drop the three from the migration set.** Rejected. They are not host
repositories and no deletion schedule covers them; excluding them would leave the
change with an empty migration set and the fleet on per-repository copies, which
is the state it was written to end.

### The refusal that displaces what it protects

Found in the same review round, and it is #91's blind spot one set out. A
repository refused at the preflight is never enrolled, because refusal happens
before the enrolment pass. The run then publishes, binds, and exits reporting
that each refused repository "keeps the hook it already had" — which is true only
while `.git/hooks/` is still consulted. For a refused repository with no local
`core.hooksPath`, the binding is exactly what stops it being consulted, and the
dispatcher exits 0 for want of an enrolment marker. **Neither surface, and a
report that says the opposite.**

#91 closed this displacement for the repositories the run migrates. It never
asked about the ones the run declines, and the answer is not the same: a migrated
repository is enrolled before the binding lands, and a refused one is enrolled
never.

So a preflight refusal for a repository with no local binding stops the run
before anything is published or bound. Acting at the preflight costs nothing —
that is what a preflight is — and the alternative is binding a machine while
knowing that a repository the operator named goes silently ungated as a result.
A refused repository that carries a local binding is not displaced and does not
stop anything.

The same reasoning applies to repositories nobody named, and there the answer has
to be different: naming them needs the search Decision 7 removed. What was
actually wrong there was a claim rather than a behaviour — the delta said an
unnamed repository "remains gated by the hook it already carries", which is false
for any that sets no local binding. The claim is corrected and `--check` is named
as where the machine-wide report belongs. A false reassurance is worse than an
acknowledged gap, and this change had written one down.

### What this costs

One predicate, one preflight line that distinguishes the two removals, one abort
path, and a setup step the operator performs once per repository. The migration
set is three, so the cost is three commands, each of which is the operator saying
the thing the file cannot — and the binder's own refusal prints each one,
digest included, for the repository it just read.

## The question this change refuses to answer by implication

`host-neutral-instruction-files` requires a project's `AGENTS.md` to carry
exactly one workflow section whenever an agent is provisioned, and calls a repo
that lists an agent without one "broken: its agents are pointed at a workflow
the file does not describe".

If the trigger skill carries the workflow, is globally installed, and
self-activates, that premise is weaker than when it was written — the agents are
pointed at a workflow the *skill* describes.

This change does not touch that requirement. Repealing a requirement as a
side effect of a change about hooks is how a rule disappears without anyone
deciding it should. It is named here as the most likely next change, and it
needs its own evidence: whether the skill actually loads on every host, and what
a project file is for once behaviour lives elsewhere.

The counter-evidence this section used to cite has since been overtaken, and the
correction matters in both directions. It read: *the skill that loaded in this
very session was the 402-line copy from an archived checkout, not core's
235-line v4.0.0*. That was true when written. It is **false as of 2026-08-07**:
`~/.claude/skills/agentic-apps-workflow` now resolves to core's v4.0.0, the
hyphenless 402-line duplicate no longer exists on this machine, and
`fresh-clone-needs-nothing` fixed it — `LEGACY_DIRS` in `install.sh` removes the
copied duplicate, and the sweep rebinds the archived link.

So the delivery risk was real and is now closed on this machine. What it does
**not** license is repealing the requirement by implication, and the reason has
changed rather than disappeared: one machine resolving correctly after a
targeted fix is evidence about one machine, not about skill resolution as a
delivery mechanism. Open question 9.7 records that `scan_archived` walks skill
directories only and structurally cannot see command directories — two links
into an archived checkout survived every install that way. The deferral
therefore stands on its original grounds, with its evidence bar unchanged:
whether the skill actually loads on every host, and what a project file is for
once behaviour lives elsewhere.

## Risks

| Risk | Mitigation |
|---|---|
| A repo adopts husky and the global path silently disables it | Already the case in `fbc-platform`, and already handled: husky sets a local `core.hooksPath`, which git prefers over the global one. `--check` reports the effective binding per repository so the opt-out is visible rather than inferred |
| A repository leaves the floor by accident, via a local `core.hooksPath` nothing reports | The more likely failure and already true in six repositories. Five are redundant and are unset by the sweep; `--check` names any repository the floor cannot reach |
| Core's own git-hook installer collides with the global binding | `tools/install-core-git-hooks.sh` resolves via `git rev-parse --git-path hooks`, which honors `core.hooksPath` — so once bound globally it writes into the machine-level directory, either refusing forever on a foreign marker or publishing core's working-tree-resolving hook to every repository. **Decision 4 removes the collision at its source: `install.sh` no longer calls it**, so the machine installer never triggers the redirect. The `core-self-enforcement` delta's refusal — destination outside the git *common* directory — covers a by-hand run on a bound machine, which is now the only way to reach it |
| Nothing establishes core's local binding once the installer stops calling the helper | Opened by Decision 4 and tracked as task 3.5. `core-self-enforcement` requires the binding and makes its absence a CI failure, so the gap is loud rather than silent — but it is unassigned until 3.5 names an owner |
| An operator has a global `core.hooksPath` already set to something else | The installer refuses to overwrite a foreign binding and reports it, the same posture `install-core-git-hooks.sh` already takes toward a foreign hook |
| Removing the host hook is felt as "the workflow got weaker" | It is weaker in latency and identical in enforcement. `--check` and the run summary should say which surfaces are active rather than leaving it to be inferred |
| Nine stale per-repository gate copies remain — 10 distinct hooks directories, less `fbc-platform`'s husky | They become **inert**, not competing — verified: with `core.hooksPath` set, `.git/hooks/` is not consulted at all. They are still removed, because an executable hook on disk that never runs is read by the next person as the one that does |
