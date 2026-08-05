## Context

`AGENTS.md` is read by every agent that opens the repo. Each host's setup skill
appends its own marker-delimited block to it independently, and no host looks
first to see whether the section is already there. With one host installed the
design flaw is invisible; the fleet survey found every repo but one carrying
exactly one block, which means the fleet is conformant by accident.

`factiv/cparx` is the exception and the evidence. It had codex and opencode
installed, so it had two blocks — 96 and 94 lines. Normalising host names out
of both leaves ~50 of ~190 lines differing, and every one of those differences
is drift rather than design: `/prompts:gsd-discuss-phase` against
`/gsd-discuss-phase`, `gsd-execute-plan` against `gsd-execute-phase` for the
same step, and both blocks citing GSD, removed fleet-wide on 2026-07-28. The
duplication did not encode a host difference. It manufactured a disagreement.

Two constraints shape the work. Core owns the contract but not the
implementations — the templates that write these blocks live in
`codex-workflow` and `pi-agentic-apps-workflow`, separate repos. And core
already has an established way to bind a contract it cannot execute: the
`tools/*-conformance.sh` harnesses, which a host repo runs against its own
artifacts to prove it satisfies a spec section.

## Goals / Non-Goals

**Goals:**

- One host-neutral workflow section in `AGENTS.md`, whatever the agent count.
- Adding and removing an agent are both supported, idempotent, re-runnable.
- Removal is bounded — one directory, not a search — and says what it found
  rather than guessing.
- The contract is machine-checkable by a host repo without core executing it.

**Non-Goals:**

- `CLAUDE.md`. Claude is its only reader; there is no second agent to
  coordinate with, so a marker convention there buys nothing.
- The curl-able bash installer (separate Part-2 change). Recorded there, not
  here: the installer should detect missing prerequisites on whatever machine
  it runs on and **offer** to install them, with the user accepting first.
- Editing the host repos' templates. This change defines what they must
  satisfy; they change on their own schedule.
- Auto-collapsing existing duplicate blocks. See Decisions.

## Decisions

**A duplicate section is reported, never auto-collapsed.** The obvious move is
to detect two blocks and merge them. Rejected: the cparx pair had drifted, so
"merge" means choosing between `gsd-execute-plan` and `gsd-execute-phase`, and
nothing in the text says which is right. Both, as it happens, were wrong — the
system they named had been deleted. A tool that picks silently would have
propagated a dead reference with the authority of having been "fixed".
Reporting both and stopping is the honest failure. *Alternative considered:*
collapse to the first block and diff the second into a `.orphan` file. Still a
silent choice, plus a new file nobody reads.

**Presence of an agent is the presence of its directory, and partial presence
is a first-class state.** Both cparx hosts were half-installed: `.opencode/`
had a config and a version stamp but no skills, `.codex/` was never committed
at all. A definition that admits only present/absent classifies both wrongly
and makes removal either refuse or over-delete. Removal therefore removes what
is there and reports what was expected but missing. *Alternative considered:* a
manifest per host listing every provisioned file. Better fidelity, but it is
new state that can itself drift from the directory, and the failure mode is
worse — a manifest that disagrees with disk is harder to reason about than a
directory that is simply incomplete.

**Tool-owned state inside a host directory is reported, not deleted.**
`.opencode/` also holds a `package.json` and `node_modules` that the opencode
CLI manages for itself. Removal must not take those: the workflow did not
install them and does not know what depends on them. This is the same rule the
cparx cleanup followed by hand.

**A link per agent is the only host-specific thing in the shared file.**
Donald's rule, and it replaced a weaker one this design originally carried:
that the shared file is touched only at the first-agent and last-agent
boundaries. That was wrong in an interesting way — it protected the file by
making agents invisible in it, which meant nothing in `AGENTS.md` recorded
which agents were actually installed, and removal had no per-agent handle to
pull. One link per agent restores the handle while keeping every line of prose
host-neutral. Adding an agent adds its link; removing it removes its link; no
other agent's link moves. *Alternative considered:* an agent manifest in a
separate file, leaving `AGENTS.md` entirely host-neutral. Rejected for the same
reason as the per-host manifest above — it is new state that can drift from
disk, and an agent reading `AGENTS.md` would have no pointer to its own
instructions.

**The links are a frontmatter list, and the entries carry paths.** Donald's
choice, over a per-agent marker pair. The entries are `codex: .codex/AGENTS.md`,
not a bare `- codex`, and that distinction is what keeps this decision
consistent with the manifest rejection directly above: an entry carrying a path
is still a pointer to the agent's own instructions, whereas a bare id would be
exactly the inventory that paragraph rules out. The list lives in `AGENTS.md`
itself, so it also cannot drift from the file it describes the way a separate
manifest could.

The cost is that adding or removing an entry rewrites the frontmatter block. No
tool can then prove it left the other entries byte-untouched, so the lifecycle
requirements below say another agent's link is *unchanged* in content rather
than byte-identical — the byte-identical claim is kept for the host-neutral
section, where it is achievable and where it is the property that actually
matters. *Alternative considered:* a marker pair per agent, which makes the
byte-identical claim provable for links too. Not chosen; the frontmatter list
buys a single well-known location and no delimiter overhead, and the rewrite
hazard falls on the host installers rather than on core, whose harness only
reads this file.

**The host-neutral section survives the last agent leaving.** Removing it would
be symmetric with adding it, and symmetry is the wrong goal: a repo that
briefly has no agent would lose documentation it is about to want back, and
re-adding an agent would have to reconstruct prose that was never any agent's
to own. Only the departing link goes.

**A host identifier inside the section warns rather than fails, and links are
exempt.** The check is a denylist and cannot recognise novel phrasing, so it
will both miss cases and occasionally fire on prose that merely mentions a host
— making a partial heuristic blocking is the wrong trade. The link exemption is
not a refinement but a correctness condition: links are host-specific by
design, and a check that flagged them would fire on the one thing the
capability explicitly permits.

**Tool-owned state is reported, and no subdirectory separation is required.**
The open question asked whether a host directory must separate
workflow-provisioned files from state the agent's own CLI manages. Donald
redirected to the `AGENTS.md` rule above rather than answering it, so the
weaker existing decision stands unchanged: removal reports state it did not
install and leaves it alone. Recorded here so the question is visibly not
adopted rather than silently dropped.

**The marker name stays `agentic-apps-workflow sections`, and the marker was
never the problem.** This design originally recorded that today's markers are
host-scoped — `BEGIN: agentic-apps-workflow sections` and
`BEGIN: opencode-workflow sections` — and that the new section therefore needs a
single host-neutral name. A marker inventory across the family shows both halves
of that are wrong.

`agentic-apps-workflow sections` is not host-scoped. It is already host-neutral,
and all three live templates — codex, opencode and pi — already write exactly
it. `BEGIN: opencode-workflow sections` appears nowhere in the family except in
this design's own earlier text. The host-scoped markers that do exist,
`codex-workflow global section` and `opencode-workflow global section`, are
written into the *global* agents file (`$CODEX_HOME/AGENTS.md`,
`$OPENCODE_CONFIG_DIR/AGENTS.md`), which is a different file from the project's
`AGENTS.md` and out of scope here.

This inverts the diagnosis. Two hosts did not collide because they used
different names — they collided because they used the *same* name and neither
looked for it before appending. A single host-neutral marker is not the fix; it
is the pre-existing condition. It is also why the cparx pair could not be merged
mechanically: with both blocks carrying an identical marker, nothing in the file
records which host wrote which, so even the provenance needed to choose between
them was absent.

The requirement is therefore about behaviour, not naming: a host MUST look for
the marker and MUST NOT append a second block when it is present. There is no
rename, and the legacy-name list for project files is empty — but the harness
must still not mistake a global-file marker for a project one, since the two
differ only by a word.

**Core binds this with a conformance harness, not an implementation.** Follows
the established `tools/*-conformance.sh` shape: a host repo points the script
at its own artifacts and gets a pass/fail row per requirement. Core cannot
provision an agent into a repo it does not own, and the last time a contract in
this repo was stated in prose alone, seven fixtures and a worked example
drifted from it undetected until CI ran on a different machine.

## Risks / Trade-offs

**The single-section rule is unenforced until every host adopts it.** → The
harness makes non-adoption visible per host rather than fleet-wide, so
adoption can be sequenced instead of coordinated. Until then the current
accidental conformance holds, since one agent per repo is the norm.

**Reporting duplicates rather than fixing them leaves manual work.** → It is
one repo, already cleaned by hand, and the report names both blocks and their
line ranges. The alternative silently picks a loser.

**"Host-neutral" has no mechanical test.** A host could satisfy the
single-section rule and still write its own name inside the section. → The
harness can check for known host identifiers in the section body. That is a
denylist and will not catch novel phrasing — a real residue, worth stating
rather than papering over.

**Splitting content into host directories can under-specify an agent.** If
something genuinely shared gets pushed into a host directory, other agents lose
it. → The measured host-specific surface is about four values; anything larger
crossing that boundary is the signal to re-examine, and the harness reports
host-directory size rather than assuming.

## Migration Plan

Fleet scope is zero repos in the duplicate state — cparx was the only one and
its cleanup already merged as cparx PR #125. The migration exists to define
the collapse, not to run it.

1. Spec §12 gains the single-section and host-directory requirements.
2. Core ships the conformance harness; core's own CI runs it against core.
3. Each host repo adopts on its own schedule, using the harness as the gate.
4. A repo found with duplicate blocks is reported, resolved by hand, and the
   resolution recorded — there is no automated collapse path by design.

Rollback is deleting the harness and reverting the §12 requirements; nothing
in a downstream repo depends on this change until that repo adopts it.

## Open Questions

All three questions this design opened were answered by Donald and have moved
into Decisions above: the host-identifier check warns rather than fails; a
per-agent link is the only host-specific content permitted in `AGENTS.md`; and
the host-neutral section is not removed when the last agent leaves.

The link's shape, which task 2.5 held open, has also been answered and moved
into Decisions above: a frontmatter list whose entries carry paths. The
denylist, which the first plan review found was normative-but-unowned, is now
enumerated in the spec with an explicit rule for hosts not on it.

Remaining, and genuinely open:

- **Concurrent provisioning is unaddressed.** Two hosts installing at the same
  time both read `AGENTS.md`, both find no section, and both write one. The
  read-modify-write is not atomic and this design specifies no locking. It is a
  narrow window on a single-operator fleet, and the duplicate is detected and
  reported by the harness afterwards rather than being silent — so it degrades
  to the state this change already handles rather than to corruption. Stated as
  an accepted limitation, not solved.
- **Nothing verifies that a linked file is actually read.** Moving invocation
  detail out of the shared file assumes each agent loads its own linked file. If
  a host does not, that detail becomes invisible rather than relocated, and the
  harness cannot tell the difference — it can check the link resolves, not that
  the runtime dereferences it.
- **The producer/consumer asymmetry this change surfaced is unowned.** Reading
  the three live templates side by side found the gate's "≥ 2 external
  reviewers, enforced" claim still in `pi-agentic-apps-workflow`'s template —
  false since gate 2.0.0, and corrected in all seven projects' shims on
  2026-08-02 without the template that seeds new projects being touched. The
  section version added above lets a stale *section* be repaired; nothing yet
  checks that a correction applied to consumers reaches the producer.
