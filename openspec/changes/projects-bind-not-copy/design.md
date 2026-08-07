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
- Touching `install.sh`. Its budget, modes and tests are untouched.
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
