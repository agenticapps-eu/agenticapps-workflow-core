# reviewer-cli — reference implementation

The defensive wrapper the §18 change-gate's review *producer* calls once per
vendor. The gate **consumes** review evidence; this is what **produces** it.

`reviewer-cli.sh` is installed at one shared path,
`~/.agenticapps/bin/reviewer-cli.sh`, written by the claude / codex / opencode /
pi installers alike. Vendor it. Do not maintain a host copy — a private fork of a
file at a shared path is not a fork, it is a race.

**Change behaviour here only alongside a matching harness row.** The gate earned
that rule the hard way and this artifact is one directory over.

## Contract

| | |
|---|---|
| Invocation | `reviewer-cli.sh <vendor> <prompt-file>` |
| Vendors | `claude` · `gemini` · `opencode` · `codex` |
| Prompt delivery | **argument**, never stdin (stdin is pinned) |
| Output | the reviewer's raw verdict text on stdout |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | review completed |
| `3` | usage error, unknown vendor, missing prompt file, CLI absent, or timeout |
| other | the vendor CLI's own exit code, passed through |

A non-zero vendor means **"reviewer unavailable"**, and the producer MUST record
it in `REVIEWS.md` as such. It must never be silently counted as a passing
reviewer — that would let one reachable vendor satisfy a rule whose entire
purpose is two independent ones.

Timeouts surface as `3`, not the raw `124`, so a producer does not need to know
`timeout(1)`'s convention to interpret the result.

## Environment

| Var | Meaning |
|---|---|
| `REVIEWER_TIMEOUT` | hard wall-clock cap in seconds (default `300`) |

## The two properties this wrapper exists for

1. **stdin pinned to `/dev/null`.** `codex exec "<prompt>"` reads stdin and
   **hangs** without it — a 4-minute stall on first attempt in the cParX pilot.
2. **A hard `timeout`**, with a `gtimeout` fallback for macOS/BSD. If neither
   binary is present the wrapper still runs, unbounded, and **warns** — refusing
   outright would brick review on a machine missing coreutils, and silence would
   reproduce the hang it exists to prevent.

Both are enforced inside `run_bounded`, in **one place**, covering both branches.
Repeating `</dev/null` at each call site — as two of the three pre-1.0.0 host
copies did — is one forgotten redirect away from reintroducing the hang, and the
omission is invisible until that specific vendor is next called. The harness
scores stdin pinning **per arm** for exactly this reason.

## Vendor exclusion is the producer's job, not the wrapper's

A host must never review its own change. That exclusion belongs to the producer
skill, which picks the vendor set. **Every** arm still ships here, including the
host's own: this file lives at one global path shared by every host, so the
`codex` arm exists for the sibling hosts that call it.

Dropping an arm because "this host would never use it" is the direct cause of
[#41](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/41).

## `opencode` is a client, not a provider

The producer must record the **resolved model** (e.g. `glm-5.2`), not just the
CLI name. A CLI name alone is not evidence of a distinct vendor — two arms
pointed at the same underlying model would count as two independent reviewers
and §18's threshold would be satisfied by one opinion wearing two names.

## Vendoring into a host

1. Copy `reviewer-cli.sh` to the host's `bin/`. Do not edit it — a private
   change here is a fork at a shared path, which is how #41 happened.
2. **Copy `tools/reviewer-cli-conformance.sh` too**, and run it in CI. Keep the
   two in sync: a stale harness certifies a stale wrapper.
3. **Teach the host's installer to honour `# reviewer-cli-version:`.** Every
   host writes the same shared path, so without arbitration it is
   last-writer-wins. Installers MUST compare the incoming marker against the
   installed one and **refuse to downgrade** (treat an unmarked file as
   `0.0.0`). This is the same rule as the change gate's `# gate-version:` — the
   gate has had it since 1.2.0, this file did not, and the difference is the
   entire content of #41.

   **Refusing to downgrade is necessary and not sufficient.** The compare and the
   write must be serialised, or two installers each deciding correctly against
   the same observed state still let the later writer win regardless of version.
   Do not hand-roll that: call
   [`install-shared-artifact.sh`](../shared-install/), which holds a lock across
   the whole read-compare-write and renames the file into place.
4. Run the harness. Report the result in the host's adoption PR.

```bash
tools/reviewer-cli-conformance.sh --family                 # every host copy + the shared install
tools/reviewer-cli-conformance.sh path/to/reviewer-cli.sh  # one copy
```

If a host genuinely needs different behaviour, change it **here** and add a
harness row, then re-vendor. That is the point of this directory.

## Why this is published

Three divergent copies existed at one shared path with no arbitration:

| host | lines | vendor arms |
|---|---|---|
| `codex-workflow` | 95 | claude, gemini, **opencode**, codex |
| `pi-agentic-apps-workflow` | 85 | claude, gemini, codex |
| `opencode-workflow` | 72 | gemini, codex |
| `claude-workflow` | — | ships none |

On 2026-07-25 a host installer delivered the correctly-arbitrated `1.2.2` change
gate and, **in the same run**, blind-installed a 3-arm wrapper over the 4-arm
one. The next review that asked for `opencode` got:

```
reviewer-cli: unknown vendor 'opencode' (expected: gemini | codex | claude)
```

Not a gate bypass — a producer excluding its own host still had two vendors, and
§18's floor still held. But it is a silent capability loss that
surfaces mid-review as `unknown vendor`, gets recorded as "reviewer unavailable",
and moves on with one fewer opinion. That is a quiet degradation of the exact
evidence §18 exists to compel.

The canonical below is a **merge**, not a pick: `pi`'s structure (stdin pinned
inside `run_bounded`, explicit usage checks, the unbounded-run warning) with
`codex`'s coverage (four arms and the model-provenance note). Neither copy was
simply better than the other.
