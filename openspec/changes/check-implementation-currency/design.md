## Context

`tools/provisioning-check.sh` computes two axes and prints "This machine is
provisioned. The shims will resolve." on `complete` + `attested`. Observed
2026-08-03, and this change exists because of the observation rather than in
anticipation of it:

| artifact | published | core ships | measured behaviour of the published copy |
|---|---|---|---|
| `normalize-claude-md` | 1.0.0 | 1.0.1 | `CLAUDE.md` 0644 in → **0600** out |
| `database-sentinel` | 1.0.0 | 1.1.0 | `DELETE FROM public.users` **not blocked** |

**The first draft of this design was wrong about the cause**, and the plan review
is what caught it. It proposed building a comparison that already exists.
`--source-check DIR` was built by task 3.2a-ii, does byte-comparison against
core's maintained implementations, and carries a comment stating the premise
exactly: *"A machine can be perfectly attested against a manifest that published
last month's implementation."*

Reproduced against a deliberately stale authority tree:

```
SOURCE    database-sentinel  DIFFERS from the maintained implementation in <tree>
SOURCE    normalize-claude-md  DIFFERS from the maintained implementation in <tree>
COMPLETENESS  complete   (2 of 2 expected artifact(s) present)
INTEGRITY     attested
This machine is provisioned. The shims will resolve.
```

The check found it and the summary said "provisioned" anyway. That is the defect,
and it is much narrower than "no currency check exists".

## Goals / Non-Goals

**Goals**

- Give the existing comparison a verdict the summary is obliged to respect.
- Default it on, since the tool lives inside the authority it needs.
- Say which question was *not* asked when it cannot run.
- Make the message actionable: direction, versions, and a remedy per condition.

**Non-Goals**

- **A new comparison.** The comparison exists. This is a reporting change.
- **Auto-updating.** The tools report and the installer installs.
- **Blocking.** Default exit stays 0; currency counts toward `--strict`.
- **Touching the fleet.** Core's own tooling only.

## Decisions

### Decision 1 — a third axis, not a fourth report block

`--source-check` output is a `SOURCE` block that increments `findings` and
changes no verdict, which is why the summary could contradict it. Currency
becomes an axis so the summary line is computed from it and cannot disagree with
it.

Independence is the same argument that split completeness from integrity: a
reviewer showed overlapping states cannot classify a machine. Completeness asks
how much is installed, integrity whether it still matches what was installed,
currency whether that is still what the authority holds. Three questions.

`stale` and `drifted` stay distinct. `drifted` means a published file was edited
or replaced — investigate. `stale` means the machine did what it was told and the
world moved on — one command. Merging them trains an operator to answer real
tampering by re-running the installer.

### Decision 2 — default on, resolved from the tool's own location

The tool is `tools/provisioning-check.sh` inside core; the authority is
`reference-implementations/project-hooks/` two levels up. Same fixed-point
argument the gate hook makes about its own path, and for the same reason: an
environment variable or a working directory can be stale or wrong, and the file's
own location cannot.

`--source-check DIR` is retained — it is the existing flag and the explicit
override. `--no-source-check` opts out. **No new `--authority` flag**: the first
draft proposed one, and the plan review pointed out it would overlap
`--source-check` with no compatibility or conflict semantics defined.

### Decision 3 — currency judges the DECLARED set only

`~/.agenticapps/bin` holds `openspec-change-gate`, `reviewer-cli` and
`run-plan-review` beside the project hooks. They are published by
`install-shared-artifact.sh`, are outside this manifest's scope, and the existing
check already says so — "not covered — published by another installer".

Currency judges the artifacts declared in `ARTIFACTS`, and nothing else. This
matters because of a mistake made in this very change: the review's first round
asked for "the authority holds no such file" to be reported `stale`, that was
accepted, and running it showed it would flag those three out-of-scope artifacts,
each of which correctly reports "no maintained file — cannot compare". Scoped to
the declared set, "no authority file" is a genuine finding again, because every
declared artifact must exist in the authority.

### Decision 4 — bytes decide, markers speak

Verdict is byte-identity. `# <hook>-version:` supplies the message, because a
file whose bytes differ while its marker matches is exactly what a version-only
comparison cannot see — the case already caught once for shims, where a marker
attested "a string about the file rather than the file".

Ordering is **component-wise numeric**, reusing `semver_cmp` from
`project-hook-conformance.sh`. A lexical compare places `1.10.0` below `1.9.0`,
inverting the reported direction and pointing the operator at the wrong remedy.

Where either side has no parseable marker the verdict still stands on bytes and
the message says the version could not be read, rather than inventing one.

### Decision 5 — remedies per condition, because one remedy is wrong

The first draft said every stale line names `install-project-hooks.sh`. The review
showed that is wrong in three of five cases:

| condition | remedy |
|---|---|
| published **older** than authority | re-run `install-project-hooks.sh` |
| published **newer** than authority | **not** the installer — it refuses downgrades. Update the checkout, or investigate a build published from a tree nobody has |
| versions equal, bytes differ | investigate: a build error or a hand-edit, not a lag |
| authority has no file for a **declared** artifact | check out the authority at a commit that has it, or reconcile `ARTIFACTS` |
| `drifted` **and** `stale` together | investigate first; re-installing overwrites the evidence |

A check that names a remedy which cannot work is worse than one that names none.

### Decision 6 — the axis measures a checkout, and says so

Currency is evaluated against the authority path's content on disk when the check
runs. Never core's `main`, never a remote: the tool reads files and cannot know
what a branch elsewhere contains.

**The honest limit, raised by the review: an equally stale checkout and install
agree, and report `current`.** That recreates the false green one level up. Two
responses, and the second is deliberately not taken:

- **Taken** — the axis claims only "matches this authority checkout", and the
  summary says so. It never claims "matches what core ships".
- **Not taken** — verifying the checkout's own freshness against a remote. That
  needs network from a local reporting tool, fails differently when offline, and
  would make an offline machine's verdict depend on connectivity. Recorded as a
  known limit instead, with `git show <ref>:<path>` named as the way to ask the
  branch question — which is what the fleet's contract propagation actually used.

This limit was observed for real hours before this change: `--fleet` reported a
repository stale because a concurrent session had moved its checkout, while the
shims sat correct on the pushed branch.

### Decision 7 — `unknown` is defined by its sub-cases

The review found `unknown` covering only "path not reachable". The middle cases
were undefined and would each have produced a misleading `stale`:

| condition | verdict |
|---|---|
| authority path absent or not a directory | `unknown`, naming the path |
| path exists but holds no declared artifact at all | `unknown` — it is not an authority checkout, and reporting every artifact stale would be confidently wrong |
| some declared artifacts present, some absent | `stale` for the absent ones; the path is an authority |
| a file exists but cannot be read | `unknown` for that artifact, naming the reason; a failed read is not a difference |

Aggregation: any `stale` makes the machine `stale`; otherwise any `unknown` makes
it `unknown`; otherwise `current`. `stale` outranks `unknown` because a known
finding outranks an unasked question.

`unknown` never reads as `current`, and the report names the path it looked for.

### Decision 8 — path disclosure, recorded rather than silently accepted

The review noted an absolute authority path in output can disclose a username or
workspace layout in CI logs. The path is printed anyway: it is the actionable
part of an `unknown` report, this is a local developer tool that is not published
to the shared bin, and `$HOME` appears throughout the existing output already.
Recorded as a decision so it is a choice rather than an oversight.

## Risks / Trade-offs

- **The severity claim, corrected.** The first draft said "nothing here is a
  security fix". A reviewer objected that the observed failure was
  `database-sentinel` not blocking a destructive query. Both overstate. The
  capability's own coverage boundary calls that hook "best-effort defence in
  depth, not a security boundary", so its miss is not a security breach — but a
  stale install silently disables a control the fleet believes is running, and
  calling that merely cosmetic is the same overclaim this change exists to fix.
- **`--strict` gets stricter**, and this is a real behaviour change rather than a
  pure reporting one. A CI job on a machine whose checkout lags would newly fail.
  Core's CI has core, so the case is narrow.
- **The output format changes** on a default run. The first draft claimed "no
  interface changes"; that was false and the review caught it.
- **A stale machine is still running the hooks.** Nothing here changes what
  executes; it changes what the machine is willing to claim about itself.

## Migration Plan

`--source-check DIR` keeps working unchanged. A default run gains a `CURRENCY`
line and may gain findings it did not previously report — which is the point.
`--no-source-check` restores the old default for anyone who needs it.

## Open Questions

None outstanding. The first draft's open question — automatic authority
resolution versus an explicit flag — is settled by Decision 2: automatic, with the
existing `--source-check` as the override, and no new overlapping flag.
