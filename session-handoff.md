# Session Handoff — 2026-08-04 (fourth session of the day)

## Accomplished

- **Group 3 verified live** through a deployed 1.2.0 shim. Both defects
  reproduce and are gone; the 1.1.0 counterfactual was run beside each so the
  fix is measured against the defect, not against nothing.
- **All seven fleet PRs opened** (groups 5 and 6). None merged.
- **The group 6 premise was found false**, which is the session's real result.
- Core evidence branch `chore/fleet-propagation-evidence` pushed, with
  `PROPAGATION-EVIDENCE.md` new and tasks 3.x, 5.x, 6.x, 7.2–7.5, 8.1 ticked.

### The finding: the instrument measured this laptop and called it the fleet

`--fleet` scans **working trees**. Six of the seven checkouts here were behind
their remotes by up to eleven commits, and in five of them the unpulled commits
were exactly the ones that had already shimmed the hooks at 1.1.0 on
2026-08-02. **The whole fleet was already shimmed, with correct matchers.** The
inlined copies, the narrow `Bash|Edit|Write` registrations, the `migrations/`
block with its `/gsd-discuss-phase` remedy — all real, all on this disk only.

So of the 46-finding baseline, 15 unrecognised markers and 4 narrow matchers
described stale local files. No repo needed a matcher edit. Group 6 needed
exactly what group 5 needed: a 1.1.0 → 1.2.0 re-version.

It cost a wrong PR first: roadmap #13 was opened claiming to unblock
`migrations/*` with live before/after exit codes — real codes, produced by
running stale files. Corrected in place (merged with current main, body
rewritten to name the mistake) rather than force-pushed away.

**The instrument fix is deliberately not taken.** Reporting each project's
checkout state beside its findings is its own change.

## The seven PRs

| Repo | PR | Note |
|---|---|---|
| `agenticapps-dashboard` | #99 | |
| `cparx` | #124 | cross-family, stated in the body |
| `agenticapps-roadmap` | #13 | body corrected; net diff now matches the rest |
| `callbot` | #100 | |
| `fbc-platform` | #105 | built in a worktree — that checkout is mid-feature |
| `fx-signal-agent` | #120 | |
| `agents-task-viewer` | #18 | 2 shims + ADR 0009 + `bin/README.md` |

## Decisions

- **3.1 done with a stated deviation.** The shared implementation was NOT
  renamed away — a second Claude session was live in `agenticapps-dashboard`.
  `HOME` was pointed at a same-shaped empty tree instead: identical branch,
  clears the marker by construction, no global side effect.
- **6.5a's premise was wrong; its other branch was taken.**
  `agents-task-viewer`'s `bin/openspec-change-gate.sh` is not orphaned — CI
  invokes it and fails without it, and `core-vendor.manifest` pins its sha256.
  Kept, with the note in `bin/README.md` beside the file, because editing a
  pinned file breaks the pin.
- **The note omits the override variable's name on purpose.** Naming it costs a
  permanent override-vector finding on every fleet scan. Verified both ways: one
  finding with, zero without.
- **6.6 became a recovery, not a relocation.** The rationale's file was deleted
  upstream in `ac13485` before this ran, so it survived only in git history. Now
  ADR 0009, linked from `CLAUDE.md` outside every GSD block.

## The theme, now at sixteen

15. **A confident answer to a question nobody asked.** `--fleet reports 46` was
    the same false-clearance shape as `--fleet reports 0`, pointing the other
    way: right about the disk, wrong about the fleet, and unable to tell the
    two apart in its own output.
16. **A task list ages into fiction.** Four of group 6's tasks described a state
    that had already changed — including one whose stated dependency had already
    been violated upstream, destroying the thing it existed to protect.

## Files modified

On `chore/fleet-propagation-evidence` (core, pushed, no PR yet):

- `openspec/changes/.../PROPAGATION-EVIDENCE.md` — **new**; baseline
  composition, group 3 live runs with 1.1.0 counterfactuals, the staleness
  finding, groups 5–6, and 7.2/7.2a/7.5
- `openspec/changes/.../tasks.md` — 3.x, 5.x, 6.x, 7.2–7.5, 8.1 ticked; group 6's
  heading corrected in place rather than rewritten

## Next session: start here

**Merge the seven fleet PRs, then `git pull` each of the seven checkouts**, and
only then re-run `tools/project-hook-conformance.sh --fleet ~/Sourcecode` for
task 7.1. Pulling is not housekeeping here — it is the difference between
measuring the fleet and measuring this laptop again, which is the mistake this
session made. Then core PR 2 (task 8.3) carries group 7's evidence, group 4's
README corrections and the archive, and 8.4's second half is its review in a
cleared session.

## Open questions

- **7.1's target of "0 findings, down from 30" is wrong twice.** The baseline is
  46, and 0 is unreachable while the override-vector axis reports docs prose.
  Decide what number 7.1 should actually assert before running it.
- **A second Claude session was live in `agenticapps-dashboard`** and checked out
  a branch off this work's commit mid-run. Worth knowing before assuming a repo's
  checkout is yours alone.
- **`callbot` has an unpushed local commit on `main`** (`e962111`). Untouched;
  its PR branch was cut from `origin/main`.
- **A `git worktree` for `fbc-platform` is still registered** at the scratchpad
  path. Remove it once #105 merges.
- **27 branches carry genuinely unmerged content**, still unjudged for worth.
- The convergence rule is still unwritten — twelfth session.
- **Two neuroflash PRs remain open** (api-docs #14, terraform #185) — different
  family, untouched.
