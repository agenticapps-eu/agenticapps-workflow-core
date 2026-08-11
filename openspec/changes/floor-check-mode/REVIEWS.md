---
reviewers: [gemini, codex]
models: [gemini-cli-default (not printed by the CLI — see Not counted), gpt-5.6-sol]
verdicts: [REQUEST-CHANGES, REQUEST-CHANGES]
reviewed_artifacts_sha: sha256:352188626dc50cf8c49040c56c2808854e1413ecd1f92ffee7f7eef851143023
---

# Change review — floor-check-mode

Two vendors, neither of them this host's. Both returned REQUEST-CHANGES and both
found the same HIGH independently, from different directions: the proposal
promises a fleet answer and the plan only specifies a repository-local one.

## Reviewer: gemini (model id not resolved)

VERDICT: REQUEST-CHANGES

- [HIGH] tasks / spec delta — the fleet-wide report is unspecified. The proposal
  promises "which repositories the floor cannot reach"; every task and scenario
  operates on the current repository only. — Add scenarios for reporting on
  multiple repositories, either by scanning a tree (`--check --scan ~/Sourcecode`)
  or by accepting repository paths as arguments.
- [MEDIUM] spec delta — a `.git/hooks/pre-commit` has the highest precedence of
  all, so `--check` could report a repository as governed by the floor while a
  local hook silently bypasses it. — Inspect `.git/hooks` and report a
  `pre-commit` found there as the effective, overriding hook.
- [LOW] tasks §1 — task 1.2 reopens a decision the proposal already made. A
  proposal should commit. — Delete task 1.2.

Assumptions it named: that a discovery mechanism exists and is unspecified; that
`core.hooksPath` alone determines the active hook; that the mode is for
interactive use only and has no automated-health-check role.

## Reviewer: codex (gpt-5.6-sol)

VERDICT: REQUEST-CHANGES

- [HIGH] proposal / What changes — neither the census scope nor a discovery
  source is defined, while task 4.2 expects fleet counts. — Define an explicit
  read-only root or repository list (traversal, bare repositories, linked-worktree
  dedup, unreadable paths, invocation outside a repository), **or** limit `--check`
  to the current repository and drop the fleet claims.
- [HIGH] workflow-installation delta — the central defect is not specified. No
  scenario requires an `openspec/` repository with absent/false/malformed
  enrolment to be reported ungated, and none covers displaced repository hooks.
  They exist only as tasks, so they will not survive archival as requirements. —
  Add normative scenarios, with the enrolment lookup defined exactly as the
  dispatcher does it.
- [HIGH] core-self-enforcement delta — the MODIFIED block replaces the
  requirement whole and drops its rationale and all three existing scenarios.
  Validation does not catch semantic deletion. — Restate the requirement
  verbatim, then append the new behaviour.
- [HIGH] workflow-installation delta — "names the surfaces that enforce the gate"
  is undefined and can produce false assurance: an executable, byte-current
  dispatcher still fails **open** when the gate executable is absent. CI
  enforcement cannot be inferred from a hook binding. — Enumerate exactly which
  surfaces are inspected and what makes each active.
- [MEDIUM] currency scenarios — no complete state model. Absent, newer than the
  checkout, older, markerless, symlinked are all missing, and byte-inequality
  cannot distinguish a legitimately newer published file from a hand-edited one
  when the publisher deliberately preserves newer versions.
- [MEDIUM] dangling scenario — does not say whether it means the global or the
  effective binding; the machine-wide consequence is wrong for a dangling local
  override. An existing directory with no `pre-commit` ungates just as
  effectively and is untested.
- [MEDIUM] tasks §3 — "repairs nothing" and "exit 0 whatever it finds" are task
  prose, not normative behaviour, and "whatever it finds" conflates reportable
  drift with operational failure.
- [MEDIUM] CLI grammar unspecified alongside the positional migration arguments.
- [LOW] tasks §1 — task 1.2 leaves a settled decision to implementation, and the
  documentation says both "had to be deferred" and "is dropped".

Assumptions it named, the sharpest first: that `~/Sourcecode` is the authorized
census root; that **every repository containing `openspec/` is intended to
enrol**; that local config is the only possible effective override; that
dispatcher bytes plus the execute bit prove the gate can run.

## Not counted

- No reviewer failed, timed out or was absent — both arms returned. What is
  missing is gemini's **resolved model id**: its CLI prints no model line and a
  direct `gemini -p "reply with your model id"` returned nothing usable through
  the hook noise. Recorded as unresolved rather than guessed, because rule 4
  exists so that two arms pointed at one model cannot pass as two opinions, and
  an invented id defeats that more thoroughly than an admitted gap.

## Resolution

**Both HIGHs about the census are accepted, and neither proposed remedy is
taken.** `--check` gains **positional repository arguments**, exactly as the
migration path already has them: `--check [repository ...]`. With none, it
reports the repository it runs in. There is no scan, no declared root, no
walk — the binder's own text says the migration set is *named, never
discovered*, and a mode that inspects has no better claim to search the machine
than the mode that mutates. Task 4.2's re-measurement is then a shell loop that
names its repositories, and what it measures is stated rather than inferred.
Bare paths and non-repositories are **reported and skipped**, not refused: the
migration stops the whole run on a bad name because it is about to mutate; a
report has no such reason, and refusing one section of it discards the other
nine.

**codex's second HIGH is accepted in full.** Tasks 2.5 and 2.6 become scenarios,
and the enrolment lookup is pinned to what the dispatcher actually does —
`--local --type=bool`, value must normalise to `true` — so `false`, a malformed
value and a global-only key all read as *not enrolled*, which is the dispatcher's
behaviour and therefore the truth about whether the commit is gated.

**codex's third HIGH is accepted, and it was independently confirmed here before
the review returned.** The live requirement carries three scenarios and a
rationale the delta's MODIFIED block would have deleted; the same failure cost a
previous change three archive attempts. The block now restates the requirement
and appends.

**codex's fourth HIGH is accepted, and it is the most valuable finding in either
review.** The dispatcher *fails open* when the gate executable is missing — it
warns and exits 0 — so a floor that is bound, published, current and executable
still gates nothing if `~/.agenticapps/bin/openspec-change-gate.sh` is absent.
A check mode that reported "bound and current" there would be the false
assurance this change exists to remove, arrived at by the change itself. The
inspected surfaces are now enumerated: the published dispatcher, **the gate
executable it invokes**, and the `hooks.d` entries. CI is explicitly not
inspected and no claim is made about it.

**gemini's MEDIUM is rejected on the facts, and the correction is kept.** Git
precedence runs the other way: when `core.hooksPath` is set, `.git/hooks` is not
consulted at all. Measured here on git 2.50.1 (Apple Git-155) — a repository
with an executable `.git/hooks/pre-commit` and a global `core.hooksPath` ran the
floor's hook and never the local one. So a local hook cannot silently bypass the
floor; the floor silently *displaces* the local hook, which is the inverse
condition and is task 2.6. The finding pointed at the right file for the wrong
reason, and the scenario it asked for exists — reporting displacement rather
than override.

**Both LOWs are accepted, and task 1.2 is answered rather than deleted.** The
answer is *say nothing*: `--project` was superseded outright by the archived
`one-enforcement-floor`, so no requirement is added. The task stays as the record
of a fork that was closed. The contradiction codex found is real and is task
1.1's whole content — `docs/HOW-IT-FITS-TOGETHER.md` says "that gap is why
`--project` had to be deferred" on line 160 and "`--project` is dropped, not
pending" on line 229. Both go.

**codex's MEDIUMs are accepted.** Currency mirrors `install.sh`'s
`check_artifact`, which answers the same question one directory over and already
distinguishes *modified* (same version, different bytes) from *ahead* (published
version newer) — inventing a second answer to a solved question is how two
doctors come to disagree about one machine. Dangling is split: the machine
section reports the **global** binding and its machine-wide consequence, the
repository section reports the **effective** one. "Reports and repairs nothing"
becomes a requirement with scenarios, and it carries the carve-out the finding
asks for: a completed report exits 0 whatever it found, and a usage error is not
a finding.

**On the CLI grammar**, the minimum is specified and no general option parser is
added. `--check` is recognised as the first argument; everything after it is a
repository. `--check` in any later position keeps today's behaviour, which is to
be read as a repository name and refused — safe, already tested, and not worth a
parser this change did not come to write.

**Two things neither reviewer could have found, recorded because each changes
the work.** First, where the code goes: the RED baseline was run before the
reviews returned, and the current binder does not merely refuse `--check`, it
creates `~/.agenticapps/git-hooks` *first* and then refuses. So `--check` cannot
be a branch somewhere convenient in the flow — it has to be handled before the
`mkdir -p`, or the mode that promises to write nothing writes a directory on its
first run.

Second, task 4.3 was wrong and would have caused the exact failure codex's
currency MEDIUM warned about. It said to bump `global-floor-version` and
publish. That marker is on the published **dispatcher**, `pre-commit`, at 1.1.0
— which this change does not touch. The binder carries no version marker and is
not a published artifact at all; `install.sh` runs it from the checkout, so
`git pull` is its update path and nothing arbitrates on it. Bumping the marker
would have told every machine that its correct 1.1.0 dispatcher was stale,
because `--check` judges currency by content against the checkout. The task is
replaced by its inverse: assert the dispatcher is byte-unchanged, publish
nothing.

---

# Step 4 — the diff review

Recorded here rather than in a second file, because a reader asking "who read
this" should find one answer. Step 2b above read the **plan**; this read the
**diff**.

## Reviewer: codex (gpt-5.6-sol) — VERDICT: REQUEST-CHANGES

**The first attempt does not count.** It timed out at the wrapper's 300s default
and returned an empty review; re-run at `REVIEWER_TIMEOUT=900` it completed.
Recorded because a timed-out reviewer silently counted is exactly how one vendor
comes to satisfy a two-reader rule.

It ran `shellcheck -S warning` against the file before reasoning about it. That
is worth keeping: shellcheck is clean on everything this change adds, and its one
warning (`SC2034`, `m_common appears unused`) is pre-existing and in the
migration path.

Six findings, four accepted outright, one accepted after correcting its framing,
one declined:

- **[HIGH] every executable dispatcher stayed `FLOOR_ACTIVE=1`**, so an enrolled
  repository behind a *hand-edited* dispatcher was reported plainly "gated".
  **Accepted, with the framing corrected.** The fix is not to call a modified
  dispatcher inactive — that would drag `ahead` in with it and produce the false
  alarm the plan review already warned about. It is that these are **two claims**:
  git runs the dispatcher (structural, knowable) and the dispatcher is still this
  checkout's gate (content). A new `FLOOR_VOUCHED` carries the second, and the
  verdict is qualified rather than flipped.
- **[HIGH] `hooks.d` entries listed as running with none of the dispatcher's
  guards applied.** Accepted in full, and the sharpest of the six: the dispatcher
  **refuses to run at all** on a symlinked, unowned or group/world-writable
  `hooks.d`, which blocks every commit in every enrolled repository. The report
  described that wedged machine as healthy and listed the entries as active.
- **[HIGH] core classified by presence rather than by where the binding points.**
  Accepted in full; all three sub-cases were wrong. An unset binding on an
  *unbound* machine was called "governed by the floor" when nothing governs it; a
  declared binding aimed elsewhere was called healthy, which would let a
  declaration launder any path; and a foreign undeclared binding was called "at
  risk of being swept" when the migration refuses to sweep exactly that, by name.
- **[MEDIUM] relative `core.hooksPath` resolved against the checker's cwd.**
  Accepted, and it is not a hypothetical shape — husky has shipped
  `core.hooksPath = .husky/_` for years. Worth recording *how it nearly escaped*:
  the first test resolved correctly by accident, because it checked the
  repository the checker was standing in, so the two directories coincided. It
  passed against the bug. Re-pointed at a **named** repository it failed, which
  is the whole class of defect this mode's grammar creates.
- **[MEDIUM] the dispatcher was never required to be a regular file.** Accepted:
  `[ -x ]` is true of a directory, and `grep` on a FIFO blocks forever — so the
  mode could **hang** rather than report, which is the one failure a diagnostic
  must not have.
- **[MEDIUM] the gate override is resolved once, against the checker's cwd, and a
  slashless value would go through `PATH`.** **Declined, and the reason is
  stated rather than hidden.** The default is absolute and every realistic value
  is; carrying per-repository gate state to serve a relative or slashless
  `OPENSPEC_GATE` adds loop-carried state for a case nobody has. The limitation
  is real and is recorded here rather than built.

Seven assertions were written for the five accepted findings, all observed RED,
then GREEN twice. The suite went 132 → 139.

---

## Why the gate cannot verify this file, and why it is not being made to

The gate prints `NOTE ... has a REVIEWS.md this gate cannot verify
(trailer-absent)`. That is accurate and it is being left alone.

`run-plan-review.sh` stamps a trailer — `implementing-host`, `digest`,
`producer-version` — binding the evidence to a digest of `proposal.md`,
`design.md` and `specs/**`. This file was written by hand, following the
`openspec-change-review` skill, whose documented format is YAML frontmatter and
carries no trailer at all. So a skill-shaped REVIEWS.md is unverifiable to the
gate by construction, which is worth reporting as a divergence between the two
rather than working around.

**And the trailer must not be forged here, because it would be false.** Its
digest asserts which artifacts the reviewers saw. Both reviews above are of the
delta *as it stood before their findings were resolved*, and resolving them
changed `specs/**` substantially — that is the entire point of running them
before code. A hand-stamped digest over the current files would claim the
reviewers approved artifacts they never read, which is precisely the staleness
the digest exists to detect. `trailer-absent` is the honest state: evidence
exists, and the machine is right that it cannot vouch for it.
