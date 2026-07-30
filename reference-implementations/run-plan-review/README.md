# run-plan-review — reference implementation

The **review producer**. It drives other-vendor agent CLIs over an active
OpenSpec change and writes `openspec/changes/<slug>/REVIEWS.md`. The §18
change-gate is the **verifier**: it refuses code edits until this script has
written evidence the gate accepts. Producer and verifier are deliberately
separate processes.

`run-plan-review.sh` is installed at one shared path,
`~/.agenticapps/bin/run-plan-review.sh`. Vendor it. Do not maintain a host copy
— a private fork of a file at a shared path is not a fork, it is a race.

**This directory was created late.** The gate, `reviewer-cli` and the shared
installer were all tracked here first; the producer sat in the same shared
directory, installed by the same script, and was maintained only as an installed
artifact. The copy at `gate/run-plan-review.sh` in this repo is a 66-line
*ancestor*, not the running implementation — the 227-line 1.0.0 that actually
runs was seeded here byte-identically from `~/.agenticapps/bin/`, which is why
the baseline is provably what executes rather than what someone believed
executes.

**Change behaviour here only alongside a matching harness row**
(`tools/run-plan-review-conformance.sh`). Its two sibling artifacts earned that
rule the hard way.

## Contract

| | |
|---|---|
| Invocation | `run-plan-review.sh <change-slug> [reviewer...]` |
| Vendors | `claude` · `gemini` · `opencode` · `codex` |
| Reviewer dispatch | delegated to `reviewer-cli.sh` — never reimplemented here |
| Output | `openspec/changes/<slug>/REVIEWS.md`, plus progress on stderr |

The change slug is a **single directory name**. A slug containing `/`, or equal
to `.`/`..`, or beginning with `-`, is rejected: the slug is pasted into a path
that is later written to, so a traversing slug would make this script overwrite
an arbitrary file. A symlinked change directory is refused for the same reason.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | the floor was met; `REVIEWS.md` was written |
| `1` | fewer reviewers succeeded than the floor requires |
| `2` | usage error — bad slug, no such change, missing required input |

## Environment

| Var | Meaning |
|---|---|
| `REVIEW_TIMEOUT` | hard wall-clock cap per reviewer, seconds (default `180`) |
| `MIN_REVIEWERS` | reviewers required for a non-warning exit |
| `REVIEWER_CLI` | override the wrapper path (default: shared install, then `bin/`) |

## The version marker

The first lines carry `# run-plan-review-version: <semver>`. Every host
installer MUST read it before writing this file to the shared path and MUST
refuse to overwrite a higher version; an unmarked file is `0.0.0`.

That marker is **late**, and the reason is recorded in the script's own header:
the gate and `reviewer-cli` were both given one after core#41, in which a host
installer blind-installed a 3-arm `reviewer-cli` over a 4-arm one, the
`opencode` arm vanished, and the next review that asked for it was recorded as
"reviewer unavailable" and waved through with one fewer opinion. The producer
sat three lines below that arbitration block and was left blind. Nothing had
broken only because no sibling host shipped a producer to overwrite it with —
luck, not design.

## Relationship to `reviewer-cli.sh`

This script picks the vendor set and records the evidence. **The wrapper owns
vendor dispatch, the stdin pin and the wall-clock bound.** This script used to
carry its own copy of the four vendor arms; that is exactly the shape that
produced core#41 — three divergent copies of one wrapper, one missing the
`opencode` arm, all writing the same shared path.

Fix vendor behaviour in `reference-implementations/reviewer-cli/` alongside a
harness row and re-vendor. Never patch the arms back in here.

A vendor name outside core's set (`claude` · `gemini` · `opencode` · `codex`)
is reported unavailable rather than run unbounded.

## The egress boundary

Invoking this script sends the change's artifacts to third-party agent CLIs.
State it as it is, not as it is comfortable:

- **The vendor CLIs are agentic and run with the operator's credentials.** The
  boundary is *what they can reach on this machine as this user* — not the
  prompt, and not the repository. They can read files outside the change, and
  they can **write and execute**, not only read.
- **Consent is scoped to vendor selection**, which is the act of invocation. It
  is not consent to a specific file set, because the producer does not control
  what an agentic CLI reads once running.
- **No secret or PII screening is performed** in either direction. Check before
  invoking. Screening is deferred to the named follow-up change
  `screen-review-egress`, which covers the return path as well as the outbound
  one.
- **Reviewer output is untrusted third-party input.** It is written into
  `REVIEWS.md` verbatim by design — a review that could be rewritten would not
  be a review — and agents subsequently read that file as context. §14 governs.

The `## Reviewer:` forge guard and the stdout sanitiser are **not** injection
controls. The guard defends the reviewer *count*; the sanitiser strips banner
noise from a response's edges without altering its interior. Neither reads
meaning, and the capability says so rather than claiming otherwise.

## Independence is a different CLI, not a different model

The vendor vocabulary names CLIs. `opencode` can be configured to route to the
same provider and model as the implementing host, in which case two counted
"independent" reviewers are one model answering twice. The claim is made in its
weaker, true form. Recording provider and model identity would strengthen it and
is not attempted — the CLIs do not report it uniformly.

## Why this is published

The same failure has now happened three times in this fleet: five divergent gate
copies ([#32](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/32),
ADR-0022), three divergent `reviewer-cli` copies that silently dropped a vendor
arm ([#41](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/41)),
and a producer whose in-repo copy diverged 161 lines from the one that runs.
Every one went unnoticed because a drifted artifact reports clean.
