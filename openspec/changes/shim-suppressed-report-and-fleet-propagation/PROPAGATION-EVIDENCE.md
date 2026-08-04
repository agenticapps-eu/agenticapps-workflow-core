# Propagation evidence

The change's central claim is that contract 1.2.0 reached the fleet and that the
two defects it repairs are gone on the surface they appeared on. This file holds
the evidence for that claim as it accumulates, so core PR 2 cites recorded
output rather than a recollection of having seen it.

Everything below was run on 2026-08-04 against the merged instrument
(`8e7fcd4`), not against a working copy of it.

---

## The pre-rollout baseline — 46 findings

```
$ tools/project-hook-conformance.sh --fleet ~/Sourcecode
...
46 finding(s) reported above. This tool reports; it does not block.
```

Composition, which matters because the total alone hides what moved:

| Axis | Count | What they are |
|---|---:|---|
| `MARKER` | 21 | 6 stale at 1.1.0 (dashboard, cparx) + 15 unrecognised (the five inlined-copy repos) |
| `IDENTITY` | 21 | every bound shim in all seven repos differs from core's authority |
| `MATCHER` | 4 | `database-sentinel` registered `Bash\|Edit\|Write` in four repos, declared `Bash\|Edit\|Write\|MultiEdit` |

The `MATCHER` findings are easy to miscount from the output: the tool strips the
`FINDING` suffix before printing (`project-hook-conformance.sh:454`), so a
coverage finding and an informational "covers the declared set" line look alike
on the page and differ only in whether they were counted. 21 + 21 + 4 = 46.

---

## Group 3 — the defects, live, through a deployed 1.2.0 shim

Run through `agenticapps-dashboard`'s `.claude/hooks/database-sentinel.sh` after
group 5.1 re-issued it — a real project binder, not a fixture.

### Deviation from task 3.1, stated rather than quietly taken

Task 3.1 says to rename `~/.agenticapps/bin/database-sentinel.sh` away. It was
**not** renamed. A second Claude session was live in `agenticapps-dashboard` at
the time (it checked out a branch off this work's commit mid-run), and renaming
the shared implementation would have put that session's hooks on the fail-open
path for the duration.

Instead `HOME` was pointed at a tree of the same shape with an empty
`.agenticapps/bin/`. The shim derives `SHARED="$HOME/.agenticapps/bin/$HOOK.sh"`
and `STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/agenticapps"`, so this
reaches the identical branch with an identical directory layout — the directory
exists and the file does not, exactly as after a rename — and additionally
satisfies 3.1's "clear the rate-limit marker" by construction. The real shared
bin and the real marker were confirmed untouched afterwards (marker mtime still
09:14, i.e. before this run).

What this does **not** cover: nothing here exercises the real
`~/.agenticapps/bin` path itself. The claim is about the shim's branch, not
about that directory.

### 3.1 / 3.2 — three consecutive matched calls, contract 1.2.0

| Call | Exit | stderr |
|---:|---:|---|
| 1 | 1 | 4 lines — `database-sentinel hook: not installed at … — this hook did NOT run, and the tool call was allowed`, then the remedy and `Full notice at most once per hour per hook; see shim-contract 1.2.0.` |
| 2 | 1 | 1 line — `database-sentinel hook: still not installed at … — this call was allowed; full notice already made this hour` |
| 3 | 1 | 1 line — identical to call 2 |

Calls 2 and 3 render a notice **with content**, and the content says it is a
repeat. 3.2 is satisfied.

### The same three calls under 1.1.0 — the defect reproducing

Rendered from `d225954`'s template, run identically:

| Call | Exit | stderr | What the host shows |
|---:|---:|---:|---|
| 1 | 1 | 4 lines | the full notice |
| 2 | 1 | **0 lines** | `hook error — No stderr output` |
| 3 | 1 | **0 lines** | `hook error — No stderr output` |

The exit code is identical in both revisions — which is the whole point. The
limit never suppressed the interruption; it only ever suppressed the content,
and 1.1.0 therefore interrupted exactly as often while saying nothing.

### The occupied shared path — Stage-2 finding 6's second half

A directory at `$HOME/.agenticapps/bin/database-sentinel.sh`:

| Contract | Exit | stderr |
|---|---:|---|
| 1.2.0 | 1 | `database-sentinel hook: … exists but is not an executable regular file — this hook did NOT run, and the tool call was allowed`, then `Something other than the published implementation occupies that path.` and the remedy |
| 1.1.0 | **126** | bash's own `is a directory` / `cannot execute: Undefined error: 0` — not this contract's exit code, and no sentence naming the hook or saying the call was allowed |

### 3.3 — restored and re-verified

Nothing was renamed, so there was nothing to restore; the real environment was
re-checked rather than assumed:

- `~/.agenticapps/bin/database-sentinel.sh` — present, 5.2k, mode 0755
- benign `Edit` through the dashboard shim → **exit 0**
- `psql -c "DROP TABLE users"` through the dashboard shim → **exit 2, blocked**

The second line is what distinguishes a shim that resolves from one that merely
fails to complain: exit 0 alone is also what a hook that does nothing returns.

---

## Group 5 — the two repos already carrying shims

Both were compared against a clean 1.1.0 render **before** replacement and were
byte-identical to it, so neither PR carried away local behaviour. That was
checked, not assumed — it is the only thing that makes a blind re-render safe.

| Task | Repo | PR | Instrument, that repo alone |
|---|---|---|---|
| 5.1 | `agenticapps-dashboard` | [#99](https://github.com/agenticapps-eu/agenticapps-dashboard/pull/99) | 6 findings → **0**; 3/3 markers current, 3/3 byte-identical, 3/3 matchers covering |
| 5.2 | `cparx` (factiv, cross-family, authorized for this change) | [#124](https://github.com/agenticapps-eu/cparx/pull/124) | 6 findings → **0**; same three axes |

Neither repo's `settings.json` was touched: all six registrations already
covered their declared matcher sets. The matcher edit belongs to group 6's four
repos, where `database-sentinel` is registered one tool short.

Live, per repo — the instrument proves propagation, not that anything works:

- benign `Edit` through each of the three shims → exit 0
- `DROP TABLE` through `database-sentinel` → exit 2, blocked

Both PRs are open, not merged. The fleet total therefore has **not** moved yet,
and group 7's re-run is the measurement that counts.

---

## The instrument measured this machine and called it the fleet

Group 6's premise — *"the five repos carrying inlined copies"* — was **false of
every one of them**, and the baseline above is what said otherwise.

`project-hook-conformance.sh --fleet` scans **working trees**. Six of the seven
checkouts on this machine were behind their remotes, some by eleven commits, and
in five of them the commits not pulled were exactly the ones that had already
converted the hooks to shims. Measured against `origin/main` instead:

| Repo | local checkout behind | upstream `database-sentinel` | upstream matcher |
|---|---:|---|---|
| `agenticapps-dashboard` | 0 | 1.1.0 shim | `Bash\|Edit\|Write\|MultiEdit` |
| `agenticapps-roadmap` | 11 | 1.1.0 shim | correct |
| `agents-task-viewer` | 4 | 1.1.0 shim | correct |
| `callbot` | 3 | 1.1.0 shim | correct |
| `cparx` | 2 | 1.1.0 shim | correct |
| `fbc-platform` | 3 | 1.1.0 shim | correct |
| `fx-signal-agent` | 3 | 1.1.0 shim | correct |

The entire fleet was already shimmed at 1.1.0 with correct matcher coverage. The
inlined copies, the narrow `Bash|Edit|Write` registrations, the `migrations/`
block with its `/gsd-discuss-phase` remedy — all of that was real, and all of it
was **on this laptop**, in checkouts nobody had pulled since 2026-08-02.

So of the baseline's 46 findings, the 15 unrecognised markers and 4 narrow
matchers described stale local files. What the fleet actually needed was what
group 5 needed: a 1.1.0 → 1.2.0 re-version, everywhere.

### It cost a wrong PR before it was noticed

`agenticapps-roadmap` PR #13 was opened claiming to convert inlined copies,
unblock `migrations/*` and widen a matcher, with live before/after exit codes
to prove it. The exit codes were real; they were produced by running the stale
local files. The PR was corrected in place: merged with current `main`,
conflicts resolved to it, and the body rewritten to name the mistake. Its net
diff is now the same 149/25 re-version as the other six.

### Why this belongs in this change rather than in a footnote

It is the change's own subject, arriving from the direction the change was not
looking. `--fleet reports 0` was already recorded as a false-clearance shape;
`--fleet reports 46` turns out to be a false-*conviction* of the same kind. The
instrument answered confidently, and the question it answered — *what is on this
disk* — was not the question asked — *what is in the fleet*. Nothing in its
output distinguishes the two. It does not read a git ref, does not fetch, and
does not say how old the tree it just scored is.

**Not fixed here.** The fix belongs to the instrument and wants its own change:
report each project's checkout state (`ahead/behind`, or at minimum the HEAD date
and whether a fetch is stale) beside its findings, so a reader can tell a fleet
report from a laptop report. Recorded so that group 7's re-run is not read as
covering it.

---

## Group 6 — the five repos that were said to carry inlined copies

All five needed the same 1.1.0 → 1.2.0 re-version as group 5. No repo needed a
matcher edit: upstream registrations already covered the declared sets, so task
6's central instruction — widen one entry and diff to prove only that entry
moved — had already been carried out before this change began.

| Task | Repo | PR | Result |
|---|---|---|---|
| 6.1 | `agenticapps-roadmap` | [#13](https://github.com/agenticapps-eu/agenticapps-roadmap/pull/13) | corrected in place after being cut from a stale checkout |
| 6.2 | `callbot` | [#100](https://github.com/agenticapps-eu/callbot/pull/100) | clean |
| 6.3 | `fbc-platform` | [#105](https://github.com/agenticapps-eu/fbc-platform/pull/105) | prepared in a temporary worktree — that checkout sits on an in-progress design-system branch with uncommitted work |
| 6.4 | `fx-signal-agent` | [#120](https://github.com/agenticapps-eu/fx-signal-agent/pull/120) | clean |
| 6.5 | `agents-task-viewer` | [#18](https://github.com/agenticapps-eu/agents-task-viewer/pull/18) | two shims; plus 6.5a and 6.6 below |

Each verified the same way: conformance against that repo alone (all axes
clean), benign `Edit` through every bound shim → exit 0, `DROP TABLE` through
`database-sentinel` → exit 2.

### 6.5a — the premise was wrong, and the task's other branch was taken

6.5a proposed disposing of `agents-task-viewer`'s `bin/openspec-change-gate.sh`
as *"a 17k copy that nothing calls and no instrument reports"*. The second half
is true. The first is not: the hook shim does not call it, but CI does —
`.github/workflows/openspec-gate.yml` runs `change-gate-conformance.sh` against
it, `bin/openspec-gate-ci.sh` fails without it, and `tools/core-vendor.manifest`
pins its sha256 under core ADR-0023. CI has no `~/.agenticapps` to resolve from,
so the gate has to be in the repository. Deleting it breaks CI.

Kept, with a note beside it rather than inside it — the file is pinned by
sha256, so editing it would break the pin.

The note omits the override variable's **name** on purpose, and that is worth
recording as a small tension in the instrument: the override-vector scan reports
any repository file that merely *names* the variable, deliberately, because
"over-reporting costs a glance". But a docs file naming it books that glance on
every fleet scan from then on. Verified both ways — with the name, one finding
against that repo; without it, zero. Documenting the contract inside a fleet repo
currently costs a permanent finding.

### 6.6 — the rationale was already lost, and is now recovered

The 26-line opt-out banner lived at the top of `agents-task-viewer`'s
`.claude/hooks/normalize-claude-md.sh`. That file was deleted upstream in
`ac13485` when the hooks became shims — so the reason survived only in
`git show ac13485^`. Task 6.6 exists to relocate the rationale **before** 6.7
deletes the file; upstream, 6.7 happened first. The exact failure the ordering
was written to prevent had already occurred.

Recovered as ADR 0009 in that repo, linked from `CLAUDE.md`'s hand-written
preamble — outside every GSD block, so the hook the ADR declines to run could not
rewrite the link even if it were re-registered.

### 6.6a and 6.7 — already satisfied

6.6a: the opt-out is already declared in
`reference-implementations/project-hooks/OPT-OUTS`, and the instrument reports it
as an opt-out with its reason on both the marker and matcher axes. 6.7: the file
is already gone upstream.
