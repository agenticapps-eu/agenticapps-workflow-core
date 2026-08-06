## Context

Four host repos each carried an installer. All four are archived. What survives
is skill bindings pointing into those checkouts, and no command that installs
the workflow or reports a machine's state.

The host facts were measured in an earlier session; three were confirmed then
and two were recorded as unknown. Both unknowns are now resolved, from each
host's own documentation and shipped code:

| host | skill dir | hook wiring |
|---|---|---|
| claude | `~/.claude/skills` | `~/.claude/settings.json`, `PreToolUse` |
| codex | `~/.codex/skills` | `~/.codex/hooks.json`, via an adapter |
| opencode | `~/.config/opencode/skills` (plural; `skill/` also exists and is not the one) | `~/.config/opencode/plugin/openspec-change-gate.ts` |
| pi | `~/.agents/skills` | none this change — surface exists, unmeasured |
| omp | `~/.agents/skills` | none this change |

**pi** reads `~/.pi/agent/skills/` *and* `~/.agents/skills/` (`docs/skills.md`,
"Locations"). The earlier session looked for `~/.pi/skills`, which is not a path
pi uses, and concluded pi had no skill directory.

**omp** is `@oh-my-pi`, a pi fork. Its skill providers include one described in
its own shipped code as *"Load skills from `.agent/skills` and `.agents/skills`
(project walk-up + user home)"*, and a second, separate provider that loads
`~/.claude/skills`. So omp already sees anything installed for claude.

The consequence is that **five hosts need four directories**, and the one that
covers both remaining hosts is `~/.agents/skills` — a path with no host name in
it, which already exists on this machine.

The previous session's failure was building a scoring instrument around a
fifteen-line behaviour change. The budget — 200 executable lines — exists to
make that failure mode visible while it is happening rather than after.

## What the first draft got wrong

This design was reviewed by gemini and codex before any code was written. Both
returned REQUEST-CHANGES, and the findings were verified against files in this
repository rather than accepted on the reviewers' word. Four defects were
confirmed, and the largest of them inverts the design. `REVIEWS.md` carries all
fourteen findings; this section carries only what changed the architecture.

**The first draft would have reimplemented its own back end.** It proposed
`install -m 0755` for the executables and a hand-written `cp` for the git hook.
`install-shared-artifact.sh` already implements a lock, a monotonic version
marker, downgrade refusal at exit 3, and an opt-in `--allow-downgrade … --reason`.
`install-core-git-hooks.sh` already resolves the hooks directory through
`git rev-parse --git-path hooks`, tolerates linked worktrees and
`core.hooksPath`, refuses a foreign hook, and claims ownership by marker line.
The first draft cited `~/.agenticapps/install.log` — which records two real
downgrades taken through that arbitration — as its reason to copy rather than
symlink, and then proposed the one mechanism that would have destroyed the
property that log exists to record.

## What the second round found, and why the change got smaller

Round one's insight — orchestrate, do not reimplement — holds for the host side
and does **not** hold for the project side, because on the project side there is
currently nothing to orchestrate. Two of the three things `--project` was going
to delegate to do not cover it:

- `install-core-git-hooks.sh` is core-only by design. The hook it writes resolves
  `${OPENSPEC_GATE:-$ROOT/reference-implementations/openspec-change-gate/openspec-change-gate.sh}`
  — ADR-0028's self-hosting inversion, working exactly as intended. A consuming
  project has no `reference-implementations/`, so this script cannot bind one at
  all, by `cd` or otherwise. The first draft's "generalised by `cd`, not by
  modification" was wrong twice: it contradicts a flag that takes a path, and the
  target it named cannot serve the case.
- **No canonical instruction-file provisioner exists.** Searching this repository
  for the mandated marker across shell sources returns the conformance *test*,
  the authoring-conventions spec, and the capability spec. No writer.

That is a scope discovery, not a defect to patch. So `--project` is deferred to
its own change and this one is the host side: publish, bind skills, replace
legacy bindings, wire claude/codex/opencode, `--check`. The budget was already at
risk before round two; with a provisioner and a project-shim path added it was
not credible, and the spec forbids meeting the budget by dropping a promised mode.

## Goals / Non-Goals

**Goals:**

- One command, no host argument required, that leaves a machine usable.
- Every skill binding a symlink into the checkout, so `git pull` updates the
  machine.
- A `--check` an operator can run on an unfamiliar machine to see its state.
- The bindings into archived checkouts become replaceable.

**Non-Goals:**

- Rewriting the gate, `run-plan-review` or `reviewer-cli`. That is Phase 4, and
  this installer publishes them exactly as they stand today.
- Binding a consuming project. `--project` is its own change, for the reasons in
  the section above: it needs a project-shim installer and an instruction-file
  provisioner that does not exist yet.
- Deleting `tools/`. Phase 5b.
- Wiring pi's or omp's hook. pi can block a tool call from an extension
  (`docs/extensions.md`: the event after `tool_execution_start` "**Can block**"),
  so this is a known-possible follow-up rather than an unknown — but writing a
  pi extension is a second gate implementation, and that is not what a 200-line
  installer is for.
- Uninstall. Nobody has asked for it, and every line of it is a line of this
  budget spent on a path no one has walked.

## Decisions

### `install.sh` is a front end, not a replacement

It publishes through the two existing installers and installs core's own hook
through `install-core-git-hooks.sh`. This is the leaner answer as well as the
safer one: orchestrating is less code than reimplementing, and the contracts
come free.

### Publishing is two calls, because attestation and arbitration are different

The first draft published all four executables through
`install-shared-artifact.sh`. That is wrong for one of them.

`install-shared-artifact.sh <src> <dst> <marker-key>` gives **monotonic
replacement**: a lock around the whole read-compare-write, refusal to downgrade,
atomic rename. It writes no manifest. `install-project-hooks.sh` gives
**attestation**: it reads the declared set from
`reference-implementations/project-hooks/ARTIFACTS`, publishes that whole set,
and rewrites `~/.agenticapps/manifest.tsv` with a version and a sha256 per
artifact. `project-hook-binding` requires that attestation, and
`~/.agenticapps/manifest.tsv` on this machine carries exactly the project-hook
artifacts and nothing else — that manifest *is* the attestation.

So:

| Source | Installer | Marker key |
|---|---|---|
| `reference-implementations/openspec-change-gate/openspec-change-gate.sh` | `install-shared-artifact.sh` | `gate-version` |
| `reference-implementations/run-plan-review/run-plan-review.sh` | `install-shared-artifact.sh` | `run-plan-review-version` |
| `reference-implementations/reviewer-cli/reviewer-cli.sh` | `install-shared-artifact.sh` | `reviewer-cli-version` |
| the declared project-hook set (today: `database-sentinel`) | `install-project-hooks.sh` | — the installer handles it |

Two calls plus one loop, rather than four loop iterations. It is also less code.

**Exit 3 from the shared-artifact installer is success, not a skip.** Its own
contract says so in terms: "skipped — dst already holds a STRICTLY NEWER version
(this is success: the postcondition *dst is at least as new as src* holds either
way)". The first draft classified it as skipped work, which would have driven a
non-zero exit on a machine that is in the desired state. It is reported as
satisfied.

*Note, not a goal:* `install-project-hooks.sh` rewrites the manifest in full from
the declared set, so the stale `normalize-claude-md.sh` row left behind by that
artifact's retirement disappears on the first run. The file itself stays in
`~/.agenticapps/bin/`. Removing software this installer did not install is not
this change's business.

### The executables are published from where they already live

`install.sh` names its sources inline, from the table above.

*Alternative rejected:* create a `bin/` directory and move them into it. It
reads better, and it costs a rename that touches `CLAUDE.md`, core's
self-hosting gate hook, and the tooling that resolves those paths — all for no
behaviour change. Phase 4 rewrites these scripts anyway; a rename belongs next
to the rewrite, or nowhere.

`~/.agenticapps/bin/` does not move. Six fleet projects shim to that absolute
path.

### Skills are symlinked; executables go through version arbitration

The asymmetry is intentional. A skill is read by an agent at session start, and
a stale one silently teaches the wrong loop, so it must track the checkout. An
executable is run by a git hook on a machine that may not have the checkout
mounted, and its version history is something the fleet has already had to reason
about deliberately.

### Legacy bindings come from a named manifest

Today's `skills/` holds two entries. The bindings actually on this machine
include `agentic-apps-workflow`, `setup-agenticapps-workflow`,
`update-agenticapps-workflow`, `agenticapps-workflow`, a `codex-*` set including
`setup-codex-agenticapps-workflow`, and `update-opencode-agenticapps-workflow`.
Iterating two entries cannot replace any of them, and deleting the archived
checkouts would leave every one of them dangling.

So the manifest is explicit data in `install.sh`: for each legacy name, either
the current name that replaces it or `remove`. Round two's objection was that the
mapping itself was never written down, so here it is, as it will appear in the
script:

| Legacy binding name | Outcome | Why |
|---|---|---|
| `agentic-apps-workflow` | → `agentic-apps-workflow` | the trigger skill; core now ships it |
| `agenticapps-workflow` | → `agentic-apps-workflow` | the hyphenless duplicate; two names, one skill |
| `setup-agenticapps-workflow` | remove | `install.sh --project` is its successor, and that is a later change |
| `update-agenticapps-workflow` | remove | migration replay; core has no `migrations/` |
| `setup-codex-agenticapps-workflow` | remove | host-prefixed variant of the above |
| `update-codex-agenticapps-workflow` | remove | host-prefixed variant of the above |
| `update-opencode-agenticapps-workflow` | remove | host-prefixed variant of the above |
| `openspec-change-review` | → `openspec-change-review` | core now ships it |

`update-*` is removed because the behaviour is gone: core has no `migrations/`
directory, so nothing in it can be replayed.

**`setup-agenticapps-workflow` is different, and the split opens a window.** Its
job — bootstrapping a fresh project — is what `--project` will do, and `--project`
is now a later change. Removing the binding therefore removes a capability before
its replacement exists.

It is removed anyway, and the window is stated rather than avoided. The
alternative is to leave a binding into an archived checkout in place, which fails
this change's own negative test and is the exact condition the change exists to
end. During the window, bootstrapping a new project means invoking the archived
checkout's skill directly — it still exists on disk, since Phase 5b is what
deletes it — or doing it by hand.

The consequence is a sequencing constraint worth naming: **the `--project`
follow-up must land before the archived checkouts are deleted.** That was already
true for the codex adapter and the opencode plugin, both sourced from those
checkouts. This adds a third reason.

**The test cannot be the manifest read back.** Round two was right that checking
"every name in the manifest" against that same manifest proves nothing about the
names the manifest omits — which is the only failure mode that matters. So the
negative test does not consult the manifest at all: it walks *every known host
skill directory* and fails if any entry, manifest member or not, resolves into a
checkout the workflow no longer maintains. A manifest gap fails that test.

### Revised once the real machine was measured: discovery acts too

The paragraph above said discovery detects and the manifest acts, on the grounds
that discovery "cannot decide between replace and remove". Running `--check` on
the real machine showed the manifest naming 8 of 26 archived bindings, and the
18 it missed are not obscure: `setup-opencode-agenticapps-workflow`, and
seventeen host-prefixed copies of upstream skills — `codex-cso`, `opencode-qa`,
`codex-impeccable-audit`, `opencode-ts-declare-first` and the rest.

Two things follow. First, the manifest is not a list anyone will keep complete
by hand; that was the predicted residual defect and it was already real before
the first run. Second, the objection that blocked discovery is answerable: **the
presence of a host-neutral equivalent decides.** Strip the host prefix and any
`-audit` suffix, and if a skill of that name is installed, rebind to it;
otherwise remove. `codex-cso` becomes `cso`, `opencode-qa` becomes `qa`, and
`codex-design-critique` — for which no neutral skill exists — is removed.

So the sweep acts, and the manifest shrinks to the single case the sweep is
blind to: `agenticapps-workflow`, a real directory holding a copied skill rather
than a symlink. That is also the second of the two files that both claimed to be
the trigger skill.

These copies are what the workflow's own rule already forbids — "never vendor a
copy; bind the installed one". Rebinding is that rule applied retroactively.

*Alternative rejected:* symlinking each host's whole skills directory to
`core/skills`. It is the obvious simplification and it is wrong, because those
directories are not ours: `~/.claude/skills` holds 98 entries and core owns two
of them. A directory-level link would delete the other 96. Per-entry links also
buy per-entry consent and per-entry recovery, which an all-or-nothing link
cannot.

### `jq` is Tier 2, and a skipped wiring exits non-zero

`~/.claude/settings.json` on this machine already carries hooks from four other
tools. Hand-rolling a JSON merge in bash against a file other software writes to
is how you corrupt someone's editor config. So wiring uses `jq`, and `jq` is
Tier 2 — Tier 1 is `git` and `bash` by requirement.

The first draft then exited 0 when `jq` was missing. That violates
`installer-prerequisite-consent`, which says in terms that an installer *"SHALL
exit non-zero when a step it was asked to perform was skipped."* Both reviewers
caught it from opposite directions — gemini as a usability objection to
hand-pasting JSON, codex as a spec contradiction — and gemini's own second
option is the resolution: **refuse to wire that host, say so, wire the others,
exit non-zero.** The block is still printed, because an operator who wants to
finish the job by hand should not have to reconstruct it.

Note the distinction the spec draws: an *unrequested* absence is not a skip.
Wiring pi, which has no confirmed hook surface, exits zero — the operator asked
for what exists and got it.

When `jq` is present the write is: render to a temp file, confirm it parses,
preserve the original at a reported path, then move. A failed `jq` leaves the
original untouched because it was never opened for writing. And modifying a
host's configuration at all requires acceptance, defaulting to no — that file
belongs to the host, not to this workflow.

The non-interactive opt-in is `--accept-host-config`, and `INSTALL_ACCEPT_HOST_CONFIG=1`
is its environment equivalent for CI. Round two was right that "a named opt-in"
with no name is not a specification: without one, every non-interactive run
either prompts into a closed stdin or silently assumes consent, and both are the
failure this rule exists to prevent. Absent the flag, a non-interactive run
prints the block it would have written and does not write it.

Note the asymmetry with `jq` reserialisation, because a test depends on it: `jq`
reformats the whole document, so **byte** preservation of other tools' hook
entries is not achievable and asserting it would fail a correct implementation.
What must hold is that every pre-existing entry survives **semantically** — same
entries, same values — and that the *backup* is byte-for-byte the original.

*Alternative rejected:* python3 for the merge. It is a second scripting language
in a file whose budget is 200 lines and whose reviewer is asked to read all of
them.

### Null wiring is the absence of a function, not a branch

Each host with confirmed wiring gets a `wire_<host>` function. Hosts without one
get their skills bound and nothing else. There is no `if host is pi or omp` test
anywhere. Adding pi later is adding `wire_pi`.

### pi and omp share one host-neutral directory, and it identifies neither

Both resolve to `~/.agents/skills`, so one symlink set covers both. The
installer does not write `~/.pi/agent/skills` even though pi reads it, and does
not write a second copy into `~/.claude/skills` for omp — omp already reads
claude's.

But that directory cannot be used to *detect* either host: it is shared, and it
already holds a `.skill-lock.json` from an unrelated tool. Detection tests for
the host executable. The shared binding is reported once, as shared, naming both
hosts — not as evidence that either is installed.

### The opencode plugin is derived, not lifted

The installed copy at `~/.config/opencode/plugin/openspec-change-gate.ts` tells
the operator, at line 93, that a change *"must pass 'openspec validate --all'
AND carry REVIEWS.md with >=2"*. The gate stopped enforcing that at 2.0.0;
`CLAUDE.md` and `change-gate-enforcement` both say so. Lifting it byte-for-byte
would install a message that sends operators to fetch reviews for an edit that
was never blocked for that reason.

So `hosts/opencode/openspec-change-gate.ts` is written against current gate
behaviour and reviewed as executable code, not as an asset. The same rule
generalises into the spec: wiring never asserts a rule the gate does not enforce.

And it is **installed**, by a `wire_opencode` that is a peer of `wire_claude` and
`wire_codex` — same acceptance, same preserve-before-replace, same idempotence,
same failure handling. The first draft created the plugin and tested its
behaviour but never wired it, which would have shipped a file nobody installs.
Opencode's plugin is a file rather than a JSON edit, so `wire_opencode` does not
need `jq`; it still needs acceptance, because the plugin directory belongs to
opencode.

### codex needs an adapter, and one exists to start from

codex cannot invoke the gate directly: `apply_patch` carries paths inside the
patch body, and codex expects a permission-decision response. The adapter that
handles this lives at
`codex-workflow/skills/agentic-apps-workflow/scripts/hook-wrapper-openspec-gate.sh`
in the archived repo, and core has no equivalent — so replacing codex's skill
binding without carrying it forward would break a hook that works today.

It comes into `hosts/codex/` and is reviewed as code under the same rule as the
opencode plugin, against real allow and block payloads.

### `hosts/` is where host names are allowed

`CLAUDE.md` forbids a host name inside `skills/`. It does not forbid host
adapters existing — it cannot, because three hosts have irreducibly different
wiring. `hosts/` makes that boundary explicit rather than implicit.

### `--check` judges currency by bytes, not by version marker

Presence is not a state worth reporting: a stale, downgraded or hand-edited
executable is present. Neither is a matching version marker, and that was round
two's sharpest finding — **a hand-edited executable carrying the same marker
reports as current.** Comparing markers to markers cannot see an edit that did
not touch the marker, which is the same failure the round-one review caught one
level up.

`project-hook-binding` already settles this: currency is judged against an
authority checkout, by bytes. So for each published artifact `--check` compares
the destination's content with the checkout's and reports one of:

| State | Meaning |
|---|---|
| current | bytes match the checkout |
| stale | destination version is older than the checkout's |
| ahead | destination version is newer — the deliberate-downgrade-refusal case |
| modified | same version, different bytes — hand-edited or half-upgraded |
| unreadable | present but cannot be read or its marker cannot be parsed |
| absent | not there |

`modified` is the state that only exists because the comparison is by bytes, and
it is the one worth having. `unreadable` is separate from `absent` because an
operator can act on the first and not the second.

For each host, `--check` reports whether skills are bound and whether the hook is
wired, with the same distinction: a binding that exists but resolves somewhere
unexpected is not "bound".

### Recoverability is guaranteed where this installer owns the write

The first draft promised that every destructive act preserves what it replaces.
Round two showed that promise cannot be kept for published artifacts: the
shared-artifact installer takes its own lock, and a backup taken by `install.sh`
*before* delegating is racy — the destination can change between the copy and the
helper acquiring the lock. A guarantee that holds only when nothing else is
running is not a guarantee.

So the guarantee is scoped to what `install.sh` writes with its own hands:
**skill bindings and host configuration files.** Those it preserves at a reported
path before replacing, and the summary states the restore command.

For published executables the protection is different and already exists: version
arbitration under lock, refusal to downgrade, and an explicit
`--allow-downgrade … --reason` for the case where an operator means it. That is
the recoverability story for `~/.agenticapps/bin/`, and this design states it
rather than layering a weaker one on top.

*Alternative rejected:* adding backup-under-lock to `install-shared-artifact.sh`.
It would make the guarantee uniform, and it is a change to a file six fleet
projects depend on, made inside a change that is already at its budget. If the
uniform guarantee is wanted, it is a change to that helper, with its own review.

Backups are named `<path>.pre-install.<n>` where `<n>` is the first integer that
does not collide, so a second run never overwrites the first run's evidence.
They carry the original's permissions. A backup that cannot be written aborts
that step rather than proceeding unprotected.

## Risks / Trade-offs

**Corrupting a shared `settings.json`** → acceptance first, then render to temp,
parse-check, preserve, move. `jq` never writes the original. On any failure the
block is printed, the step counts as skipped, and the run exits non-zero.

**Replacing a binding someone wanted** → every replacement is reported by path
and names what it found. Acceptance is required for anything that might not be
ours, which round two correctly said the first draft got backwards — it replaced
every foreign symlink unasked:

| What is at the target | Outcome |
|---|---|
| symlink into this checkout | already correct; nothing done |
| symlink into a checkout on the legacy manifest | replaced, reported by old target |
| symlink anywhere else | **acceptance required**; declined, it is left and counted skipped |
| dangling or relative symlink | resolved first, then judged by the rows above |
| directory | reported as a copied skill; replaced only with acceptance |
| regular file | reported; replaced only with acceptance |

The regular-file row exists because the first draft named that state and then
defined no outcome for it. A regular file where a skill directory belongs is
someone's note or someone's half-migration, and neither should vanish silently.

**Two opt-ins, not one.** Writing the binding tests made it obvious that
`--accept-host-config` cannot also authorise replacing a binding target: one
grants "edit the JSON your editor reads", the other grants "delete a directory
that may hold work". An operator granting the first has not considered the
second, and a single flag would collect both on one keystroke. So the
unrecognised-target consent is `--replace-unrecognised`, separate and separately
named, each with the `INSTALL_*` environment equivalent the spec requires.

**Recognition is by repo name in the resolved target, not by absolute path.** A
binding is this workflow's own if its resolved target contains one of the
archived repo names — `claude-workflow`, `codex-workflow`, `opencode-workflow`,
`pi-agentic-apps-workflow`. Hardcoding `~/Sourcecode/agenticapps/…` would tie the
judgement to one machine's directory layout and silently reclassify every
binding as foreign on a machine that checks out elsewhere, which is the failure
mode where the installer stops replacing the things it exists to replace. It also
makes the property testable without fabricating a home directory layout.

**The legacy manifest is incomplete** → this is the likeliest residual defect,
and it is why the negative test exists: after a run, no binding installed by
this workflow may resolve into an archived checkout. A gap fails that test
rather than surfacing when someone deletes a checkout months later.

**pi and omp stay unwired** → accepted. They run on the git and CI floor, which
is where enforcement actually is.

**`~/.agents/skills` is shared** → it already holds another tool's
`.skill-lock.json`. The installer only ever adds or replaces entries it can
name, never clears the directory.

**The budget is now at risk** → orchestrating rather than reimplementing buys
room, deferring `--project` buys more, and the legacy manifest and byte-wise
currency spend some of it back. Round two was right that "report the overage"
gives an implementer no way to proceed, which makes the budget a suggestion. So
the order of sacrifice is fixed in advance, and it is not negotiable at the
moment of writing the code:

1. **Mandatory** — the four modes, publishing, skill binding, the legacy
   manifest, and every acceptance and preservation rule. None of these may be
   dropped to fit. `--host auto` is a normative scenario, not a nice-to-have,
   and the first draft was wrong to offer it as the thing that goes.
2. **Deferrable, in this order** — the `modified`/`unreadable` distinction in
   `--check` (collapsing to "not current"); then per-host wiring for the third
   host, which leaves that host bound and unwired, a state the spec already
   defines as conformant.

Anything deferred is reported to the operator with what caused it. If the
mandatory set alone exceeds 200 lines, that is reported as an overage and the
budget is raised in the spec by amendment — never silently in the script.

**The archived checkouts must survive until this lands** → the codex adapter and
the opencode plugin are both sourced from them. Deleting them first loses the
adapter.

## Migration Plan

1. Land `install.sh`, `hosts/`, and the tests. Nothing on the machine changes.
2. Run `./install.sh --check` and record the before state.
3. Run `./install.sh --host auto`. Legacy bindings are replaced or removed.
4. Re-run `--check`; confirm every previously-bound host is still bound and no
   binding resolves into an archived checkout.
5. Confirm a fleet project's shim still resolves
   `~/.agenticapps/bin/openspec-change-gate.sh`.
6. Only then are the archived checkouts safe to delete — which is what Phase 5b
   needs.

Rollback: every binding and configuration file `install.sh` replaces is preserved
at a reported path, and step 2's `--check` output is saved as a file rather than
merely printed — a before state that scrolled past in a terminal is not evidence
you can restore to. Published executables roll back through version arbitration,
not through backups, per the recoverability decision above. The checkouts
themselves are never written to.

## Open Questions

None blocking. pi's and omp's skill directories are resolved above and closed
the host table.

Deferred with the mode that needed them, to `--project`'s own change: a project
shim installer, and a canonical instruction-file provisioner. The provisioner is
the larger of the two and its size is genuinely unknown — a section template, a
version source, frontmatter placement, byte preservation outside the markers, and
consent to update an existing section. That is the reason it is not a task in
this change rather than a risk in it.

Deferred deliberately: pi's blocking tool-execution hook is a real wiring
surface, and wiring it would put pi on the same footing as the other three. It
is a separate change, because it is a gate implementation in TypeScript against
an API this session has read one page of.

Noted, out of scope: `~/.config/opencode/opencode.json` still registers the
removed `gitnexus` MCP server. Recorded here so it is not lost; it is the third
open question in the session handoff.
