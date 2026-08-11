# The floor can be inspected

## Why

`one-enforcement-floor` shipped the machine-level enforcement floor and archived
on 2026-08-11 without the one thing that makes it legible: a way to ask what it
is doing.

The floor is bound once per machine through `core.hooksPath` and governs only
repositories carrying `agenticapps.workflow.enrolled`. Both halves are invisible
from inside a repository. Measured 2026-08-11: 39 of 41 repositories under
`~/Sourcecode` resolve to the published dispatcher and nothing in any of them
says so — no file, no marker, no output. A repository that is *not* enrolled
looks exactly the same, and is ungated.

That is the shape of the defect this whole capability exists to remove. The
2026-08-08 measurement that started it found five repositories carrying live
OpenSpec changes and not one enrolled, and the reason nobody noticed is that
nothing reported it. Shipping a floor whose coverage cannot be asked about
recreates the condition at one remove.

`--check` was specified as part of `one-enforcement-floor` and never built. It
was excised before archiving rather than carried, because archiving it would
have made core non-conformant to its own spec on the day the spec landed:
`bind-global-floor.sh --check` parses `--check` as a repository argument and
refuses. This change is that excised requirement, plus the three scenarios whose
only actor was `--check`, given a plan of their own.

## What changes

A `--check` mode on the floor binder that reports, without changing anything:
whether `core.hooksPath` is set and resolves to the published directory, whether
the published dispatcher is current by content, which enforcement surfaces are
active for the repository it runs in, and which repositories the floor cannot
reach. `--project` is dropped in the same pass — it is named in deferred-scope
notes for a mode that was never built and no longer has a caller.

## Non-goals

It reports; it repairs nothing. A mode that fixes what it finds is a second
decision with its own failure modes, and the value here is that the answer can
be trusted precisely because asking is free.
