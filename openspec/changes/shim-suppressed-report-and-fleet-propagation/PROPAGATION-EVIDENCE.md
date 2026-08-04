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
