# Tasks — the rosters name only what can exist

**Sized to the diff.** Four rosters, three deletions, one branch removal, one
narrow spec amendment. Every task below either deletes something, asserts what is
left, or corrects a sentence that describes what is gone. If this list grows a
task that *adds* behaviour to a harness, something has been smuggled in.

Removals get TDD the same as anything else, inverted: the assertion of the new
state is written and observed RED before the thing it describes is removed. Two
tasks below say explicitly what would make a RED vacuous, because plan review
caught one that was.

Revised after step 2b — `REVIEWS.md` carries both reviews and every resolution.
The §3 and §4 shape changed materially: the resolver is retired here rather than
deferred, and §0 exists because the deletions in §4 were forbidden as drafted.

## 0. The amendment first, because everything in §4 depends on it

- [x] 0.1 Land the `vestigial-surface-removal` delta: the record/instrument
      distinction and its three conditions. It is first because tasks 4.2 and
      4.4 are forbidden by the capability as it currently reads, and doing them
      first would be shipping the thing the spec says not to and amending the
      spec afterwards to match — the red flag this workflow names by name.
- [x] 0.2 For each artifact §4 deletes, record the three conditions **as
      measured**, not asserted: the declared subject, evidence every entry in it
      is retired, and the sweep showing no other input supplies a subject. The
      requirement demands this be recorded; §4's tasks each name their evidence.

## 1. FLEET drops the retired repository

- [x] 1.1 Remove `agents-task-viewer` from
      `reference-implementations/project-hooks/FLEET` and record it in the
      tombstone comment block already at the foot of that file, matching the
      2026-08-08 entry in form and dating it 2026-08-10 (the retirement) rather
      than today.
- [x] 1.2 Run `tools/check-shims.sh` and confirm no `MISSING REPO` line. Confirm
      the remaining four names still resolve — they are under `factiv/`, not
      `agenticapps/`, so a root assumption would break them silently.
- [x] 1.3 Run `tools/check-shims.test.sh`. It builds synthetic FLEET fixtures and
      must be unaffected; if it is affected, the fixture was coupled to real
      membership and that is a finding.

## 2. The two conformance rosters

- [x] 2.1 **RED first.** Add to `tools/conformance-harness-reporting.test.sh` an
      assertion that each `--family` roster declares exactly `core` and
      `shared-install` — a literal declaration, so an entry added later has to be
      added here too, deliberately. Observe it fail against the six-entry roster.
- [x] 2.2 Trim `ROSTER` in `tools/change-gate-conformance.sh` (lines 1073–1076)
      and `tools/reviewer-cli-conformance.sh` (lines 269–272) to the two entries,
      each with a dated tombstone comment naming the four repositories, the
      2026-08-05 archival and the 2026-08-12 deletion.
- [x] 2.3 Observe 2.1 GREEN. Run both harnesses with `--family` and record the
      coverage line each now prints; `roster_total` must read 2, not 6.
- [x] 2.4 Correct what the sweep claims, in both harnesses' own comments: two
      entries measure **publish drift** — working tree against published copy —
      and not fleet coverage. A `scored 2 of 2` over the authority and a copy of
      the authority reads as fleet coverage to anyone who does not open the
      roster.

## 3. Pin-and-resolve comes out, resolver included

- [x] 3.1 **RED first, and it must be a real one.** Assert that
      `change-gate-conformance.sh --family --resolve` exits non-zero with a usage
      error. This fails today — the flag is accepted — so it is a genuine RED.
      Do **not** also assert that output lacks the resolvable-but-not-attempted
      string: no host directory holds a resolver and manifest, so that assertion
      passes before the change and proves nothing. Plan review caught this, and
      the delta itself argues against exactly this shape for J3.
- [x] 3.2 Remove from `tools/change-gate-conformance.sh`: the `--resolve` flag,
      its usage text, its argument parsing, the `RESOLVE` guard, the
      scratch-directory resolve machinery and its cleanup, and the
      `resolve-core-artifact.sh` + `core-vendor.manifest` probe in the roster
      loop. An absent entry falls through to its screening reason.
- [x] 3.3 Remove the same probe and reason string from
      `tools/reviewer-cli-conformance.sh`, which implements the reporting half
      only.
- [x] 3.4 Delete assertion J3 from `tools/conformance-harness-reporting.test.sh`.
      Deleted rather than inverted: J3 asserts a reporting behaviour that no
      longer has a requirement, and an inverted J3 would assert the absence of a
      string, which passes for a harness that prints nothing at all.
- [x] 3.5 Retire `reference-implementations/shared-install/resolve-core-artifact.sh`.
      It is a published interface artifact and inside `vestigial-surface-removal`'s
      governed class as that capability already reads — this deletion needs no
      part of §0. Evidence: no `core-vendor.manifest` and no vendored resolver
      exists anywhere under `~/Sourcecode`.
- [x] 3.6 Retire `tools/resolve-core-artifact-conformance.sh` under §0, and
      remove its row from `tools/conformance-harness-reporting.test.sh` (line 64,
      `resolve-core-artifact-conformance.sh:S:norost`). Its declared subject was
      the one artifact 3.5 deletes; it takes no other target.
- [x] 3.7 Check whether any requirement in `conformance-harness-reporting` names
      `resolve-core-artifact-conformance.sh` beyond the shapes list already in
      the delta. If one does, it needs a delta; if none does, record that it was
      checked.
- [x] 3.8 Observe 3.1 GREEN. `shellcheck -S warning` clean on both harnesses.

## 4. `drift-report.sh` is retired

- [x] 4.1 Record its final measurement in `CHANGELOG.md` before deleting it —
      `OK: 0 · DRIFT: 0 · SKIP: 60` on 2026-08-12 — because after the deletion
      nothing can produce that number again.
      **Done, but not in the order written.** The number was captured in
      `proposal.md` and committed before the deletion; the `CHANGELOG.md` entry
      was written after, with the rest of §6. The requirement was that the
      measurement outlive the tool, and it did — but the task said CHANGELOG and
      the CHANGELOG came second, so this is recorded rather than ticked silently.
- [x] 4.2 Delete `tools/drift-report.sh` and `tools/drift-report.test.sh` under
      §0. Evidence for the three conditions: its subject is declared in the
      `HOSTS` array; all four entries are the host repositories deleted
      2026-08-12; and it takes only a hosts-directory path, which selects where
      to look for `HOSTS` rather than supplying a different subject.
- [x] 4.3 Confirm by sweep that nothing invokes either: `install.sh`, the git
      hooks, CI, and every other file under `tools/`. Prose hits are §5's.

## 5. The prose that describes what is gone

Each reference is classified before it is touched — a dated measurement record
stays as history, a live instruction is corrected. That is the distinction
`vestigial-surface-removal` already draws between deletion and correction.

- [x] 5.1 `spec/09-conformance.md` — the `## Drift` section describes
      `drift-report.sh` as the advisory check. Rewrite it to state that
      canonical-prose drift is no longer measured by a tool in this repository,
      why, and that re-scoping such a check is a decision deferred until there is
      a subject for it. Do not delete the section and leave §09 silent on drift.
- [x] 5.2 `spec/20-conformance-harness-reporting.md` — remove the pin-and-resolve
      security rules (around lines 140–156) and the `## Out of scope` paragraph
      naming `drift-report.sh`. This file is the published section of the same
      capability; if it and the openspec spec disagree after this change, one of
      them is wrong.
- [x] 5.3 `GATE-INVENTORY.md:67` — the row reads `migration framework +
      drift-report | KEEP`. Change the verdict to RETIRED for the drift-report
      half, naming the date; keep the row and keep the migration-framework half
      intact, because the inventory's value is that it records what was decided
      about each item.
- [x] 5.4 `README.md` — `:103` and `:137` present `drift-report.sh` as the
      current advisory check, and `:17–26` present the four host repositories as
      the current fleet. Both are live instructions and are corrected.
- [x] 5.5 `reference-implementations/README.md` — `:61–64` are the per-host
      conformance rows and `:82–97` describe what `drift-report.sh` scores. The
      rows are dated measurement records and stay; what must change is anything
      stating these hosts are the **current** fleet or that the tool scores them
      **now**. Classify each before editing.

## 6. Close it out

- [x] 6.1 `openspec validate --all` green.
- [x] 6.2 Step 4 code review on the diff by a reviewer of another vendor.
      **One vendor, not two.** gemini reviewed and found one TRIVIAL finding,
      accepted and fixed. codex timed out at both 300s and 550s on the
      1,503-line diff prompt, having reviewed this change's plan successfully at
      step 2b — a size or load problem, not an unavailable CLI. Recorded in
      `REVIEWS.md` under *Not counted*; a timed-out reviewer counts as no
      reviewer.
- [x] 6.3 `CHANGELOG.md` entry covering the four rosters, three retirements, the
      removed requirement and the amended one.
- [x] 6.4 Full suite: `tools/conformance-harness-reporting.test.sh`,
      `check-shims.test.sh`, and both harnesses under `--family`.
