# ADR-0023 — Hosts pin core artifacts instead of vendoring them

**Status**: accepted
**Date**: 2026-07-28
**Supersedes in part**: ADR-0022 (which established that core publishes the gate;
this changes how hosts *obtain* it, not who owns it)

## Context

ADR-0022 made core the publisher of the §18 change gate so four host copies
could stop diverging. It worked — issue #32's divergence is closed, and the
conformance harness scores any copy against the truth table.

The mechanism was byte-vendoring: each host keeps
`bin/openspec-change-gate.sh`, `bin/reviewer-cli.sh` and both
`tools/*-conformance.sh` as copies of core's canonical files, and a drift check
compares them against a sibling core checkout.

On 2026-07-28 the gate shipped four versions in one day —
`1.2.2 → 1.3.0 → 1.3.1 → 1.4.0`. Each required a re-vendor PR in four repos,
touching two files each: **twelve mechanical PRs before the fourth release**.
Every one was a diff nobody reads, and each was an opportunity to update the
artifact but forget its harness — which happened, and CI caught it as a
mysterious two-row failure rather than as "you forgot a file".

The re-vendoring also has a hidden ordering constraint. Host drift checks
compare against `core@main`, so a host PR is red until core's PR merges. That
is correct behaviour, but it means the fleet is never atomically consistent and
every release is a sequenced convoy.

**What the copies are actually for.** The project-level hook resolves
`~/.agenticapps/bin/` first and only falls back to a repo-local path:

```sh
GATE="${OPENSPEC_GATE:-$HOME/.agenticapps/bin/openspec-change-gate.sh}"
[ -x "$GATE" ] || GATE="$(git rev-parse --show-toplevel)/bin/openspec-change-gate.sh"
```

For a *project* (callbot, cparx, roadmap) that fallback names a path which does
not exist. The runtime therefore never reads a host's vendored copy. Those
copies exist for exactly one caller: the host's own `install.sh`, which needs
bytes to publish into the shared path.

Four repos carry four artifacts each so that four installers have something to
`install -m 0755`.

## Decision

**Hosts record a pin; core supplies the bytes.**

A host keeps `tools/core-vendor.manifest` — a core commit plus a sha256 per
file — and `install.sh` resolves each artifact through
`resolve-core-artifact.sh` before handing it to `install-shared-artifact.sh`.
The vendored artifact and harness copies are deleted.

```
manifest (pin)  ──▶  resolve-core-artifact.sh  ──▶  install-shared-artifact.sh
core_commit=…        local checkout @ commit         monotonic, lock-guarded
sha256=…             else fetch @ commit             publish to ~/.agenticapps/bin
                     VERIFY sha256 or fail
```

Resolution order is deliberate: an explicit `CORE_CHECKOUT`, then a sibling
checkout, then the network. Development machines with core checked out beside
the hosts — which is how this fleet is laid out — never touch the network.

`codex-workflow` already carried this manifest format alongside its byte
copies; this generalises the half it had and drops the half it did not need.

## Consequences

**A core release stops being a fleet event.** One line per host (plus the
hashes), botable, and the harness copies disappear entirely — core's CI scores
the canonical, and a host verifies its pin rather than re-testing the artifact.

| | vendored | pinned |
|---|---|---|
| host files per artifact | 2 (artifact + harness) | 0 |
| host files total | 4 | 1 manifest |
| per-release PR content | full diffs ×4 | one sha + hashes ×4 |
| drift check | compare files vs sibling checkout | verify hash matches pin |

**The trust model is unchanged in substance.** Vendoring meant "someone read
these bytes once and committed them". A pin means "someone read these bytes
once and recorded their hash". Both anchor on a human decision; the pin just
stops storing a redundant copy of what it already identifies. Bytes that do not
hash to the pin are never emitted — `resolve` fails closed with exit `4`.

**New: a network dependency on a cold machine.** A host with no local core
checkout and no network cannot install. Mitigated by checkout-first resolution
and `CORE_OFFLINE=1` for environments that must never reach out. This is a real
cost and the honest trade for deleting twelve PRs per four releases.

**Lost: the repo-local fallback for host repos themselves.** A host that
deletes `bin/openspec-change-gate.sh` has no gate until `install.sh` has run
once. Projects are unaffected (their fallback never resolved anyway). Bootstrap
is now strictly "run the installer", which it effectively already was.

**A pin can go stale silently.** A host pinned to an old commit keeps working
and keeps publishing an old gate — the version arbiter stops it clobbering a
newer shared copy, but the host itself never notices it is behind. Detecting
that is a follow-up: a CI row comparing the pin against core's HEAD, advisory
not blocking.

## Alternatives considered

**Track `main` instead of pinning a commit.** Zero PRs per release. Rejected:
an installer that fetches whatever `main` says today is not reproducible, and a
bad core commit would propagate to every machine on its next install with no
human in the loop. The pin is the human in the loop.

**Publish core as an npm package.** Familiar and versioned, but adds a registry
and a publish step to a fleet of shell scripts, and the artifacts are already
addressable by commit. Reconsider if the artifact set grows beyond shell.

**Automate the re-vendor with a bot.** Keeps the copies and removes the typing.
Rejected as treating the symptom: the copies would still drift, the harnesses
would still need syncing, and the ordering convoy would remain.

**Keep vendoring.** Defensible — it is offline, auditable and simple. The
measured cost (twelve PRs in one day, one forgotten-harness incident) is what
tipped it.
