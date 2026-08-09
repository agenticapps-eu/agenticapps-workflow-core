## Context

`core-installer-one-entry-point` bound `skills/*` into all five host directories
on 2026-08-06 and was archived the same day. The measurement that motivates this
change was taken **after** that archive, which is why it is a separate change and
not a defect in that one: the installer did exactly what its specification said,
and its specification said nothing about projects.

Eight repositories hold `.claude/skills/agentic-apps-workflow/` as a committed
directory. Four byte-sizes (324, 331, 346, 415), two claimed versions (3.0.0 and
3.2.0), and three of the four v3.2.0 copies are byte-identical while
`fbc-platform`'s is not. Core publishes 235 lines at v4.0.0.

Each of those repositories also holds six `openspec-*` skills. Those are upstream
OpenSpec's — MIT, `compatibility: Requires openspec CLI`, installed per-project
by that tool, and they implement the `/opsx:*` commands this proposal was written
with. They are not in scope, and saying so explicitly is load-bearing: a check
that removed "vendored skills" without that distinction would break every repo's
planning commands.

## Goals / Non-Goals

**Goals:**

- One trigger skill on this machine, resolved the same way from every directory.
- A rule with a home, so the condition cannot return quietly.
- A check whose expected set is declared rather than discovered.

**Non-Goals:**

- Reviving `--project`. `one-enforcement-floor` superseded it and this change
  does not need it: removing a copy needs no installer.
- ~~Touching `install.sh`. Its budget, modes and tests are untouched.~~
  **No longer a non-goal, as of 2026-08-09.** Retiring the project-hook
  publisher unwires `install.sh`'s delegation to it (task 3.13d) and removes the
  project-hook cases from `tools/install.test.sh` (3.13e), so the installer
  contract does change and this change owns that. Its budget and its modes are
  still not touched, and the four shared artifacts publish exactly as before
  through a different helper.
- The `openspec-*` skills, per the Context.
- Deciding what a *new* project does at creation time. That is a bootstrapping
  question, and the capability window `core-installer-one-entry-point` opened is
  still open. This change is about the eight that exist.

## Decisions

### Delete the copies; do not replace them with symlinks

A project could bind to core the way a host does — a symlink from
`.claude/skills/agentic-apps-workflow` into the checkout. Rejected: it is a
second binding of the same skill on the same machine, so it doubles the surface
that has to stay correct and buys nothing the host binding does not already
provide. Every host reads a directory the installer binds, so every project on
this machine already resolves v4.0.0 the moment its own copy is gone.

*Alternative rejected: keep a copy but attest it.* Generate the project copy from
core and have a check compare bytes, the way published artifacts are attested.
This is the most defensible version of copying, and it is still copying: it makes
drift *detectable* rather than impossible, and it needs a generator, a manifest
and a refresh step — three artifacts to preserve a file nobody needs.

*Alternative rejected: leave them and document the precedence.* Cheapest, and it
loses the property the whole payload change was for. Eight repositories would
keep running v3.2.0 while every other directory on the machine runs v4.0.0, and
the difference would show up as behaviour nobody could explain.

### The load-bearing assumption, stated because it decides the design

**This workflow runs on one machine.** No other machine has it. That is what
makes deletion safe: the host binding covers every directory here, so a project
with no copy is a project that resolves core's skill.

If that stops being true — a teammate clones `cparx` on a machine with no
install — the deleted copy is the only thing that would have given them the
workflow, and they get nothing. That is the real cost of this decision and it
should be paid deliberately, not discovered. The answer at that point is a
bootstrapping story for a fresh machine, which is the capability window already
open; it is not a copy checked into eight repositories.

### One rule, two surfaces, because the second was found by asking about the first

The change began as the skill copies. Donald's question — *aren't the other hooks
in cparx wrong too?* — is what surfaced the hook half, and the answer is yes, on a
delay: `normalize-claude-md` is declared on `main` and undeclared the moment PR
#87 merges, at which point six repositories bind a hook the fleet does not name
and the implementation keeps running because manifest rows outside the declared
set are carried forward by design.

Keeping these in one change is deliberate. They are the same sentence — *a
project holds what core does not sanction* — and they are fixed by the same two
things: a sweep across the same eight repositories, and a check that walks the
direction the existing checks do not. Splitting them means two sweeps over the
same `.claude/` directories and two checks that each answer half the question.

*Alternative rejected: put the hook half in PR #87.* It is the change that
creates the orphan, so there is a real argument that it should clean up after
itself. Rejected because #87 is a narrow retirement that has already been
reviewed, and adding a six-repository sweep to it turns it into a fleet change
and discards that review. The sequencing constraint carries the same guarantee at
a fraction of the cost: #87 does not merge first.

### `database-sentinel` is removed, and the alternatives are on the record

Decided 2026-08-07, after both plan reviewers found the change claiming to have
decided and stating nothing.

**A. Remove it with the surface.** *(chosen)*

**B. Keep it, and accept the surface stays open for one hook.** This has the
better security argument and it is worth writing down properly, because it is
not a weak one. The `DROP TABLE` / `TRUNCATE` / `DELETE`-without-`WHERE` arms
intercept an **irreversible** action, and the standard justification for
deleting a host hook — "the condition is caught again at `git commit` and in
CI" — is *false* here. Destructive SQL never enters git. Removing these arms
removes the only such interception in the workflow and nothing downstream
replaces it.

Rejected on reach. The hook fires from `.claude/settings.json`, so it protects
Claude sessions and nothing else; codex, opencode, pi and omp get none of it.
Multi-agent is a permanent condition, not a phase, so a guard covering one host
of five is not a floor — it is a floor-shaped thing in one room. Keeping it also
means this change closes a surface and then leaves it open, which is the kind of
exception that is remembered as a rule.

The hook's own header declines the credit that argument B would need: *"THIS IS
NOT a security boundary… `psql -f script.sql` never presents the SQL to the
regex… a speed bump, not a control."* A speed bump for one of five hosts does
not buy an exception to the rule this change exists to state.

**C. Keep only the destructive-SQL arms, drop the `.env` arm.** The `.env` arm
is the weakest of the three — it matches `Edit`/`Write`/`MultiEdit` on a path,
and the likeliest way an agent writes that file is `cat > .env` through `Bash`,
which presents no `file_path` at all. What it does catch is also found by
`cso`'s secrets archaeology and intercepted by the host's permission prompts.

Rejected, but only on the same reach argument as B — a narrower host-specific
hook is still a host-specific hook. Worth recording that it was the strongest
compromise, because if the reach problem is ever solved (a hook surface every
host reads), C is where to restart rather than B.

**What replaces it.** Nothing, inside this workflow, and the change says so
plainly rather than implying continuity. The destructive-SQL protection is
reassigned to the host's own permission layer — a Bash deny rule in the
operator's configuration. That is host-specific by nature, which is precisely
why it belongs to the operator and not to core: core cannot ship it without
reacquiring the property this change removes.

**A consequence that improves the check.** `SHIMMED-HOOKS` held two names.
Removing `database-sentinel` while this change removes `openspec-change-gate`'s
project binding leaves it **empty**, which dissolves the objection raised
against the second pass — that `OPT-OUTS` sanctions a *missing* binding and has
no axis for an *extra* one, so a retained hook would fail the both-directions
check forever with no way to record it as intended. An empty declaration needs
no sanctioned exceptions, and the reverse pass becomes a flat rule: a project
binds no fleet hook at all.

### The check declares its fleet, and `FLEET` is the declaration

`reference-implementations/project-hooks/FLEET` already names seven of the eight
repositories and exists precisely because "a repository MISSING from those lists
was indistinguishable from one that passed". Reusing it means one declaration to
maintain rather than two that drift apart.

`agenticapps-dashboard-add-agent-board` is not in `FLEET` and is a worktree of a
retired repository. **A worktree is not a fleet member**; it resolves to the same
repository, and adding it would make the declaration a list of directories rather
than a list of repositories. Its copy is v3.0.0, the oldest on the machine, and
it is reachable only through a checkout of a repo that is already retired.

### The retired repository gets the same treatment as the others

`agenticapps-dashboard` was retired on 2026-08-05, and its `CLAUDE.md` says
reading it is "fine and encouraged" because its `openspec/specs/` are a good
example of the discipline. A repository people are told to read is a repository
an agent will open, and an agent that opens it loads its skills. Retirement
removed it from the roadmap, not from the loader.

*Alternative rejected: skip it as not worth a PR.* That is how the condition
comes back — one exception, defensible on its own, and the check then needs a
suppression list, and a suppression list is where the next copy hides.

### Sequencing: this change depends on a binding that already landed

The removals are only safe because the hosts are bound. If
`core-installer-one-entry-point` were reverted, deleting these copies would leave
eight repositories with no workflow skill at all rather than an old one. The
dependency runs one way and it is already satisfied on this machine, but the
change that carries these removals SHALL NOT merge before the branch carrying
that binding does.

### The publisher is retired and the checker is kept, because only one lost its subject

Removing `database-sentinel` empties `ARTIFACTS`, and `ARTIFACTS` is the whole
input to `install-project-hooks.sh`. That is a subsystem losing its subject, not
a declaration losing a row, and task 3.9b stopped rather than assume which way it
went.

**What settles it is which files still have a reader — and the honest answer is
narrower than an earlier revision of this section claimed.** That revision said
the bind half is "driven by live code that landed on `main` in PR #94", which
overstates it. `check-shims.sh` does read `SHIMMED-HOOKS`, `FLEET`, `OPT-OUTS`
and `shim-template.sh`, and does exit 65 without the template. But its only loop
iterates the declaration, and with the declaration empty that loop never
executes: **it currently walks every repository, examines nothing, and says so.**
Its reverse pass — the one that asks what a repository *holds* — is specified in
tasks 2b.1–2b.5 and all five are open. So the bind half is live code that checks
nothing yet.

The distinction from the publish half survives that correction, because it was
never really about current readers:

| Half | Reader today | Reader planned |
|---|---|---|
| publish | none — `install-project-hooks.sh:122` dies *"no artifacts to publish"* on an empty declaration, verified by running it against a comments-only `ARTIFACTS`, and its only caller is `install.sh:25` | none — no task in this change or any other proposes a future project-hook artifact, and the host-neutrality rule this change adds makes one unlikely |
| bind / check | none — the forward pass is vacuous by design since 2b.6 | tasks 2b.1–2b.5, open, which read all four declaration files and the template |

Keeping the bind half is therefore a bet on 2b.1–2b.5 landing, stated as such
rather than dressed up as a claim that it checks something today. Deleting it
would mean deleting the inputs to a pass this same change specifies and has not
yet built.

**The manifest decided it.** The publisher's reason to exist is the attestation
it writes, and three measurements taken 2026-08-09 say that attestation has no
consumer and one false claim:

1. `~/.agenticapps/manifest.tsv` is read by `tools/install.test.sh` and by
   nothing else in the repository. `resolve-core-artifact.sh` reads a
   *different* file — `core-vendor.manifest`, keyed `core_repo=` /
   `core_commit=` — which this subsystem does not write.
2. `install-shared-artifact.sh`, which survives and publishes the four shared
   artifacts, writes no manifest and computes no digest. So the provenance the
   capability demands is produced for the one artifact being deleted and for
   none of the four being kept.
3. The manifest carries rows forward for artifacts a run does not touch —
   `install-project-hooks.sh:215-224`, correctly, so that a partial run does not
   look like a fresh install of a smaller set — and nothing ever expires them.
   Rewritten in full at 22:58 on 2026-08-08, it attested
   `normalize-claude-md.sh 1.0.1` with a digest, for a path holding no file.

A drift instrument whose only reader is its own test, whose surviving row is
false, and which covers none of the artifacts that remain, is not evidence. It
is deleted rather than repaired, and the machine copy goes with it: this change
removes `~/.agenticapps/bin/database-sentinel.sh` and `~/.agenticapps/manifest.tsv`
outright. Leaving a published executable nothing runs is the shape already
rejected for husky in `fbc-platform` — an installed-but-unbound hook is an
executable that never fires, and keeping it costs the same confusion for none of
the protection.

**The alternative was to keep the machinery dormant** — delete only the
implementation and leave `ARTIFACTS` empty, the way `SHIMMED-HOOKS` was left. It
is rejected because the two cases differ in exactly the way that matters:
`SHIMMED-HOOKS` empty is *read* by a live checker and means something ("no
project binds a fleet hook"), whereas `ARTIFACTS` empty is read by an installer
that refuses to run, and means nothing to anybody. An empty declaration earns its
keep when something asks it a question.

## Risks / Trade-offs

- **Eight PRs across two families.** Cross-family work is explicit in the
  proposal because the family rule requires it. The removals are mechanical and
  the risk is in the count, not the content — a partial sweep leaves the fleet in
  a state where "did we do this" is unanswerable, which is what the declared
  check is for.
- **The precedence claim is inferred, not measured.** This change asserts a
  project-local skill resolves ahead of a host-level one. That is the behaviour
  every loader documents and it is why the copies matter, but it has not been
  observed on this machine for this pair. **Task 1 measures it before anything is
  deleted**, because if the host copy wins, these eight copies are inert and the
  urgency — though not the argument for removing them — evaporates.
- **`fbc-platform`'s copy differs from its siblings and nobody knows why.** It may
  carry a local edit worth keeping. Deleting it without reading the diff would
  discard a change someone made on purpose; the tasks read it first and record
  what was in it.
- **A repository could reintroduce a copy** between the sweep and the check
  landing. The check is the answer, so it lands in the same change rather than
  after it.
- **Retiring the publisher removes durable installation provenance — and NOT
  drift detection, which an earlier revision of this paragraph got wrong.** It
  claimed a hand-edited `~/.agenticapps/bin/openspec-change-gate.sh` would be
  undetectable by any tool in this repository. That is false, and a round-2
  reviewer caught it: `install.sh`'s `check_artifact()` runs `cmp -s` against the
  checkout *before* it looks at any version, and reports `MODIFIED — same version
  as checkout, different bytes, not current` by name. Byte drift of every
  surviving artifact is detected today and continues to be.

  What is actually lost is narrower and worth stating precisely: a **record of
  what was installed, when, and with what hash, independent of the checkout.**
  `check_artifact` answers "does this match the checkout *as it stands now*",
  so if the checkout moves, the answer moves with it and no history says what was
  on the machine yesterday. The manifest was that record. It is accepted as a
  loss because the record covered exactly one artifact — the hook being deleted —
  and none of the four that survive, so what disappears is a property the fleet
  was described as having for artifacts it never had it for. Giving the surviving
  artifacts real provenance is a separate change against
  `install-shared-artifact.sh`, and this change does not pretend to have done it.
- **A future fleet-shared project hook would need the publisher rebuilt.** The
  code is recoverable from this change's archive, and the requirements with it.
  The judgement is that rebuilding from an archived, working implementation costs
  less than carrying a subsystem whose declaration no code reads — and that the
  cost falls only if such a hook ever appears, which the host-neutrality rule now
  makes unlikely.
