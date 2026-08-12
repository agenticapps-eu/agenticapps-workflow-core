# The rosters name only what can exist

## Why

Four host repositories — `claude-workflow`, `codex-workflow`, `opencode-workflow`
and `pi-agentic-apps-workflow` — were archived on GitHub on 2026-08-05 and their
checkouts deleted on 2026-08-12. `agents-task-viewer` was retired on 2026-08-10.
Five repositories are gone; three rosters in this repository still declare them.

A roster is a **declaration**, and that is the whole reason this repo has them.
`reference-implementations/project-hooks/FLEET` says it in its own header: an
expected set discovered from what you happened to find cannot detect a missing
member. The corollary is the defect here — a declared member that cannot exist
is a claim about coverage that will never come true, and every sweep that reads
it reports the same absence forever. `check-shims.sh` has printed
`MISSING REPO  agents-task-viewer` since 2026-08-10.

Measured on 2026-08-12, before any edit in this change:

| Roster | Declares | State |
|---|---|---|
| `tools/change-gate-conformance.sh` | 6 | scores 2; four are the dead hosts |
| `tools/reviewer-cli-conformance.sh` | 6 | scores 2; assertions fell 57 → 38 |
| `tools/drift-report.sh` | 4 | scores **0**; every entry is a dead host |
| `reference-implementations/project-hooks/FLEET` | 5 | 4 resolve; `agents-task-viewer` does not |

`drift-report.sh` is the finding the handoff did not carry. Its `HOSTS` array is
exactly the four dead repositories and nothing else, so the tool now runs to
completion reporting `OK: 0 · DRIFT: 0 · SKIP: 60`. It has no subject left. That
is not a stale entry in a working instrument; it is an instrument whose entire
subject was retired, which is what `vestigial-surface-removal` means by an
artifact reached for on the strength of its name.

## What changes

The three rosters are trimmed to what can exist, and the surfaces left with no
possible subject go with them.

`FLEET` drops `agents-task-viewer`. The two conformance rosters drop the four
host repositories and keep `core` and `shared-install`. `tools/drift-report.sh`
and its test are deleted.

The **pin-and-resolve** reporting branch is removed from both conformance
harnesses, along with `--resolve` on `change-gate-conformance.sh`. This is a
consequence of the roster trim rather than a separate opinion: the branch fires
only for a roster entry that is absent *and* whose host ships
`bin/resolve-core-artifact.sh` and `tools/core-vendor.manifest`. Every entry that
could satisfy that is one of the four. Measured 2026-08-12: no
`core-vendor.manifest` and no vendored resolver exists anywhere under
`~/Sourcecode`. The requirement governing that branch is removed with it, because
a SHALL nothing can reach is a rule that cannot be violated or satisfied.

**The published resolver goes with it.** An earlier draft kept
`reference-implementations/shared-install/resolve-core-artifact.sh` and its
harness on the grounds that retiring them was a separate judgement. Both plan
reviewers rejected that independently, and they were right: this change removes
the resolver's only harness integration, its reporting distinction and the
path-confinement security contract a future adopter would need, so keeping the
resolver published would leave an interface whose safety rules had to be
reconstructed from an old commit. Coherence is the argument — either the
mechanism is offered with its contract intact or it is retired whole.
`resolve-core-artifact.sh` and `tools/resolve-core-artifact-conformance.sh` are
therefore retired here.

Removals are recorded rather than performed silently — each roster keeps a dated
tombstone comment naming what left and when, which is the treatment `FLEET`
already gives `agenticapps-dashboard` and `agenticapps-roadmap`.

## The one amendment this needs

`vestigial-surface-removal` exempts `tools/` and "every test harness" from
deletion, and decides genuine ambiguity toward retention. Read as written it
forbids retiring `drift-report.sh`, its test, and
`resolve-core-artifact-conformance.sh` — and the first draft of this proposal
cited that same capability as its warrant for doing so, which it does not grant.
A plan reviewer caught it; it was verified by reading, not conceded.

The exemption is right and is not being loosened generally. It gets one narrow
carve-out: a **record** documents what was true, while an **instrument**
measures a subject it declares, and an instrument whose declared subject has
been *entirely* retired is neither. It records no past measurement and performs
no present one. Three conditions must all hold — the subject is declared, every
entry in it is retired, and the instrument has no remaining subject through any
other input — and where any one fails, the exemption stands. "Nobody runs it" is
not this condition, and neither is an empty roster on an instrument that also
takes arguments; `check-shims.sh` with an empty `FLEET` is the case the third
condition exists to protect.

## Non-goals

The two `agents-task-viewer` mentions in `openspec/specs/project-hook-binding/spec.md`
(`:389`, `:1251`) are untouched. They are dated measurement records — true when
written — not declarations anything reads. The same test is applied to every
host-repository reference in `README.md` and
`reference-implementations/README.md`: a dated record stays, a live instruction
is corrected, and each is classified before it is touched.

## Impact

`change-gate-conformance.sh --family` and `reviewer-cli-conformance.sh --family`
report a roster of 2 instead of 6, and their coverage lines stop naming four
absences that will never be filled. `check-shims.sh` reports no `MISSING REPO`.
The canonical-prose drift check ceases to exist; nothing invoked it, and it has
certified nothing since the last host checkout was deleted.

**What `--family` proves is restated rather than quietly reduced.** With two
entries it measures publish drift — whether the bytes this repository ships are
the bytes an installed machine runs — and no longer says anything about
independent host implementations, because there are none. The flag keeps its
name for its callers; the claim attached to it does not survive unedited. A
coverage line reading `scored 2 of 2` over the authority and a copy of the
authority would otherwise read as fleet coverage to anyone who did not go and
look at the roster.
