# Code review — `feat/projects-bind-not-copy` (PR #89)

Stage 2 under §07, run 2026-08-08 in a cleared session with no implementation
context. It is filed here because every finding lands on
`one-enforcement-floor`'s code, but the diff also carries
`fresh-clone-needs-nothing`'s `init-project.sh`.

**Scope, corrected after the fact.** The review was run against `main...HEAD`
with a local `main` that was 32 commits behind `origin/main`, which framed it as
84 commits and 158 files. The real PR is `origin/main...HEAD`: **53 commits, 50
files, +9,675/−232** — 36 `.md`, 9 `.sh`, 4 `.yaml`, and the floor's
`pre-commit`. The stale base made the review a **superset** of the PR, never a
subset, so nothing went uncovered; and all five reviewed scripts were confirmed
to sit inside the true diff, so every finding below still lands.

What the superset wrongly swept in was the deletions — `provisioning-check.sh`,
`normalize-claude-md.sh`, `tools/lib/semver.sh` and `.planning/` are all already
on `origin/main`, merged by earlier PRs. **This PR is additive**: five new
scripts, five new test suites, and the plan artifacts. The judgements recorded
about those deletions below are still true; they are simply about `main`, not
about this PR.

The review surface is the ~1,000 lines of new shell in those five scripts, and
the ~2,900 lines of suite that exercise them.

## Stage 1 — Spec compliance

Discharged before code, per the v1.0.0 remap: `openspec validate --all` plus the
pre-code multi-AI reviews. Both are on disk and current.

- `openspec validate --all` — **14 passed, 0 failed**, re-run at review time.
- `REVIEWS.md` exists for all five open changes. `projects-bind-not-copy` and
  `diagram-is-the-surface` were reviewed twice.

No protocol violations found. One gap, recorded rather than blocking: this
Stage 2 is the first on a branch that is 84 commits deep, so it is reading three
sessions of accumulated code rather than one task's worth. That is the risk the
handoff named, and it is now discharged.

## Stage 2 — Code quality

**Verdict: pass-with-followups**, with one gating condition that is about
running the code, not about merging it.

### Evidence

Every claim below was reproduced before it was written down.

| Suite | Result |
|---|---|
| `install.test.sh` | 53 passed, 0 failed |
| `global-floor.test.sh` | 18 passed, 0 failed |
| `global-floor-bind.test.sh` | 18 passed, 0 failed |
| `init-project.test.sh` | 47 passed, 0 failed |
| `bind-openspec-tools.test.sh` | 29 passed, 0 failed |
| the seven suites CI invokes | 323 passed, 0 failed, 5 skipped |
| **total** | **488 passed, 0 failed** |

`shellcheck -S style` is clean on all five new scripts. The two informational
hits in `init-project.sh` are false positives: SC2094 flags an append-mode
redirect that cannot truncate, SC2016 flags backticks in prose.

### Critical — one, and it is already tracked

**C1. `install.sh` binds the global floor before the migration that makes the
binding safe exists.** `install.sh:346` calls `bind-global-floor.sh`
unconditionally. Neither Decision 5's enrolment migration (task 9.4a, open) nor
the local-binding guard (task 10.2, open) is implemented. Running `./install.sh`
today silently ungates every repository currently gated by a local hook —
including core itself.

Proven end to end in a sandbox, both halves:

1. Setting `core.hooksPath` displaces `.git/hooks/pre-commit` **entirely**. The
   local hook did not run, the floor hook ran in its place, and the commit
   landed.
2. The real floor dispatcher in an unenrolled repository exits 0 having printed
   **nothing at all**, and the commit lands. That is
   `reference-implementations/global-floor/pre-commit:82` doing exactly what it
   says it does.

Measured on this machine and still true: global `core.hooksPath` unset, core's
local unset, `agenticapps.workflow.enrolled` unset, core's own ADR-0028 hook
present at `.git/hooks/pre-commit`. So the displacement is latent and fires on
the first successful bind.

The blast radius is the gap between the two halves of the system. `install.sh`
binds the floor, `init-project.sh` establishes a repository, and **nothing in
the shipped code sets `agenticapps.workflow.enrolled`** — the only writes of
that key anywhere in the tree are in `global-floor.test.sh`. So the floor, once
bound, governs nothing while having removed what did.

Merging changes nothing. Running does. The condition is therefore: **do not run
`./install.sh` on a machine you care about until 10.2 and 9.4a land.** Recovery
if it is run is `git config --global --unset core.hooksPath` — the local hooks
are displaced, not deleted.

### Important — two, both in `bind-openspec-tools.sh`

**I1. It reports skills as bound that it explicitly declined to bind.**
`link()` returns 0 on both collision paths (lines 73 and 78), so the caller's
`link … && n=$((n + 1))` at line 125 counts a collision as a success.

Reproduced with three colliding destinations: the script printed three
`collision: … left alone` lines and then `skills: 3 bound into ~/.claude/skills`,
having created **zero** symlinks. `rc=1` is correct, and `install.sh:313` does
print "opsx tooling: not fully bound" — so the run contradicts itself in two
adjacent lines rather than lying outright. The count is still false.

Fix: `return 1` on the two collision paths, or increment only on a successful
`ln`. Note that line 80's `mkdir -p … && ln -s …` also fails silently — a
failed `ln` there is neither counted nor reported.

**I2. A bare `--host` aborts with a shell error, not a usage error.**
`bind-openspec-tools.sh --host` dies with `line 49: $2: unbound variable`,
because `set -u` is on and the arm shifts 2 without checking `$#`. `--store` and
`--home` have it too.

This is the defect `install.sh:328-330` fixes by name, with a passing regression
test — "a bare `--host` is a usage error, not a shell error". The sibling script
`install.sh` calls did not get the same fix. Confirmed side by side: `install.sh
--host` prints `--host needs a host name` and the usage block.

### Minor — four

**M1. `install.sh:283`** gates the project-hook success line on `[ "$SKIPPED" =
0 ]`. A run where an artifact publish failed but the project hooks published and
attested cleanly omits the attestation line entirely. It conflates "this step
succeeded" with "no earlier step failed".

**M2. `bind-openspec-tools.sh:114`** — the `[ -z "$skills" ]` branch is
unreachable. All five host arms set a non-empty `skills`; an unknown host
`continue`s at line 107. The comment above it describes a behaviour that cannot
occur, which is precisely the "dead text is read as a live guarantee" failure
`install.sh:108` names when it deletes a dead consent rule.

**M3. `install.sh:341`** — `--host auto` replaces `REQUESTED` wholesale. On a
machine without claude installed, `--host auto --host claude` silently drops the
explicit request. Last-writer-wins across a detected set and a named one.

**M4. `init-project.sh:116-117`** — on the collapse path `rm -f CLAUDE.md`
precedes `ln -s`, so a failed link leaves the repository with no `CLAUDE.md` at
all, and the `die` message does not say it was just removed. No data loss:
`cmp -s` at line 56 has already proven the two files byte-identical, so the
content survives in `AGENTS.md`. `install.sh:190-193` handles the same ordering
and reports it explicitly; this one does not.

### Spec drift — one

**D1.** `openspec/specs/project-hook-binding/spec.md` — the **current** spec
slot, not a delta — names `normalize-claude-md` as the live instance of a shim
class in seven places, including the registration table at line 1472. This
branch deletes the implementation. The removal is planned in
`diagram-is-the-surface`'s `vestigial-surface-removal` delta, which is 0/46
tasks done.

`validate` is green through this because it is a schema check, which is the
distinction the workflow's own rationalisation table draws.

### Verified and NOT defects

Recorded so they are not raised again.

- **`newer()`'s `sort -V`** works on this macOS box (`1.9.0` sorts below
  `1.10.0`). The deleted `tools/lib/semver.sh` had exactly one remaining
  caller, `provisioning-check.sh`, which this branch also deletes. Clean
  removal, no orphan.
- **`install-core-git-hooks.sh` will not overwrite the published floor hook**
  after a global bind. It resolves through `git rev-parse --git-path hooks`,
  which honours `core.hooksPath`, so it would target the published directory —
  but the whole-line marker check at line 219 (`grep -qxF`, deliberately not a
  substring match) refuses a file it did not write. The second-order corruption
  is guarded.
- **The surviving references to the deleted scripts** in
  `tools/spec-placement.test.sh` and `tools/project-hook-shim.test.sh` are prose
  in comments and test names, not executable paths. `ARTIFACTS` documents the
  deletion in its header. No dangling references; both suites pass.

### What is good, and worth saying

The reasoning-in-comments discipline is doing real work here rather than
decorating. `bind-global-floor.sh`'s publish-then-bind ordering argument, the
`hooks.d` symlink check placed deliberately before `mkdir`, and the
`resolved_dir_of` bound against symlink cycles are each a defect that was
measured and then closed, with the measurement left in place. The
`preserve()` quoting note — a home directory with a space turned the advertised
restore command into two wrong ones — is the kind of thing only found by
someone actually reading their own output.

## Followups

| # | Action | State |
|---|---|---|
| **C1** | Land 10.2, then 9.4a, before anyone runs `install.sh` | **open** — `one-enforcement-floor` §10 and 9.4a |
| I1 | `link()` returns 0 only for a link that exists; a failed `ln` is named | fixed, §10.1–10.2 of `fresh-clone-needs-nothing` |
| I2 | `$#` guarded on `--host`/`--store`/`--home` | fixed, §10.3 |
| M1 | The project-hook line keys on its own exit status | fixed, §11.1 of this change |
| M2 | The unreachable `[ -z "$skills" ]` branch removed | fixed, §10.4 |
| M3 | `--host auto` adds to the named set | fixed, §11.2 of this change |
| M4 | `init-project.sh` replaces `CLAUDE.md` atomically | fixed, §10.5 |
| D1 | Covered by `diagram-is-the-surface` | open — that change is 0/46 |

## The fixes need their own Stage 2

Everything in the Followups table marked *fixed* was written **after** this
review, by the reviewer. §07 forbids the implementer authoring Stage 2, so this
document does not cover them and must not be read as though it does.

The delta is small and self-contained — three scripts, two suites, 16 new test
cases — and it is a fair scope for a single independent pass rather than another
whole-branch review. What it should look at:

- `install.sh` is at **exactly** its 217-line budget. Both fixes were written
  long, measured at 229, and compacted to fit. Compaction under a budget is
  where clarity gets traded away quietly; the two-statement `if/else` on one
  line in `publish()` is the place to look first.
- The `--host auto` fix strips the literal token with `sed 's/ auto / /g'`. No
  host is named `auto` and none contains it, so this is safe today. It is
  string surgery on a word list, and it would stop being safe the moment a host
  name contained the substring.
- `init-project.sh` now writes `.CLAUDE.md.init-project.$$` into the operator's
  repository before moving it over `CLAUDE.md`. The window is closed, but the
  temp file is briefly visible in a directory the operator owns, and `$$` is not
  a security boundary.
- Two of the new assertions initially passed or failed for the wrong reason and
  were corrected in place. Both corrections are recorded in the test comments;
  they are worth re-reading, because a test that once passed vacuously is the
  kind that goes back to passing vacuously.
