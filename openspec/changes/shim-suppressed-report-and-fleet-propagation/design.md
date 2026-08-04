## Context

`report_rate_limited()` appears twice, byte-identically: `shim-template.sh:68`
and `openspec-change-gate.shim.sh:66`. When the hour marker matches it
`return 0`s, and control falls through to an unconditional `exit 1` five lines
later. The suppression therefore removes the message and keeps the interruption.

Measured 2026-08-04 against an unresolvable shared install, three consecutive
calls: `exit=1` with the report, then `exit=1` silent, then `exit=1` silent. The
host renders the silent ones as `hook error — No stderr output`.

The fleet state is measured rather than remembered.
`tools/project-hook-conformance.sh --fleet ~/Sourcecode` reports **30 findings**
across the seven binders declared in `reference-implementations/project-hooks/FLEET`:

| Binder | Family | State |
|---|---|---|
| `agenticapps-dashboard` | agenticapps | 3 shims, current at 1.1.0, byte-identical to template |
| `cparx` | factiv | 3 shims, current at 1.1.0, byte-identical to template |
| `agenticapps-roadmap` | agenticapps | 3 unmarked inlined copies |
| `agents-task-viewer` | agenticapps | 3 unmarked inlined copies |
| `callbot` | factiv | 3 unmarked inlined copies |
| `fbc-platform` | factiv | 3 unmarked inlined copies |
| `fx-signal-agent` | factiv | 3 unmarked inlined copies |

This corrects the README's own propagation note, written 2026-08-04, which said
three repos in one family. The instrument says five, across two.

**The instrument excludes core, and the first draft of this change accepted its
zero as proof.** `FLEET` omits `agenticapps-workflow-core` deliberately — it is
the authority, and `--fleet` would otherwise compare the template against itself.
Correct as an exclusion, false as a clearance: "the fleet reports 0" means every
binder except the one holding the rule. Stage-2 review caught it, and following
it into `.claude/hooks/openspec-change-gate.sh` found the authority's own binder
at 1.1.0 doing this on an unresolvable gate:

```
printf 'openspec-gate: WARNING — gate not found at %s; this edit is not gated.\n' "$GATE" >&2
exit 0
```

`spec.md:611-615` names that exact construction as warning nobody, because a
`PreToolUse` hook exiting 0 has its stderr discarded from the transcript. It has
been in the repository that publishes the rule, unreportable by the repository's
own instrument.

## Goals / Non-Goals

**Goals:**

- No shim exits non-zero having said nothing.
- The rule generalises beyond the one code path that motivated it.
- All seven declared binders carry a 1.2.0 contract shim, verified by the
  instrument rather than asserted.

**Non-Goals:**

- Re-adjudicating the reconciliations. Differences 1–6 in
  `reference-implementations/project-hooks/README.md` are already argued; this
  change *applies* them and decides nothing new about `.env` matching,
  `MultiEdit`, the `migrations/` arm, the inert `cd`, the `workflow` slug branch
  or the `agents-task-viewer` opt-out.
- The two stale remedies naming `/gsd-*` inside `normalize-claude-md`, and its
  `.planning/` linking. Both are recorded in the README as belonging to
  `docs/PLAN-lightweight-fleet.md` step 5; they stay there.
- Publishing `provisioning-check.sh` to the shared bin. Still open, still
  unrelated.

## Decisions

**A suppressed report emits one line and keeps `exit 1`.** Alternatives
considered: (a) exit 0 when suppressed, which delivers the interval policy's
intent but makes every remaining call in the hour an *unannounced* fail-open —
the posture this capability rejected when it rejected fail-closed; (b) drop the
interval policy and repeat the full report, which the capability already
considered and rejected as alarm fatigue. The chosen option is the only one where
the exit code and the message stay one signal. It also concedes something true:
an interval policy can only reduce verbosity here, never frequency, because the
exit code interrupts regardless — so the spec now requires that saving to be
described as verbosity.

**One line, not two, and not the first line of the full report.** `spec.md:613`
records that the host surfaces only the *first* stderr line. The existing 5-line
reports are already 4/5 invisible in the notice, so a suppressed report that
reuses line 1 would be indistinguishable from an unsuppressed one — the operator
could not tell a fresh failure from a repeat. The suppressed line says something
the full report does not: that this is a repeat and the full notice was already
made.

**The invariant is specified, not just the fix.** Written as "a non-zero exit
always carries a message", it binds every future suppression a shim learns —
filters, guards, quiet hours — rather than only the one rate limit that exists
today. This is the seventh instance in this lineage of a check that lied; stating
the class rather than patching the instance is what has been missing each time.

**Reporting joins the version-bump list.** Under the old wording this change owed
no bump: resolution order, exit behaviour and identification are all
byte-unchanged. Every deployed shim would then have differed from the template in
what it says, with no marker difference to surface it — the marker's own rule
producing the blindness the marker exists to remove.

**Conversions adopt the shared implementations as-is.** The five repos with
inlined copies get shims pointing at `~/.agenticapps/bin/`, whose contents are
the already-reconciled 1.1.0 implementations. No local semantics survive; that is
the point of the shim contract.

**Each repo gets its own branch and PR.** `openspec status` scopes
`allowedEditRoots` to core alone, correctly — the seven binders are outside this
planning home. The change names them and the instrument verifies them; the edits
land through their own repos' gates, not this one's.

## Risks / Trade-offs

- **Converting changes live behaviour in five repos, not just their file
  contents.** The inlined `database-sentinel` copies block every `migrations/*`
  edit unless `.planning/current-phase/migrations-approved` exists, printing a
  remedy that names `/gsd-discuss-phase` — removed 2026-07-28. Five repos are
  blocked on it today. → Conversion unblocks them, which is the argued outcome of
  README difference 3, and it is called out in each PR body rather than shipped
  as a silent side effect.
- **`normalize-claude-md`'s output changes in those repos**: the false
  `Migration 0009 not yet applied` stub stops being injected (difference 5). →
  Same treatment; named per PR.
- **`agents-task-viewer` loses a file that carries the only record of why it opts
  out.** Its 314-line variant is the predecessor plus a 26-line banner explaining
  a deliberate non-registration that had been manually reverted ~3 times. →
  Relocate the rationale into that repo's `CLAUDE.md` **before** deleting the
  file; the deletion task depends on the relocation task, not the reverse.
- **Four binders are in the `factiv` family**, outside this repo's context
  boundary. → Explicitly authorized for this change only, recorded here so the
  authorization does not read as standing permission for later work.
- **Seven repos means seven CI surfaces**, some with their own gates that may be
  stale in ways this change does not own. → Each is verified by the instrument
  after its PR merges; a repo whose gate blocks for unrelated reasons is reported,
  not worked around.
- **The instrument is the verification, and it only reads markers and byte
  identity.** It cannot tell whether a converted repo still *works*. → The
  `--fleet` run proves propagation, not correctness; each PR additionally shows
  the hook resolving and exiting 0 on a benign call in that repo.
- **No instrument reads hook matchers at fleet scope.** Verified:
  `project-hook-conformance.sh:306-309` opens `settings.json` only to enumerate
  override env vectors, and nothing else under `tools/` reads matchers. So the
  `MultiEdit` half of this change has no automated check, and "`--fleet` reports
  0" would have been cited as covering it. → The matcher assertion is a named
  manual task per repo, and the tooling gap is recorded here rather than left to
  be rediscovered.
- **The marker is racy between concurrent hooks.** Two matched calls entering
  `report_rate_limited` together can both read a stale marker. → Not mitigated.
  The worst outcome is one extra full report or one extra suppressed line;
  neither loses a signal, and locking a file that must stay behaviour-free costs
  more than the failure it prevents.
- **The `agenticapps-dashboard-add-agent-board` checkout is not in `FLEET` and
  its hooks do fire when that worktree is used.** The README's re-measurement
  counted it among the defective copies, so silence here would read as a
  contradiction. → Named, left unconverted, and the reasoning is in Open
  Questions rather than implied by omission.

## Migration Plan

1. Core: template + gate shim + **core's own self-hosting binder** + spec delta +
   tests, at 1.2.0. Merged first — the template is the authority the other seven
   are compared against, so any other order compares them to a version that does
   not exist yet. Core's binder is bumped and its `exit 0` corrected in the same
   pass, because a change that fixes the fleet's reporting while leaving the
   authority's own binder warning nobody would be this capability's own failure
   mode shipped once more.
2. `agenticapps-dashboard` and `cparx`: re-issue three shims each at 1.2.0.
3. The five inlining repos: convert, update `settings.json` matchers to
   `Bash|Edit|Write|MultiEdit`, and handle the `agents-task-viewer`
   `normalize-claude-md` opt-out by relocation-then-deletion.
4. `--fleet` reports 0 findings.

Rollback is per repo: the shims are additive replacements of files still in git
history, and no implementation is touched.

## Open Questions

- Whether `agenticapps-dashboard-add-agent-board` — a second checkout of
  `agenticapps-dashboard` on branch `chore/setup-codex-workflow`, carrying its own
  inlined copies — should be converted or left to die with the branch. It is not
  in `FLEET`, so the instrument neither sees it nor misses it. Recorded rather
  than resolved: it is a checkout, not a binder, and treating checkouts as fleet
  members would make the declared set depend on what happens to be on disk.
