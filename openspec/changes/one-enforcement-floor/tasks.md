# Tasks — one enforcement floor

**No longer blocked.** `core-installer-one-entry-point` was archived on
2026-08-06 and `workflow-installation` is durable truth. This change is first in
the chain and must land before `projects-bind-not-copy`.

## 0. Prerequisites

- [x] 0.1 `core-installer-one-entry-point` is archived and `workflow-installation`
      exists in `openspec/specs/` — confirmed 2026-08-07
- [x] 0.2 Record the installer's executable line count before any edit.
      **Measured 2026-08-07: `install.sh` is at exactly 217.** The canonical
      counter is `grep -cvE '^[[:space:]]*(#|$)'` (`tools/install.test.sh:436`)
      and the assertion is `-le 217` (line 437), so **headroom is zero** — not
      the 5 this task recorded, and not the 7 an earlier revision claimed. The
      change `fresh-clone-needs-nothing` spent the remaining five lines on the
      `init-project` artifact and the opsx binder. A raise is therefore no longer
      "near certain", it is unavoidable for any wiring added inline, and the
      requirement demands the growth be itemised rather than pre-approved
- [x] 0.3 Record which repositories carry a `pre-commit` and the byte size of
      each. **Done 2026-08-07**, resolving hooks directories with
      `git rev-parse --path-format=absolute --git-path hooks` rather than
      assuming `.git/hooks`: 11 repositories over 10 distinct hooks directories
      (`agenticapps-dashboard-add-agent-board` is a linked worktree sharing the
      dashboard's); nine are the gate at 1201, 1376, 2270 and 5844 bytes; the
      tenth directory is `fbc-platform`'s husky. `cparx` carries none.
      The earlier figures — nine repositories, sizes 883/1201/2270/5844, "no
      husky, no `pre-push`, no `commit-msg`" — were wrong in every clause
- [x] 0.4 Record the six repositories that set a local `core.hooksPath` and what
      each names, as the before-state for the sweep in section 3.
      **Done 2026-08-07.** Neither `--global` nor `--system` sets it, so there is
      no floor on this machine today. Six bindings over **five** config files —
      `agenticapps-dashboard-add-agent-board` is a linked worktree and shares
      `agenticapps-dashboard/.git/config`:

      | Repository | `core.hooksPath` names |
      |---|---|
      | `factiv/callbot` | its own `.git/hooks` |
      | `factiv/fx-signal-agent` | its own `.git/hooks` |
      | `agenticapps/claude-workflow` | its own `.git/hooks` |
      | `agenticapps/agenticapps-dashboard` | its own `.git/hooks` |
      | ~~`agenticapps/agenticapps-dashboard-add-agent-board`~~ | **gone — worktree removed 2026-08-07** |
      | `factiv/fbc-platform` | `.husky/_` — the one genuine opt-out |

      **Superseded the same day.** The stray worktree was removed (the dashboard
      is retired; its branch `chore/setup-codex-workflow` is pushed and intact at
      `a44ba77`). The before-state for the sweep is therefore **five bindings
      over five config files**, one checkout each — the shared-config special
      case is gone. Section 3b is simpler by exactly one row

## 1. Inherited, not done here

The host wiring was stripped from `core-installer-one-entry-point` before it
ran, so this change starts from an installer that writes no host configuration.

- [x] 1.1 Wiring removed, `hosts/` deleted, `--accept-host-config` retired —
      landed in the predecessor, with the negative tests that assert the files
      rather than the absence of the functions
- [x] 1.2 Confirm on the archived predecessor that the claim still holds before
      building on it: no host-named code outside `HOSTS` and `--check` strings.
      **Measured 2026-08-07 — the claim does NOT hold.** Three sites in
      `install.sh` carry host-named code outside both:

      | Line | What |
      |---|---|
      | 54 | `ARCHIVED="claude-workflow codex-workflow opencode-workflow pi-agentic-apps-workflow"` |
      | 160–161 | `${1#codex-}` and `${n#opencode-}` in `neutral_of()` — host-prefix stripping |
      | 166 | `"$HOME/.claude/skills"` hard-coded in `neutral_of()`'s search order |

      None is reachable from `--check`: `neutral_of` is reached only via
      `sweep_vendored` → `bind_dir` → `install_hosts`, and `scan_archived` runs
      on the install path. Lines 5, 148 and 303–304 are comments and do not bear
      on the claim. **This is inherited, not introduced here** — every site
      predates this change. It is recorded rather than fixed, because task 7.2
      expects the after-measurement to be `HOSTS` and `--check` only, and that
      expectation is now known to be unreachable without removal work this
      change has not scoped. Resolve in 7.2 before relying on it

## 2. Publish and bind the global floor

- [ ] 2.1 Publish the gate's `pre-commit` to the machine-level hooks directory
      through the arbitrating installer, with a version marker, exactly as the
      other three executables are published
- [ ] 2.2 Bind it with `git config --global core.hooksPath <dir>`
- [ ] 2.3 Refuse and report a foreign existing `core.hooksPath`; the step counts
      as skipped so the run exits non-zero
- [ ] 2.4 Report an existing binding that is already ours as satisfied, not as
      a no-op and not as a fresh install
- [ ] 2.5 The published hook dispatches to the gate and propagates its exit
      status
- [ ] 2.6 The dispatcher composes with an operator-owned, machine-level
      `hooks.d` alongside the published directory, running each entry and
      failing the commit on the first non-zero exit
- [ ] 2.7 The dispatcher SHALL NOT exec anything resolved from inside a
      repository — not `.git/hooks/`, not a tracked path. A global hook that
      falls back to repository-controlled code makes every clone executable at
      commit time, which is the property `core.hooksPath` exists to remove.
      Assert it as a negative test, not a convention
- [x] 2.8 **Scope predicate decided 2026-08-07: an explicit opt-in marker.**
      Measured first: the gate exits 0 in a repository with no `openspec/` and in
      one whose `openspec/` is unrelated, but **blocks the commit** in any
      repository containing an `openspec/` tree that fails `openspec validate
      --all` — a fixture, a vendored example, an abandoned experiment. A global
      binding therefore imposed a blocking hook on repositories that never opted
      in. Raised independently by two reviewers as the change's largest unbounded
      risk. The published hook now checks a local git config key,
      `agenticapps.workflow.enrolled`, and exits 0 when it is absent. Rationale
      and the two rejected alternatives are in `design.md`
- [ ] 2.8a Implement the predicate in the published hook, ahead of the gate call,
      with the negative test: a repository carrying a malformed `openspec/` tree
      and **no** marker commits successfully.
      **Prototyped and proven 2026-08-07** — one line ahead of the existing hook
      body, `git config --get agenticapps.workflow.enrolled >/dev/null 2>&1 ||
      exit 0`. Against an identical malformed `openspec/` tree: unenrolled exits
      0, enrolled exits 1 and blocks with the gate's own message. Both scenarios
      in the new requirement are therefore demonstrated, not assumed. What
      remains is landing it in the published hook and adding the case to the
      suite — the prototype is evidence, not the implementation
- [ ] 2.8b Amend `init-project.sh` to set the marker, and **amend its header
      contract in the same diff**. It currently promises it writes "exactly two
      things: `openspec/`, and one instruction file ... No skills, no hooks, no
      host configuration." Enrolment is a third write. Restate the contract as
      two files and one local git config key rather than leaving a guarantee the
      script no longer keeps — and bump `init-project-version`
- [ ] 2.8c `--check` SHALL name a repository that carries `openspec/` but is not
      enrolled. Without this the marker degrades into the drifting declared-list
      option that was rejected for exactly that failure
- [ ] 2.9 Preflight before binding: report every repository the new binding will
      newly govern, and require acceptance before `git config --global` is
      written. The census in `design.md` covers `~/Sourcecode` only, and the
      binding's reach is the whole machine — so the evidence gathered is
      narrower than the act performed

## 3. Retire the per-repository copies

- [ ] 3.1 Remove the gate `pre-commit` from each of the repositories carrying
      one, having confirmed the global binding is live first
- [ ] 3.2 `tools/install-core-git-hooks.sh` — **superseded. Decided 2026-08-07,
      recorded as design Decision 4.** It resolves its destination with
      `git rev-parse --git-path hooks` (line 54), which honors `core.hooksPath`
      by its own header's admission (line 13), so once the binding is global,
      running it from `install.sh` writes into the machine-level directory —
      either refusing permanently on a foreign marker, or colliding markers and
      publishing core's working-tree-resolving hook to every repository.
      `install.sh` therefore **stops calling it**: the floor binder takes its
      `COREHOOKS` variable (line 26) and its call site (lines 345–346), one for
      one. The script is not deleted — it survives as core's own tool, and the
      refusal added in the `core-self-enforcement` delta covers a by-hand run on
      a bound machine, which becomes the only way to reach it
- [ ] 3.3 Core's own binding: ADR-0028 has core resolve its *working-tree* gate,
      and `core-self-enforcement` says the shared install "SHALL NOT be
      consulted" — which a machine-level published hook cannot satisfy. Resolve
      explicitly — an ADR if the inversion is being changed, a documented
      local `core.hooksPath` override if it is being kept. **Decided in the
      `core-self-enforcement` delta: the inversion is kept, and core sets a
      local `core.hooksPath` that git prefers over the global binding.** The
      installer gains a refusal when the resolver returns the machine-level
      directory, and core's binding is declared so the sweep cannot remove it
- [ ] 3.4 Declare core's local binding wherever the sweep reads its exclusions,
      and confirm `--check` reports an undeclared core binding as at risk
- [ ] 3.5 **Name what establishes core's local binding — the gap task 3.2 opens.**
      `install.sh` was setting core's `pre-commit` as a side effect of calling
      `install-core-git-hooks.sh` on every run; superseding that call removes the
      only thing that did it. `core-self-enforcement` requires core to carry a
      local `core.hooksPath` and makes its absence a CI failure, so the gap is
      loud rather than silent — but it is unowned. Decide the owner: core's own
      bootstrap, `init-project.sh` run against core, or a documented one-off. Do
      **not** answer it by putting the call back into `install.sh`, which is the
      category error Decision 4 removed.
      **Name a specific artifact — a reviewer pushed back on leaving it open**,
      and correctly: "CI detects its absence" is a detector, not an establisher,
      and a requirement whose subject is unnamed is a requirement nobody owns

## 3b. Sweep the redundant local bindings

Six repositories set a local `core.hooksPath`, which git prefers over the global
one, so the new floor reaches none of them. Five name the directory git would
resolve anyway, so unsetting them changes nothing today and restores reach.

- [ ] 3b.1 Unset the local `core.hooksPath` in `claude-workflow`, `callbot`,
      `fx-signal-agent` and `agenticapps-dashboard` — **four configs, four
      bindings**. This previously read "four configs, five bindings, since the
      dashboard's linked worktree shares its config"; that worktree was removed
      on 2026-08-07, so the shared-config case no longer exists
- [x] 3b.2 Confirm each named its own default hooks directory before unsetting,
      so the sweep is provably a no-op rather than assumed to be one.
      **Done 2026-08-07**, and the obvious check would have been circular:
      `git rev-parse --git-path hooks` *honours* `core.hooksPath`, so resolving
      it while the binding is set proves only that the binding is set. The
      comparison is therefore against `--git-common-dir`, which does not honour
      it. All five swept bindings equal `<common-dir>/hooks` exactly, so the
      sweep is a proven no-op. `fbc-platform` is the only one that differs
- [ ] 3b.3 Leave `fbc-platform`'s `.husky/_` binding untouched. It is a genuine
      opt-out protecting a real husky installation, and the change records it as
      such rather than treating it as drift
- [ ] 3b.4 Confirm after the sweep that the global binding governs each swept
      repository, by resolving its hooks directory rather than by inference
- [ ] 3b.5 **Define the sweep's discovery and authorization boundary.** The
      requirements read as a general sweep while 3b.1 hard-codes four named
      repositories, so nothing states what set is walked, who authorises writing
      to another repository's config, what happens on partial failure, or
      whether a dry-run exists. A sweep that mutates git configuration outside
      the repository it runs in needs all four stated before it runs, not after.
      Raised by a reviewer

## 4. Drop `--project`

- [ ] 4.1 Remove `--project` from the deferred-scope notes it appears in
- [ ] 4.1a If `--project` being unsupported is meant to be durable behaviour,
      give it a normative scenario and a test that passing it is rejected
      without writes. Prose in `design.md` is not enforceable and does not
      survive archiving as truth. Raised by a reviewer
- [ ] 4.2 Record in `core-installer-one-entry-point`'s archived design that its
      Phase 5b sequencing constraint is released, and why
- [ ] 4.3 Confirm Phase 5b has no remaining blockers: `--project` is dropped
      here, and the codex adapter and opencode plugin went with the
      predecessor's narrowing

## 5. Check mode

- [ ] 5.1 `--check` reports whether `core.hooksPath` is set and whether it
      resolves to the published directory
- [ ] 5.2 `--check` reports the published `pre-commit`'s currency by content
- [ ] 5.3 `--check` names the active enforcement surfaces
- [ ] 5.4 `--check` reports a repository whose own hooks are displaced by the
      global binding
- [ ] 5.5 `--check` reports the **effective** binding for the repository it runs
      in, not the global one. A local `core.hooksPath` wins, so reporting the
      global binding as active is wrong in six repositories today
- [ ] 5.6 `--check` names any repository the floor cannot reach, so an accidental
      opt-out is visible rather than inferred
- [ ] 5.7 `--check` reports a **dangling** binding — `core.hooksPath` set to a
      directory that no longer exists. **This task had the consequence
      backwards and is corrected 2026-08-07.** It said a dangling binding
      "fails `git commit` machine-wide"; retested independently on git 2.50.1
      with the setting pointing at an absent directory, the commit **succeeds,
      exit 0, and nothing is reported**. So a dangling binding does not announce
      itself — it silently ungates every repository it governs, which is the
      more dangerous outcome and the reason `--check` must cover it. The
      currency checks cover drift in a hook that is present; none covers the
      target being absent

## 6. Tests (TDD — RED before GREEN on every one)

- [ ] 6.1 A bare run binds `core.hooksPath` and publishes the hook
- [ ] 6.2 A foreign `core.hooksPath` is reported, left unchanged, and the run
      exits non-zero
- [ ] 6.3 An already-correct binding is reported satisfied and rewrites nothing
- [ ] 6.4 `--host claude` creates and modifies no file under `~/.claude` other
      than a skill symlink — the negative test for the whole change
- [ ] 6.5 A commit in a repository with no local hook is gated by the global one
- [ ] 6.6 A repository with its own local `core.hooksPath` is not governed by the
      global binding
- [ ] 6.7 `--accept-host-config` still exits 64 — inherited, and re-asserted
      here because a floor change that quietly reintroduced a config write is
      exactly what this suite should catch
- [ ] 6.8 Every case runs against a per-case `HOME` **and a per-case git config**;
      a test that sets a global `core.hooksPath` against the real home would
      rebind the operator's machine
- [ ] 6.9 The dispatcher runs `hooks.d` entries and fails on the first non-zero
- [ ] 6.9a `hooks.d` **itself** being a symlink is covered, not only its entries.
      Checking entry symlinks alone does not establish that the directory is
      operator-owned — repointing `hooks.d` redirects every entry at once. Assert
      ownership and permissions so another local user cannot install code that
      runs on every commit. Raised by a reviewer as MEDIUM/SECURITY
- [ ] 6.10 The dispatcher does not exec a repository's `.git/hooks/pre-commit`
      even when one is present — the negative test for task 2.7
- [ ] 6.11 A repository whose local `core.hooksPath` names its own default
      directory is swept, and is governed by the global binding afterwards
- [ ] 6.12 A repository with a genuine foreign local binding, husky-shaped, is
      left alone by the sweep
- [ ] 6.13 A dangling `core.hooksPath` is reported by `--check`. The test SHALL
      also assert that a commit under a dangling binding **succeeds silently**,
      because that is the verified behaviour and the whole reason `--check` is
      the only surface that can catch it — "discovered at the next commit" is
      not a fallback that exists

## 7. Evidence

- [ ] 7.1 Installer line count, before and after, with the delta explained
- [ ] 7.2 Host-named code in the repository, before and after. **The expected
      after-state is not `HOSTS` and `--check` only** — task 1.2 measured three
      inherited sites that fall outside both (`ARCHIVED`, `neutral_of()`'s
      prefix stripping, and its hard-coded `~/.claude/skills`). Either record
      them as accepted inherited exceptions with the reason, or open a separate
      change to remove them. Do **not** quietly restate the old expectation and
      report a pass against it
- [ ] 7.3 `--check` output before and after, as the restore reference
- [ ] 7.4 A real commit gated through the global binding, with the gate's output

## 8. Close

- [ ] 8.1 `openspec validate --all` green
- [x] 8.2 `run-plan-review.sh one-enforcement-floor --implementing-host claude`
      — ran 2026-08-07. gemini, codex and opencode counted, all REQUEST-CHANGES,
      claude excluded as implementing host. `REVIEWS.md` carries the findings
      and the resolution
- [x] 8.2b **Re-review after this repair — ran 2026-08-07.** gemini APPROVE,
      codex REQUEST-CHANGES with 10 findings, opencode timed out at 180s and was
      not counted, claude excluded as implementing host. Two counted, meeting the
      floor. Disposition — three findings were verified empirically rather than
      accepted on assertion:

      | Finding | Disposition |
      |---|---|
      | MODIFIED requirements drop scenarios | **Confirmed, fixed.** Three scenarios were absent from the delta — `No host is installed on the machine`, `The budget cannot be met`, `The mandatory behaviour alone exceeds the budget`. `openspec instructions` states MODIFIED must carry the entire block and names this exact failure. Restored |
      | `core-self-enforcement` self-contradiction | **Confirmed, fixed.** The "outside the working tree" scenario is narrowed to *inside the git common directory*, matching the prose predicate |
      | `tasks.md` 5.7 contradicts the delta on dangling bindings | **Confirmed, fixed.** Retested on git 2.50.1: a commit under a dangling `core.hooksPath` succeeds, exit 0, silently. 5.7 and 6.13 corrected; the delta was already right |
      | Machine-wide blast radius | **Confirmed and worse than stated** — see 2.8. A repo containing any `openspec/` tree that fails validate has commits blocked without opting in. Measured |
      | Unspecified behaviour in non-workflow repos | Same measurement; 2.8 and 2.9 |
      | Sweep has no discovery/authorization boundary | Accepted → 3b.5 |
      | Core's binding has no owner | Accepted → 3.5 strengthened to demand a named artifact |
      | `hooks.d` ownership beyond entry symlinks | Accepted → 6.9a |
      | `--project` removal is prose-only | Accepted → 4.1a |
      | Repository names / absolute paths in reports | **Declined, with reason.** These artifacts are repo-local planning documents already committed to this repository, and the paths are the operator's own. Redacting them would remove the evidence that makes the measurements checkable, which is this change's stated virtue. Revisit only if `--check` output is ever emitted into CI logs |
- [x] 8.2c `core-self-enforcement` spec delta written 2026-08-07 —
      `specs/core-self-enforcement/spec.md`. Two MODIFIED requirements (core
      resolves its own reference implementation; the pre-commit installer
      resolves the real hooks directory) and one ADDED (core's binding is
      declared and the sweep does not remove it). `openspec validate
      one-enforcement-floor --strict` green
- [ ] 8.3 Stage-2 code review on the diff, in an independent context
- [ ] 8.4 ADR for the enforcement-surface decision; it changes what the workflow
      guarantees locally and that belongs in a decision record, not only in a
      change that gets archived
- [ ] 8.5 Update `docs/HOW-IT-FITS-TOGETHER.md` — its hooks section and its open
      questions both become wrong the moment this lands
