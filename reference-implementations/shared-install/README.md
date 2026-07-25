# shared-install — reference implementation

The arbiter every host installer calls to write a versioned artifact into the
shared `~/.agenticapps/bin/` path.

## The contract

> An install into the shared path MUST be **monotonic**: after any set of
> concurrent installs, the path holds the **newest** version any of them
> offered.

Refusing to downgrade is **necessary and not sufficient**. Core previously
specified only the refusal, all four hosts implemented it correctly, and the
shared path was still not monotonic — because the arbitration is a
read-compare-write with nothing held across it:

```
host A (older, 1.2.1)              host B (newer, 1.2.2)
read  have=1.2.0  -> upgrade
                                   read  have=1.2.0  -> upgrade
                                   write 1.2.2
write 1.2.1                                  <-- older lands last
```

Both decisions were correct against the state each process observed. The later
writer wins regardless of version, which is precisely what the version marker
exists to prevent.

**Per-host arbitration does not compose into machine-wide monotonicity.** Closing
it needs mutual exclusion across the whole read-compare-write, and no single host
can provide that for the others — which is why this lives here and is called by
all of them, rather than being reinvented four times with four different bugs.

Reported as
[pi-agentic-apps-workflow#13](https://github.com/agenticapps-eu/pi-agentic-apps-workflow/issues/13).
Same shape as
[core#41](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/41)
one level down: there the *write* was unguarded, here the *decision* is.

## Usage

```sh
install-shared-artifact.sh <src> <dst> <marker-key>
```

```sh
install-shared-artifact.sh \
  bin/openspec-change-gate.sh \
  "$HOME/.agenticapps/bin/openspec-change-gate.sh" \
  gate-version

install-shared-artifact.sh \
  bin/reviewer-cli.sh \
  "$HOME/.agenticapps/bin/reviewer-cli.sh" \
  reviewer-cli-version
```

The marker is read as `# <marker-key>: X.Y.Z` from the first 40 lines of each
file.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | installed — the destination now holds the source's version |
| `3` | skipped — the destination already holds a **strictly newer** version |
| `1` | error — missing source, unmarked source, lock timeout, failed write |

`3` is a success: the postcondition *"the destination is at least as new as the
source"* holds either way. Installers should not treat it as a failure.

## Environment

| Var | Meaning |
|---|---|
| `SHARED_INSTALL_LOCK_TIMEOUT` | seconds to wait for the lock (default `30`) |
| `SHARED_INSTALL_TEST_DELAY` | **test only** — seconds to sleep between compare and write, so conformance can force the interleave deterministically. Default `0`; never set in production. |

## How it works

**Mutual exclusion via `mkdir`.** `mkdir` is atomic on POSIX filesystems —
exactly one caller creates the directory. Chosen over `flock(1)`, which macOS
does not ship. The lock is **per-artifact** (`<dst>.lock`), not per-directory, so
installing the gate does not serialise against installing `reviewer-cli`.

**Stale locks are broken.** The lock records its owner's pid; a lock whose owner
is gone is removed and retaken. Without this, one killed installer wedges every
future install on the machine — a worse failure than the race, because it is
permanent and silent.

**Writes are atomic.** The file is copied to a temp path in the *same directory*
and then `mv`'d into place. `rename(2)` is atomic within a filesystem, so a
concurrent reader — an agent whose `PreToolUse` hook fires mid-install — sees
either the old file or the new one, never a truncated script. The lock gives
monotonicity; the rename gives readers integrity. Both are needed and they solve
different problems.

**An unmarked destination is `0.0.0`.** Deliberate: the pre-marker copies across
the fleet carried no version, and treating them as "unknown, leave alone" would
have frozen every machine holding one. An unmarked **source**, by contrast, is an
authoring error and is refused — publishing an unarbitratable file is how this
class of bug starts.

### Known limitation

`mkdir` atomicity is not guaranteed over NFS. The shared path is a local home
directory, so this holds in practice; a host installing to network storage needs
a different primitive.

## Conformance

```sh
tools/shared-install-conformance.sh reference-implementations/shared-install/install-shared-artifact.sh
```

12 rows across arbitration, monotonicity under concurrency, liveness, and reader
integrity.

The monotonicity rows are the point. An implementation that arbitrates correctly
but holds no lock — which is what all four hosts shipped — **passes every
arbitration row and fails monotonicity**:

```
MUTANT: correct arbitration, no lock
  ── A. Arbitration ──                     (all pass)
  ── B. Monotonicity under concurrency ──
  FAIL  older installer clobbered a newer one — shared path left at 1.0.0, expected 2.0.0
  FAIL  5 concurrent installers converged on 3.0.9, expected 3.1.0
  ── C. Liveness ──
  FAIL  times out with an error on a live lock holder — exit 0
═══ TOTAL: 9 passed, 3 failed
```

That gap between sections A and B *is* the defect, and it is why "we refuse
downgrades" is not evidence of conformance.

## Adopting

1. Vendor `install-shared-artifact.sh` into the host's `bin/`.
2. Replace the installer's inline read-compare-write for **every** shared
   artifact with a call to it. Today that means the change gate and
   `reviewer-cli`; anything future that lands in `~/.agenticapps/bin/` and
   carries a version marker belongs here too.
3. Treat exit `3` as success.
4. Vendor `tools/shared-install-conformance.sh` and run it in CI.
