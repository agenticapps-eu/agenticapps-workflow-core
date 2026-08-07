## Context

Four removals were decided on four separate days and none of them finished.
GitNexus went on 2026-07-28 and six of its skills still load in core's own
`.claude/skills/`. `database-sentinel` was decided on 2026-08-07 and its
implementation and declaration entry still ship. `GSD_SKIP_REVIEWS` stopped
escaping anything at gate 2.0.0 and is still read, advertised across twenty files,
and recommended to the operator by `run-plan-review.sh` at a failure path.
`~/.claude/skills/agenticapps-workflow` was deleted at some point nobody recorded,
leaving `ts-declare-first` a dangling symlink.

And `gate/` — a whole published gate, pre-2.0.0, that nothing resolves.

The pattern is the same each time: the decision was made, the primary artifact was
removed, and the surface around it was left. Nothing failed, so nothing surfaced
it. All of it was found on 2026-08-07 while measuring something else.

## Goals / Non-Goals

**Goals:**

- Apply `CLAUDE.md`'s stated test once, to shipped enforcement surface.
- Remove `gate/`, and with it the last place in the repository that says reviews
  block.
- Remove `GSD_SKIP_REVIEWS` from every surface, including the two in `spec/18` and
  the recommendation in `run-plan-review.sh`.
- Correct the two false statements on `workflow.mmd` and the one in the gate
  header, because an arbiter wrong at the source decides wrongly.

**Non-Goals:**

- Removing anything from `adrs/`, `openspec/changes/archive/`, or `CHANGELOG.md`.
- **§13.** Removed from this change entirely — see below.
- Re-specifying `database-sentinel`'s removal; `projects-bind-not-copy` owns that
  requirement.
- Deciding the fate of the stray `agenticapps-dashboard-add-agent-board` worktree.

## Decisions

**§13 is dropped, and the reason it was ever here is worth keeping.** An earlier
revision proposed retiring `spec/13-ts-declare-first.md` on the claim that no host
bound it. The claim was produced by checking `~/.claude/skills`, finding a dangling
symlink, and stopping. `reference-implementations/README.md` records three hosts
binding it: `codex-ts-declare-first`, `opencode-ts-declare-first`, and
`pi-ts-declare-first`. pi reached `full` conformance at host v0.6.0 *by* binding
§13, after ADR-0004 explicitly reversed its minimal-host framing to do it.
Removing §13 would break three hosts and demote one, to delete 271 lines nobody
was tripping over.

The dangling symlink that produced the false claim is real and still removed —
it just evidences that *one host's global binding* went, not that the contract is
unused. A machine-level absence was read as a fleet-wide one.

*Consequence:* the spec-version collision with PR #78 dissolves. Nothing here is
breaking to `spec/`, so 2.0.0 stays uncontested.

**`gate/` is removed rather than corrected.** It could be regenerated from the
reference implementation, and that is the obvious alternative. Rejected because a
published copy that nothing resolves has no reader to serve: it would exist only
to be kept in sync, and the sync is what already failed for a month. The
resolution path is asserted, not assumed — `resolve-core-artifact.sh:100` maps the
shared install to `reference-implementations/openspec-change-gate/`, and
`~/.agenticapps/bin/openspec-change-gate.sh` is byte-identical to that file
(`bc947e37…`) and not to `gate/` (`23310b7d…`).

*This was found by a reviewer, and its premise was wrong in a way worth recording.*
opencode reported that shimmed projects run the published copy, which would have
made the change's central claim false. They do not — every installer and hook
resolves the reference implementation. But the finding was right about `gate/`
existing, contradicting the spec, and being unmentioned by this change. A wrong
mechanism led to a correct and material defect.

**The capability is scoped to enforcement surface, not to all artifacts.** An
earlier revision stated the diagram test absolutely and thereby condemned `adrs/`,
`tools/`, `docs/`, `prompts/` and `CHANGELOG.md` — while a sibling requirement in
the same file demanded records be retained. Three reviewers found this
independently. The rule now names its class and its exemptions. *Alternative
rejected: keep the broad statement and rely on judgment to read it down.* A rule
that means whatever its reader assumes is not a rule.

**The diagram does not automatically yield to the code.** An earlier revision said
a wrong diagram SHALL be corrected to match the implementation, which reverses
spec-first authority — the implementation is as likely to be the defect. The
requirement now resolves disagreements against the normative requirement and its
decision record. Here both diagram statements are stale against ADR-0027, so the
diagram is what changes; that is a finding about these two lines, not a rule.

**The hatch is removed, not defaulted off, and its absence is verified by reading
the source.** An earlier revision required the gate to "behave as if unset" when
the variable is present, and separately forbade a test asserting that. Both cannot
hold — guaranteeing behaviour for a name keeps the name in the interface. The
requirement is absence.

**Its conformance rows go with it, and this is the part that looks wrong.**
Deleting tests to make a change pass is normally the error. Here the rows assert
the behaviour of the thing being removed. But the earlier claim that they were its
*only* live consumers was false: `run-plan-review.sh:677` recommends the flag to
the operator when too few reviewers respond. That is a live consumer, at the
moment an operator is most likely to act on advice, and it is why the removal
reaches executables and not just documentation.

**Machine-level items are steps, not shipped artifacts,** and their evidence is
redacted. The opencode MCP entry embeds a `/Users/donald/...` fnm path; recording
it verbatim would repeat the unescaped-home-path egress issue that has been
deferred four times. Evidence records the structure and the fact of removal, with
paths redacted.

**Historical references are left exactly as they are.** ADR-0012, ADR-0019 and
ADR-0024 name artifacts touched here. ADRs are append-only; the removals are
recorded by a new ADR.

## Risks / Trade-offs

**Removing `gate/` breaks an unobserved consumer.** → The resolver mapping and the
installed artifact are both read and compared before removal, and the removal
records what was searched. This machine is the only one running the workflow, and
that bound is stated rather than treated as proof of universal absence.

**Removing the hatch removes a perceived override.** → Nothing blocks on reviews
in the implementation that actually runs. The risk was real for `gate/`, which is
removed in the same change; leaving one and not the other is the incoherent state.

**The `workflow.mmd` corrections change the arbiter mid-change.** → They are
sequenced first, so every later removal is judged against the corrected diagram.

**`database-sentinel.sh` is deleted here while its requirement lands elsewhere.**
→ `projects-bind-not-copy` is unmerged and has no PR. This is a hard block, not an
ordering preference. Task 5.1 states an objective precondition — the entry absent
from `SHIMMED-HOOKS` on the merge base — and a fallback: if that change stalls,
carry the declaration edit here or drop the deletion. Deleting an implementation
the declaration still names is precisely the failure the reverse pass exists to
catch.

**The surface list is still incomplete.** → It was five files in the first
revision and is twenty now, found by a reviewer rather than by me. The grep in
task 9.4 is the backstop, and it is stated as a backstop rather than as coverage.

## Migration Plan

1. Correct `workflow.mmd` — lines 7 and 13. The arbiter is fixed before it judges.
2. Correct the gate header's `MIN_REVIEWERS` documentation.
3. Remove `gate/` entirely, after reading the resolver mapping.
4. Remove `GSD_SKIP_REVIEWS`: the gate branch, `run-plan-review.sh`'s
   recommendation, `spec/18`'s two statements, the conformance rows, and the
   remaining documentation surface.
5. Delete `database-sentinel.sh`, gated on its `SHIMMED-HOOKS` entry being gone.
6. Delete core's `.claude/skills/gitnexus/`.
7. Machine-level: the dangling symlink and the opencode MCP entry, evidence
   redacted.
8. Fleet: four `SKILL.md.pre-0034` files.
9. Record the stray worktree. Write the ADR.

Rollback is `git revert` for steps 1–6 and 8. Steps 7 and 9 are not in version
control; the removed content is recorded in redacted form so it can be restored.

## Open Questions

1. **Does any host outside this machine resolve `gate/`?** Unanswerable here — the
   workflow runs on one machine. Recorded as a stated limit of the evidence.
2. **What happens to `agenticapps-dashboard-add-agent-board`?** A stray worktree
   carrying its own gate and conformance harness, and the likeliest source of the
   repeated fleet miscounts. Out of scope; it needs its own decision.
3. **Does `~/.claude/CLAUDE.md`'s stale skill-conflict warning belong here?** It is
   machine-level and about skill identity rather than enforcement surface. Kept
   because leaving it means the next reader re-derives a conflict that no longer
   exists, but it sits at the edge of the capability's scope as now written.
4. **Was `gate/` ever resolved by a host that has since been reinstalled?** The
   directory dates to 31 July and the reference implementation was updated 90
   minutes later the same day. Nothing records whether anything pointed at it in
   between.
