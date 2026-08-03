## Context

`tools/provisioning-check.sh` computes two axes and reports a machine
`complete` + `attested` when every declared implementation is present and every
present implementation matches its manifest row. Both axes are computed from the
machine alone. Neither asks whether the installed build is the build core
currently ships, so a machine attested against a stale row is described as
"provisioned" and as running "as documented".

Observed 2026-08-03, and this change exists because of the observation rather
than in anticipation of it:

| artifact | published | core | measured behaviour of the published copy |
|---|---|---|---|
| `normalize-claude-md` | 1.0.0 | 1.0.1 | `CLAUDE.md` 0644 in → **0600** out |
| `database-sentinel` | 1.0.0 | 1.1.0 | `DELETE FROM public.users` **not blocked** |

The published copies were written at 18:09; the fixes merged at 21:25 the same
evening. The check reported the machine provisioned for the fifteen hours
between, and printed `attested v1.0.0` while doing so — the number was on screen
and nothing compared it to anything.

## Goals / Non-Goals

**Goals**

- Make staleness observable, by name, with both versions and the direction.
- Keep an uncomputable answer distinguishable from a good one.
- Narrow the spec's "running as documented" claim to what the check can support.

**Non-Goals**

- **Auto-updating.** The check reports; it does not install. This capability's
  tools report and the installer installs, and a check that silently rewrote
  `~/.agenticapps/bin` would be doing the one thing `drifted` is forbidden to do
  ("SHALL NOT resolve it silently").
- **Blocking.** Default exit stays 0. Currency counts toward `--strict` like the
  other axes, for CI.
- **Touching the fleet.** No shim, no project, no published artifact changes.
  This is a defect in core's own reporting.
- **Changing the manifest format.** The manifest records what was published and
  that is the right thing for it to record. Currency is a different question
  asked of a different authority.

## Decisions

### Decision 1 — a third axis, not a third value on an existing one

Currency is independent of both existing axes. A machine can be `partial` +
`attested` + `stale`, or `complete` + `drifted` + `current`. Folding it into
integrity would recreate exactly the defect a reviewer found in the original flat
four-state list: members that overlap cannot classify anything. The capability
already made this argument once when it split completeness from integrity; this
is the same argument, and the same answer.

**Alternative rejected — extend `drifted` to mean "differs from the manifest OR
from core".** It collapses two conditions with different remedies. `drifted`
means someone edited or replaced a published file and the remedy is to
investigate; `stale` means the machine did what it was told and the world moved
on, and the remedy is one command. Reporting both as `drifted` would train
people to answer every occurrence by re-running the installer, which is the wrong
response to real tampering.

### Decision 2 — `unknown` is a value, not an error

Currency needs an authority to compare against: core's tracked
`reference-implementations/project-hooks/`. A machine that has installed the
hooks need not have core checked out at all, and the check must still run there.

So the axis is `current` / `stale` / `unknown`, and `unknown` is reported when
the authority is not reachable. It is **never** silently `current`. This is the
same honesty rule the override scan already applies — it reports "no known vector
found" rather than "no override is set", because a green result is a statement
about what was searched and not about the machine.

`unknown` counts toward `--strict`. In CI the authority is always reachable, so
`unknown` there means the check could not do its job, which CI should hear about.

**Alternative rejected — pin the expected versions into a tracked file in core.**
It would make currency computable without a checkout, and it would be a fourth
place the version is written down, guaranteed to drift from the markers it
describes. The authority is the tracked implementation, exactly as the shim
template is the authority for shims.

### Decision 3 — compare bytes, and report the version

Comparison is byte-identity against the authority's file, with the version
markers used for the *message* rather than the verdict. A file whose bytes differ
while its marker matches is the case a version-only comparison cannot see — and
it is the same case Stage-2 finding 5 caught for shims, where a marker attested
"a string about the file rather than the file".

Ordering, so the report is actionable rather than merely correct:

- bytes equal → `current`
- published marker **lower** than the authority's → `stale`, name both
- published marker **higher** → `stale`, and say so in that direction: the
  machine carries a build core cannot account for, which is what a shim marker
  ahead of the template already reports as `unrecognised`
- markers equal, bytes differ → `stale`, and say the versions agree while the
  bytes do not, because that is a build error or a hand-edit rather than an
  ordinary lag

### Decision 4 — name the remedy in the report

Every stale line ends with the command that clears it. A check that detects a
condition nobody knows how to clear is a check people learn to ignore, and this
capability has already recorded that reasoning once, as the argument for why the
gate's fail-open must not train people into `--no-verify`.

### Decision 5 — the "running as documented" clause changes

The sentence "This is the only value on either axis under which the fleet's
protections may be described as running as documented" attaches that licence to
`attested`. It is demonstrably too strong: this machine held it while running
implementations missing three landed fixes. The licence moves to
`complete` + `attested` + `current`, and `unknown` explicitly does not grant it.

This is why the change modifies an existing requirement rather than only adding
one. Adding the currency rule while leaving that sentence standing would leave
two sentences that are true of different conditions with neither saying which —
the precise failure mode the requirement's own opening paragraph was written to
correct.

## Risks / Trade-offs

- **Most machines will report `unknown`.** Only machines with core checked out
  can compute currency, which is the developer machines — the ones that run the
  hooks. Accepted: `unknown` is honest, and the alternative is a green that means
  nothing.
- **`--strict` gets stricter.** CI on a machine without core would newly fail.
  Mitigated by the fact that core's own CI has core, and no other repository runs
  this tool.
- **A stale machine is still protected, just not as documented.** Nothing here is
  a security fix; the shims resolve and the implementations run. The change makes
  a false statement stop being made.

## Migration Plan

None. No interface, format or published artifact changes. The check gains an
axis and a line of output; a machine that was `complete` + `attested` and current
reports exactly as it did before, with `CURRENCY current` added.

## Open Questions

- Should `provisioning-check.sh` locate core automatically (walking up from its
  own location, which is inside core) or take an explicit `--authority DIR`?
  Automatic covers the common case and is what the gate hook already does with
  its own path as the fixed point; explicit covers a machine checking a foreign
  install. Proposed: automatic by default from the script's own location, with
  `--authority` to override, resolved during implementation rather than now.
