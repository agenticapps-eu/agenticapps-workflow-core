---
reviewers: [gemini, codex]
models: [gemini-3-pro, gpt-5.2-codex]
verdicts: [REQUEST-CHANGES, REQUEST-CHANGES]
reviewed_artifacts_sha: c4e7a4b6fad998bc
round: 2
scope: the retire-the-publisher decision folded in on 2026-08-09
---

# Change review — projects-bind-not-copy, round 2

Round 1 is in `REVIEWS.md` and reviewed the change as originally written. This
round reviews only what was added on 2026-08-09: retiring the project-hook
publish subsystem while keeping the bind half. Both reviewers returned
REQUEST-CHANGES. **The round did its job — it falsified two of the eight
requirement removals and one of the design's central risk claims.**

## Reviewer: gemini (gemini-3-pro)

VERDICT: REQUEST-CHANGES

- **[HIGH]** spec delta / "No project binds any fleet hook once the surface is
  closed" — the delta says `SHIMMED-HOOKS` is empty *and* requires it to carry
  machine-readable tombstones for retired hooks. A file cannot be both.
- **[MEDIUM]** spec delta / MODIFIED "A hook implementation is authoritative in
  one place" — the drift scenario promises a report no surviving tool produces;
  integrity now rests on a mutable version string inside the file.

## Reviewer: codex (gpt-5.2-codex)

VERDICT: REQUEST-CHANGES — 9 HIGH, 3 MEDIUM. The ones that changed the design:

- **[HIGH]** `install.sh:check_artifact()` already reports byte drift, so the
  claim that a hand-edited artifact becomes undetectable is false. The real loss
  is durable installation provenance, not drift detection.
- **[HIGH]** Several removals have semantics that survive in
  `install-shared-artifact.sh` and `install.sh --check`. "Different mechanism"
  is not "capability retired" — move them rather than remove them.
- **[HIGH]** `proposal.md:251` and `design.md:33` promise no change to
  `install.sh`, while tasks 3.13d–e modify it and its suite.
- **[HIGH]** `shim-template.sh` — the retained bind half documents the deleted
  publisher, so the checker's authority would name a nonexistent installer.
- **[HIGH]** The reader test is applied inconsistently: with `SHIMMED-HOOKS`
  empty, `openspec-change-gate.shim.sh` is read only by its own test — the same
  argument used to delete the manifest.
- **[MEDIUM]** 3.13a's RED is factually wrong: `install.sh --check` already
  reports no project-hook set, so that assertion cannot fail.
- **[MEDIUM]** 3.13h–i cleanup misses stale publisher references outside the
  README; add an `rg` assertion over the retired names.
- **[MEDIUM]** 3.13g deletes `manifest.tsv` on a consumer search bounded by this
  repository, which does not establish that nothing outside it reads the file.

## Where the reviewers disagree, and what settled it

Gemini's MEDIUM and codex's second HIGH make opposite claims about the same
code. **Codex is right and gemini is wrong**, verified by reading
`install.sh:check_artifact()`:

```sh
if cmp -s "$dst" "$src"; then say "  $name $pv current"
elif [ "$pv" = "$cv" ]; then say "  $name $pv MODIFIED — same version as checkout, different bytes, not current"
```

The byte comparison runs *before* the version comparison, and the
same-version-different-bytes case is reported by name. So drift of the executed
copy against the maintained source is detected today, for every surviving
artifact, and the MODIFIED requirement's drift scenario is satisfied rather than
orphaned.

## A finding neither reviewer made

Following gemini's HIGH one level further: **`check-shims.sh` has no reverse
pass at all.** Its only loop iterates `decl "$DECL/SHIMMED-HOOKS"` and asks
whether each declared hook is bound. Tasks 2b.1–2b.5, which specify the pass
over what a repository *holds*, are all open. With the declaration empty the
loop never executes, so the tool walks every repository, examines nothing, and
says so.

That is honest — it is exactly what 2b.6 fixed in PR #94 — but it means the
design's justification for keeping the bind half was overstated. The bind half
is not "driven by live code that checks something"; it is driven by live code
that currently checks nothing and whose checking half is specified and unbuilt.
The distinction from the publish half survives, but it is a different one:

| Half | Current subject | Planned subject |
|---|---|---|
| publish | none | none — no task in any change proposes a future project-hook artifact |
| bind / check | none | tasks 2b.1–2b.5, open, which read all four declaration files and the template |

## Resolution

| # | Finding | Resolution |
|---|---|---|
| 1 | codex: `check_artifact` reports drift | **Accepted.** The risk paragraph claiming a hand-edited artifact is undetectable is false and is being rewritten to the actual loss: durable historical attestation of what was installed, independent of the checkout's current state. |
| 2 | gemini: no tool reports drift | **Rejected**, disproved by the same code. Recorded because a reviewer's finding that survives unchallenged becomes fact. |
| 3 | codex: surviving semantics wrongly removed | **Accepted, and it corrects the classification.** "Currency is judged against an authority checkout" is implemented by `check_artifact()`, and "The implementation version marker is compared" by `install-shared-artifact.sh`'s arbitration. Both move rather than being removed. Six removals stand, not eight. |
| 4 | gemini + codex: tombstones vs empty | **Accepted.** The tombstone paragraph is the older answer to a problem the delta already solves with a resolution-based discriminator, left standing beside its replacement. Reconciled to one rule. |
| 5 | codex: `install.sh` Non-Goal contradiction | **Accepted.** `proposal.md:251` and `design.md:33` are amended; the installer contract does change and the change must say so. |
| 6 | codex: `shim-template.sh` documents the dead publisher | **Accepted.** Added to 3.13 as a task rather than left "untouched". |
| 7 | codex: gate shim's only reader is its test | **Accepted with a distinction.** Unlike the manifest, it is the expected-bytes authority the planned reverse pass compares against, and the gate implementation it names still exists in `~/.agenticapps/bin/`. Stated explicitly so the reader test is applied consistently rather than selectively. |
| 8 | codex: 3.13a's RED cannot fail | **Accepted.** Verified: `install.sh --check` prints no project-hook line today. The assertion is replaced. |
| 9 | codex: cleanup coverage, manifest consumer scope | **Accepted.** An `rg` sweep over the retired names, and 3.13g states the search boundary rather than implying a global one. |
| 10 | codex: ADR for the unmitigated SQL regression | **Deferred, not dismissed.** The decision was taken on 3.9d and recorded; an ADR is the right home for it and is a separate act from this change. Logged as an open item. |
| 11 | codex: transition mechanism conflict (2b.9) | **Pre-existing**, raised in round 1 and unresolved there. Not introduced by this decision and not resolved by it. |
| 12 | own finding: no reverse pass exists | **Accepted.** The design's claim is corrected to the table above. |
