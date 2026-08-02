# ADR-0029: Projects bind fleet-shared hooks through shims

**Status**: Accepted  **Date**: 2026-08-02  **Change**: `shim-project-hooks`

## Context

Seven repos each carried a full copy of eight `.claude/hooks/` scripts — 4,396
lines. Four of the eight had drifted into two or three distinct versions. The
one hook that was never copied — `openspec-change-gate.sh`, a ~13-line shim
that `exec`s a shared implementation — had **zero** drift across all seven.

The copy pattern demonstrably produces drift; the shim pattern demonstrably
prevents it. That is not an argument from taste, it is the measurement.

Measuring the eight also found that **five should not exist**. Two were
permanently inert, one blocked unconditionally on a sentinel no surviving
command can write, and two wrote telemetry into `.planning/`, which fleet policy
designates frozen archive.

This is step 3a of `docs/PLAN-lightweight-fleet.md`.

## Decision

**A hook implementation is authoritative in exactly one place.** Projects bind
it through a shim whose entire job is to resolve and hand over.

Resolution is **two candidates** — an explicit override, then
`~/.agenticapps/bin/` — with **no `<repo>/bin/` third candidate**. A shim is
**behaviour-free**: it resolves, `exec`s (forwarding stdin *and* argv untouched),
reports, and touches one rate-limit marker. It inspects no tool payload.

An unresolvable shim **fails open and reports**. The guarantee moves to a
multi-artifact installer that verifies before publishing, and to a per-machine
provisioning check.

Two profiles: **published-resolution** for the seven projects, and
**self-hosting** for core, which resolves its own working-tree copy per
ADR-0028. Each hook has exactly one self-hosting binder.

## Alternatives rejected

**Symlinks.** A symlink into `~/.agenticapps/bin/` removes the copy without any
shim logic — no resolution order, no version marker, nothing to drift. Rejected
because it silently becomes a dangling link on any machine that has not run the
installer, and a dangling `command` in `settings.json` produces a host-level
error on every matching tool call with no message anyone can act on. It also
cannot express an override, which the staged rollout needed. Git tracks symlinks
but not their validity, so the repo would look correct while the machine did not.

**A package (npm/brew) installing the hooks.** Real versioning, real
distribution. Rejected as disproportionate: this is five shell scripts across
two families on one developer's machines, and it would add a release step to
every hook edit — reintroducing the latency that made copying attractive.

**Leaving the copies and adding a drift checker.** Cheapest to build. Rejected
because it detects the disease rather than curing it: someone still has to
reconcile seven copies by hand each time, which is what produced three versions
of `normalize-claude-md` in the first place.

## Why the fail-closed posture was adopted and then withdrawn

The first design had the shim **block** when it could not resolve, reasoning
that nothing else backstops a missing security control.

That was wrong, and measuring the matcher is what showed it.
`database-sentinel` is registered on `Bash|Edit|Write|MultiEdit`. A shim that
blocks on unresolvable therefore blocks **every Bash command and every file
edit in the repository** — not `.env` and dangerous SQL, which is what the
argument assumed. Narrowing it would require inspecting the tool payload, which
is exactly the behaviour the shim contract forbids and exactly the duplicated
logic the change exists to remove.

The lesson generalises: **a hook's blast radius is its matcher, not its
purpose.** Reasoning about a fail-closed posture from what a hook is *for*
rather than from what it is *registered on* gets the scope wrong by an order of
magnitude.

## Why a hook's filename is not evidence of a §02 binding — in either direction

§02 makes a gate's binding host-specific data living in the host instruction
file. So a hook named after nothing in §02 could still be some gate's binding,
and a hook named after a gate need not be. `design-shotgun-gate.sh` shares a
name with a §02 gate whose actual binding is the gstack `/design-shotgun`
*skill*.

Deletions are therefore argued on three separate tests — **binding**,
**production of evidence**, and **enforcement by any means** — run against §02,
§17, §18 and every capability spec, not §02 alone.

The third clause is broad deliberately, and it bites: **a sentinel is a proxy,
so gating on one *is* enforcement.** That reversed the argument for
`design-shotgun-gate`, which had been cleared on "the sentinel is not §02's
required evidence" — reasoning that, once clause 3 was broadened, convicts it
instead. What actually clears it is **unreachability**: no surviving tool can
write the sentinel, so the check can never pass. It does not enforce a gate; it
blocks unconditionally.

## Why superset reconciliation must also ask whether each clause can still fire

Reconciling three drifted copies to their superset is the obvious move, and it
is not sufficient. `callbot`'s copy was the behavioural superset and was adopted
as canonical — and it carried a `migrations/` clause gating on
`.planning/current-phase/migrations-approved`, printing a remedy naming
`/gsd-discuss-phase`, a command removed on 2026-07-28.

Measured: that clause was in **all seven** copies and live in **six** of them.
Adopting the superset unexamined would have propagated a live blocking defect
into the canonical implementation — inside the hook the first draft classified
as healthy, while the change was busy deleting a *different* hook for the same
sin.

**So each inherited clause is checked for whether its precondition is still
reachable, not merely for whether it is present.** The union of three copies is
a starting point, not an answer.

## Consequences

- Executable hook logic per project falls from 351 lines to 102 (−71%), and the
  102 are byte-identical across all seven. Total lines fall 4,396 → 1,944, with
  +575 added once to core: a fleet net of −1,877. The proposal estimated −3,090,
  having assumed a ~13-line shim; the shims carry their contract in comments.
- Protection now travels with the **machine** rather than the repository.
  **Every existing developer machine enters the unprovisioned state the moment
  it pulls the shim**, via an ordinary `git pull`, with nothing prompting an
  install. That is a real regression, answered by a per-machine check and by
  telling people to run the installer — not by an ordering that constrains only
  the machine doing the rollout.
- The shared directory becomes an arbitrary-code-execution concentration point:
  anyone who can write `~/.agenticapps/bin/` changes what seven projects
  enforce. Hence ownership and permission rules on the directory, its artifacts
  and its manifest.
- `$<HOOK>_OVERRIDE` is a **kill switch**, and a repository can set it via
  `settings.json`, an `.envrc`, a setup script, a task runner or README
  instructions — all indistinguishable at runtime from the operator's own
  export. A behaviour-free shim cannot defend against this, so the answer is a
  conformance scan that reports the repository **by name**, and a green result
  that reads "no known vector found" rather than "no override is set".
- **The fail-open report's channel is not established.** A live probe confirmed
  the shims run and allow, but the exit-1 report reached neither the agent nor
  the stream-json surface, while an exit-2 block did. Until someone observes the
  notice in an interactive transcript, no report may describe these hooks as
  warning anyone. If it turns out to be silent, the fail-open trade should be
  reopened.
