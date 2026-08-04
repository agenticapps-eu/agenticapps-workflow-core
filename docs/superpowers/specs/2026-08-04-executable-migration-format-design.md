# Executable migration format — design

**Date:** 2026-08-04
**Scope:** core spec §08 revision + extractor / runner / linter.
**Not in scope:** the installer (Part 2) and the Docker smoke run (Part 3).
Decisions taken today that constrain those are recorded in the appendix so they
are not lost, but nothing here builds them.

## Problem

Migrations are markdown mixing prose with shell. Applying one requires an agent
to read it and act. That makes installation depend on an authenticated coding
agent with token budget, and makes it non-reproducible: two runs against the
same repo can produce different trees.

The goal is determinism. Testability is a side benefit, not the case.

## What the survey found

Re-derived from the repos on 2026-08-04, superseding the brief's 2026-08-03
figures.

| Claim | Status |
|---|---|
| 91 of 92 fenced blocks are `bash`, one `yaml` | Confirmed |
| 16 codex migrations | Confirmed |
| 13 of 16 carry the complete quartet on every step | Confirmed |
| `0014` has zero structured sections across 7 steps | Confirmed |
| `0015` has zero structured sections | **Wrong.** Partial: 5 steps, step 1 complete, step 2 has a check but no pre-condition, steps 3–5 nothing, and no step has a rollback |
| `0000`'s interactivity is a 12-field form | **14 fields.** Includes `{{BACKEND_OVERRIDE}}`, conditional on `BACKEND = Other`, and `{{PLACEHOLDERS}}`, which is prose referring to the others rather than a field |
| `0006` | Not previously noted: 3 steps, 2 pre-conditions — a one-step gap |

Two findings the brief did not anticipate:

**§08 already mandates the quartet.** `spec/08-migration-format.md:81` — "Every
migration body MUST contain at least one step. Every step MUST have four
sections, in this order." `0014` and `0015` are therefore already
non-conformant against spec 0.9.1. They are not decay awaiting a new format.

**A hardened extractor already exists.** `codex-workflow/migrations/run-tests.sh`
is 7,176 lines; lines 71–190 are `extract_step_block()`, which pulls the fenced
block following a `**<Label>:**` marker within a numbered step. It carries a
delimiter guard so `Step 1` cannot match `Step 10`+ (added under review as
D-12), an inline-code-span fallback for `0007`/`0008`'s single-line steps
(MIGR-08), and a deliberate literal-prefix match so a metacharacter in a label
cannot inject a regex. Ported from `claude-workflow` at a pinned SHA.

## The finding that set the scope

Fleet-wide, corrected (the first scan missed that claude-workflow stamps its
version in `SKILL.md`, not a `workflow-version.txt`):

| Repo | Host | Version | Latest | Status |
|---|---|---|---|---|
| agenticapps-dashboard | claude / opencode | 3.2.0 / 1.0.0 | 3.2.0 / 1.0.0 | current |
| agenticapps-roadmap | claude | 3.2.0 | 3.2.0 | current |
| agents-task-viewer | claude / codex | 3.2.0 / 1.2.0 | 3.2.0 / 1.2.0 | current |
| callbot | claude / codex | 3.2.0 / 1.2.0 | 3.2.0 / 1.2.0 | current |
| cparx | claude | 3.2.0 | 3.2.0 | current |
| cparx | codex, opencode | 0.5.0 | 1.2.0 / 1.0.0 | **vestigial — no skills installed** |
| fbc-platform | claude | 3.2.0 | 3.2.0 | current |
| fx-signal-agent | claude | 3.2.0 | 3.2.0 | current |

Every live install is current. `cparx`'s two lagging stamps describe host
installs abandoned mid-setup around 20 July: `.codex/` was never committed to
git and has an empty skills directory; `.opencode/` has a tracked config and an
empty skills directory. Neither host can run the workflow there.

**Therefore no migration ever needs to replay.** Fresh setup already installs a
snapshot rather than replaying (ADR-0036). The 73 existing migrations across
four hosts are frozen history.

This is what makes the format greenfield: it governs migrations written from
now on, and retrofit scope is zero.

## Design

### The fence contract

Steps keep their prose headings and gain a role tag on each executable fence.

    ### Step 3: Rewire both floors to real mode dispatch

    Prose explaining why — unchanged, and still where the reasoning lives.

    **Idempotency check:**
    ```bash role=check
    grep -q 'gate-version:' "$(git rev-parse --git-path hooks)/pre-commit"
    ```

    **Pre-condition:**
    ```bash role=precondition
    test -x "${AA_BIN:?}/openspec-change-gate.sh"
    ```

    **Apply:**
    ```bash role=apply
    install -m 0755 "$SRC/bin/git-hooks/pre-commit" "$(git rev-parse --git-path hooks)/pre-commit"
    ```

    **Rollback:**
    ```bash role=rollback
    git checkout -- "$(git rev-parse --git-path hooks)/pre-commit"
    ```

Roles and the heading each sits under:

| Role | Heading |
|---|---|
| `check` | `**Idempotency check:**` |
| `precondition` | `**Pre-condition:**` |
| `apply` | `**Apply:**` |
| `verify` (optional) | `**Verify:**` |
| `rollback` | `**Rollback:**` |

The first four headings are §08's existing quartet, unchanged. `**Verify:**` is
new — `0001` expresses the same idea as `**Verbatim assertion (post-apply):**`,
which is prose rather than a contract. The new format standardises the name.

**Un-annotated `bash` fences are illustration and are never executed.** This is
the property that lets migrations keep explanatory snippets, and it is why L4
below exists.

Why both markers rather than one: the headings are already a MUST, already
readable, and already extracted by working reviewed code. The role tag adds the
one thing headings cannot express — that a given fence is not meant to run. The
cost is two markers that could disagree, which L2 makes an error.

### The linter

| Rule | Requirement |
|---|---|
| L1 | Every step has exactly one `check`, one `precondition`, one `apply`, one `rollback`. `verify` is 0 or 1. |
| L2 | Each `role=` fence sits under its matching `**Label:**` heading. Disagreement is an error. |
| L3 | No duplicate roles within a step. |
| L4 | Unknown role values are rejected. `role=aply` fails loudly. |
| L5 | `role=` appears only on `bash` fences. |

L4 is load-bearing. Because un-annotated fences are illustration, a typo silently
demotes a real command to a comment, and the runner would report success having
done nothing. That is the same defect class as the codex untrusted-hook failure
and pi's non-interactive trust default: installed, looks correct, enforces
nothing. Do not relax it into a warning.

### Which files the linter judges — B3 + cross-check

An **ID threshold**, declared per host in its instruction file: every migration
at or above that ID MUST be executable. The linter keys on the filename's ID,
which cannot be forgotten because it already exists.

Given each host's current head, the thresholds are the next unused ID:

| Host | Last migration | Threshold |
|---|---|---|
| claude-workflow | `0034` (→ 3.2.0) | `0035` |
| codex-workflow | `0015` (→ 1.2.0) | `0016` |
| opencode-workflow | `0011` (→ 1.0.0) | `0012` |
| pi-agentic-apps-workflow | `0010` (→ 1.2.1) | `0011` |

Alongside it, new migrations carry `migration_format: executable` in
frontmatter. The linter cross-checks the two and errors on disagreement — the
same shape as L2.

Rejected: a frontmatter field alone (can be forgotten, and a forgotten
declaration means the file is silently never checked), and presence-of-any-`role=`
(worse — a migration that omitted every tag is invisible to the linter and does
nothing when run).

The linter blocks from day one. Nothing existing is in scope, so there is no
grandfather list and no cost to blocking.

### Runner semantics

Per step, in order:

1. `check` — exit 0 means already applied. Skip the step, log `skipped (already applied)`.
2. `precondition` — non-zero aborts. **The block's own stderr is printed verbatim, never paraphrased.** This is what preserves `0001`'s exit-3 two-option remediation message.
3. `apply` — on failure, see the failure policy below.
4. `verify`, if present — on failure, same policy.

### Failure policy — A2

§08 currently requires an interactive three-option prompt on mid-migration
failure, and forbids auto-rollback without consent. A runner working unattended
cannot satisfy the first. Amended:

- **stdin is a TTY** — behaviour is exactly as specified today: prompt with
  retry / skip-with-warning / rollback.
- **stdin is not a TTY** — the runner aborts where it stands, prints which steps
  applied and which did not, and **rolls back nothing**.
- `--on-failure=abort|prompt|skip` overrides either way.

Rolling back unattended was considered and rejected. It does the thing the spec
forbids, on the reasoning that absence of anyone to ask is not consent. It also
destroys evidence: a half-applied migration plus a loud error is diagnosable,
an auto-rollback is not. The spec's own stated reason for the rule — partial
state is sometimes more useful than a full revert — applies more strongly when
nobody is watching, not less. The counter-argument (never leave a half-applied
tree) matters most when the same machine will retry, and that case has a TTY,
so it prompts anyway.

**A consequence worth naming: under A2, `rollback` never runs unattended.** L1
requires every step to have one, but the only path that executes it is a human
choosing rollback at an interactive prompt. That makes rollback the least-tested
block in every migration — mandatory to write, rare to exercise, and therefore
the most likely to be quietly wrong. The fixture suite compensates by running
each rollback directly against its own step's post-apply state rather than only
through the runner's failure path. If rollbacks still rot, the honest options
are to test them harder or to stop mandating them, not to leave a required block
that nothing ever runs.

### Dry-run

§08 currently promises dry-run "prints the diff each step would apply." A runner
that has not executed `apply` cannot produce a real diff. Dry-run will run
`check` and `precondition` and print the apply block's **source**. The spec text
is corrected to promise what is deliverable rather than keep a claim nothing
satisfies.

### Layout

- `spec/08-migration-format.md` — revised; `spec_version` 0.9.1 → 0.10.0.
- `reference-implementations/migration-runner/` — `extract.sh`, `run-migration.sh`,
  `lint-migration.sh`, each carrying a `# migration-runner-version:` marker so
  Part 2 can publish them into `~/.agenticapps/bin/` under the same arbitration
  the gate and reviewer CLI already use (ADR-0047).

Bash, not JavaScript: the steps are bash, so a JS runner shells out for every
block and buys only a process boundary; and it keeps migrations runnable on a
machine with no Node.

### Testing

TDD, RED before GREEN. Fixture migrations under
`reference-implementations/migration-runner/test-fixtures/`:

- one conformant migration exercising all five roles including `verify`;
- one deliberately broken fixture per linter rule L1–L5;
- the L4 fixture (`role=aply`) is the one that must be seen failing before the
  rule is written;
- a runner fixture asserting `precondition` stderr reaches the caller byte-for-byte;
- a runner fixture asserting non-TTY failure leaves the tree half-applied and
  rolls back nothing (the A2 contract);
- a rollback fixture per step, run directly against that step's post-apply state,
  because the runner's own failure path never reaches rollback unattended.

## §08 text changes

1. **Step structure** — add the role-tag requirement alongside the four labels;
   state that un-annotated fences are never executed.
2. **New subsection, "Executable form"** — the five roles, the ID threshold, the
   `migration_format` field, and the requirement that each host declare its
   threshold in its instruction file.
3. **Atomicity contract** — amended per A2 above.
4. **Dry-run** — corrected per above.
5. **Conformance** — a new MUST that the host's migration harness runs the
   format linter.

## Appendix — decisions taken today that bind Parts 2 and 3

Recorded here because they were settled in the same conversation, not because
this change implements them.

- **No npm package, no Ink TUI.** `@agenticapps/workflow` is dropped. The
  installer is bash, fetched by `curl` from a **tagged** URL, documented in
  core's README with the download-inspect-run form shown next to the one-liner.
  `curl | bash` writing into a shared directory every agent reads from is a
  trust boundary and the README says so.
- **Version axes drop from four to three** — installer marker, host
  `specVersion`, project `workflow-version.txt`.
- **Bootstrap and runner stay separate scripts.** One clones, detects and
  installs; the other executes migration steps. They fail differently, are
  tested differently, and only the bootstrap touches the network.
- **Host detection is detect-then-ask, multi-select.** Not the brief's
  error-rather-than-guess. With a TTY, present the detected hosts and let the
  user pick which to install; without one, require `--host a,b` and error rather
  than guess. `cparx` is the evidence for multi-select: two hosts half-installed,
  neither finished, both leaving version stamps behind. `openspec` is detected
  separately as a dependency, not as a host.
- **`apply-agent` is deferred**, not rejected. It existed to absorb legacy prose;
  there is no legacy prose in scope. Adding it later is an amendment.
- **`answers:` frontmatter is out of §08.** Its only consumer was
  `0000-baseline`, which never replays. Collecting the 14 setup placeholders
  belongs to the installer's setup path.
- **The smoke run's update leg has nothing to test against.** Every migration
  that exists is historic. It needs a purpose-built new-format migration.
- **`cparx`'s two vestigial stamps are unresolved.** `.codex/` (untracked, no
  skills) and `.opencode/` (tracked config, no skills), both at 0.5.0. They are
  the only thing in the fleet that makes historic migrations look live. Deleting
  them is a call for the `factiv` family, not this change.
