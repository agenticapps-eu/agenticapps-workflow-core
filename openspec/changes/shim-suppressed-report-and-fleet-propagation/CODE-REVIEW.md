# Stage-2 code review — core PR 1 (#73)

Task 8.4, first of the two it asks for. Read in a cleared session against the
branch `fix/shim-suppressed-report-and-fleet-propagation`, with no memory of
having written it. Task 8.4 is **not** discharged by this file: it asks for a
review of core PR 2 as well, and PR 2 carries the claim most worth an
independent reader.

**Verdict: REQUEST-CHANGES.** Two of the findings are in-diff and small. Both
concern *evidence* rather than behaviour: the change is right about what it
did, and two of its three headline claims are asserted by nothing.

## Verified first, so the findings are not the whole picture

Re-run in this session, not taken from the handoff:

| claim | result |
|---|---|
| `tools/project-hook-shim.test.sh` | 56 passed, 0 failed |
| `tools/project-hook-conformance.test.sh` | 54 passed, 0 failed |
| `tools/test-claude-hook-wrapper.sh` | 12 passed, 0 failed |
| PR #73 | OPEN, MERGEABLE, gate check SUCCESS, CodeRabbit SUCCESS |

**Core's binder fix is genuinely covered.** Mutating
`.claude/hooks/openspec-change-gate.sh` back to `exit 0` fails the shim suite
(55/56) *and* the wrapper suite (`genuinely absent gate fails open,
non-blocking (1)`). Two independent suites catch it. This is the part of the
change that carries its evidence, and it is the part that mattered most.

Every finding below was reproduced before being written down.

---

## Finding 1 — the matcher axis reports a hook registered *nowhere* as clean

**In-diff, and it is the change's own defect shape.**

`report_matchers()` iterates `for event, matcher in seen.get(hook, [])`. When a
declared hook appears in no `settings.json` entry, `seen` has no key for it, the
loop body never runs, and the axis prints **nothing** — no line, no finding.

Reproduced. A project with all three shims present, current at 1.2.0 and
byte-identical to the authority, whose `settings.json` is `{"hooks":{}}`:

```
MARKER    ghost-repo  database-sentinel    current (1.2.0)
MARKER    ghost-repo  normalize-claude-md  current (1.2.0)
MARKER    ghost-repo  openspec-change-gate current (1.2.0)
IDENTITY  ghost-repo  database-sentinel    matches the template
...
OK — no known vector found, and every marker read is current.
EXIT=0
```

Not one `MATCHER` line, zero findings, exit 0. Positive control: registering
`database-sentinel` on `Bash|Edit` *does* produce
`does not cover MultiEdit|Write` — so the axis detects a **narrowed**
registration and is blind to a **missing** one.

That inverts the priority `MATCHERS` states in its own header:

> so a MultiEdit to .env did not invoke the hook at all — **protection absent
> rather than degraded**, and invisible to every check.

Absent-reads-as-clean is the `[ -f "$shim" ] || continue` shape this change
exists to remove, reproduced in the axis added to remove it. `report_markers`
was taught that absence is a state; `report_matchers` was not.

**Why it matters beyond the instrument.** Tasks 6.x convert 14 inlined copies
across five repos and task 7.3 asserts matchers per repo. A conversion that
drops a registration — the plausible mistake when rewriting `settings.json` —
scores clean on every axis. PR 2's central claim is that the fleet was actually
reached; this axis cannot support it for the hook that is registered nowhere.

**Fix.** After the `seen.get(hook, [])` loop, emit a FINDING when
`hook not in seen`. It must consult `opt_out_reason` the way `report_markers`
does — for a declared opt-out, no registration is the correct state, and
reporting it as a finding would make the opt-out declaration meaningless.

## Finding 2 — the gate shim's 1.2.0 behaviour is asserted by nothing

**In-diff.** `openspec-change-gate.shim.sh` receives the same
`report_rate_limited` rewrite as the template: suppressed line, report-then-mark
ordering, 1.2.0 wording. None of it is exercised.

Mutation test — the suppressed branch reverted to the 1.1.0 defect, the silent
`return 0`, in the gate shim only:

```
  passed: 56   failed: 0      # project-hook-shim.test.sh
  passed: 54   failed: 0      # project-hook-conformance.test.sh
```

The defect this entire change exists to fix, reinstated in the file the change
itself calls **the worst case in the fleet** — "the notice it swallowed is the
one saying §18 enforcement is not running and CI is the only floor left" — is
green.

Cause: `tools/project-hook-shim.test.sh:345` creates
`$BIN/openspec-change-gate.sh` and never removes it, so `$GATE_SHIM` always
resolves candidate 2 and never reaches its unresolvable path. Its coverage is
the three override-failure cases, the two resolvable candidates, and the empty
override — the rate limiter is downstream of all of them.

This repeats, verbatim, the failure mode the comment 5 lines above that setup
names:

> Finding 6 landed in both files for exactly that reason: the template's
> assertions could not reach the sibling. An assertion made of one of two
> hand-synchronised files is an assertion about one of them.

The suppressed-line block, the four-field content assertion, the
differs-from-the-full-report assertion and the unwritable-marker assertion are
all made of `SUP_SHIM` — the template — only.

**Fix.** `rm -f "$BIN/openspec-change-gate.sh"` before a gate-shim block, and
run the suppressed-repeat, four-field and marker-ordering assertions against
`$GATE_SHIM` too. Its suppressed line has different wording ("the §18 gate did
NOT run and the edit was allowed"), so the field regexes need to match both or
be parameterised.

## Finding 3 — a new instrument axis shipped with no requirement

The delta adds five requirements:

- A non-zero exit always carries a message
- A rate limit governs verbosity, not the operator's notice
- An absent shim is a finding, not a silence
- The authority's own binder is scored, never assumed
- (MODIFIED) The shim contract itself has a propagation path

None of them is about registration coverage. `grep -i
'settings.json\|register\|coverage'` over the delta returns nothing. Yet the
change ships `report_matchers()`, a `MATCHERS` declaration with 35 lines of
rationale, a new `REGISTRATION` finding class, and counts the axis in the
30 → 46 result. Task 2b.3 adds the check; no requirement says what it must
detect.

This is why Finding 1 has nothing to violate — and the change makes the
argument against itself. Its own MODIFIED requirement holds that a marker with
no format, authority, comparison procedure or check "makes nothing detectable",
and specifies all four. The matcher axis has none of the four.

Either add an ADDED requirement covering registration coverage (including the
absent case, which is what Finding 1 turns on), or drop the axis from this
change and take it as its own. Given `--fleet` findings 30 → 46 is quoted as a
result of *this* change, the first.

## Finding 4 — Stage-2 finding 6 survives on candidate 2 (pre-existing, low)

`shim-template.sh:115-118` explains that `-x` alone is true of any searchable
directory, and hardens the override path to `[ -f ] && [ -x ]`. Eleven lines
below, candidate 2 is still bare `[ -x "$SHARED" ]`. Reproduced with a
directory at the shared-install path:

```
EXIT=126
stderr: ...: is a directory
        ...: cannot execute: Undefined error: 0
```

Not the contract's exit 1; the first line the operator sees is bash's, and it
names neither the hook nor the fact that the call was allowed. The same holds
in `openspec-change-gate.shim.sh:131`.

Pre-existing, and not introduced here — but the change adds the invariant "no
pre-exec path exits non-zero in silence" and enumerates the override, the
unresolvable and the suppressed paths. This one is not enumerated, and it is
the one already known to have been got wrong once.

## Note, not a finding — the 1.6 anti-pattern test proves less than it says

```bash
run_shim "$SUP_SHIM" "$PAYLOAD"; rc=$?
if [ "$rc" -ne 0 ] || [ ! -s "$TMP/err" ]; then
  ok "no shim path writes to stderr and then exits 0"
```

One probe, of one path, in one file — the same scenario asserted two blocks
above with the condition inverted. It cannot detect the anti-pattern on any
other path, and it does not probe core's binder, where the defect actually
lived. It happens not to matter: the directory-at-the-gate-path assertion and
the wrapper suite both cover core's binder, as the mutation test above
confirms. The name promises a general invariant the body does not check.
