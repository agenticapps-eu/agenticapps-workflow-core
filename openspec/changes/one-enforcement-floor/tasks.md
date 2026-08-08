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
- [x] 0.3a **Classify the nine, because they are not nine candidates.**
      Re-measured 2026-08-07 resolving each hooks directory rather than assuming
      `.git/hooks`. 0.3 counted the copies correctly and never asked what they
      were:

      | Repository | Bytes | Disposition |
      |---|---|---|
      | `agenticapps-workflow-core` | 1376 | core itself — local binding, 3.3/3.5 |
      | `claude-workflow` | 1201 | archived, deleted wholesale by Phase 5b |
      | `codex-workflow` | 5844 | archived, deleted wholesale by Phase 5b |
      | `opencode-workflow` | 2270 | archived, deleted wholesale by Phase 5b |
      | ~~`agenticapps-dashboard`~~ | 5844 | **gone — checkout deleted 2026-08-08** |
      | ~~`agenticapps-roadmap`~~ | 1201 | **gone — checkout deleted 2026-08-08** |
      | `agents-task-viewer` | 1201 | **live — migration set** |
      | `callbot` | 1201 | **live — migration set** |
      | `fx-signal-agent` | 1201 | **live — migration set** |

      **The migration set is three.** The exclusions follow the precedent
      `fleet-carries-only-current` already set — "cleaning a repository
      scheduled for deletion" is out of scope — and core is excluded because it
      keeps a local binding by ADR-0028. `fbc-platform` carries husky, not the
      gate.
      **Superseded again the same day: both retired checkouts were deleted from
      the machine on 2026-08-08.** Re-measured after the deletion — **seven**
      gate copies remain, not nine, and the two that left were the two largest
      dispositions to reason about. The migration set is unchanged at three,
      because neither was in it.

      `agenticapps-roadmap`'s retirement **was** recorded, and the first census
      looked in the wrong place for it. Not in the family instruction file, not
      in the repo's ADRs — **on GitHub, as the archived flag**, set 2026-08-05,
      the same day as the dashboard's. The census read local disk and never
      asked the forge, so it reported a repository as live while its own remote
      had been read-only for three days. Corrected: the retirement date is
      **2026-08-05**, not the 08-08 an earlier revision of this task recorded —
      08-08 is when it surfaced here, which is not the same fact.
      This is worth more than the correction. A local checkout carries no field
      that says "retired", so any census built only on what is on disk will keep
      making this mistake. `archived` on the remote is the machine-readable
      record, it is one API call, and 0.3b now covers asking it
      Note the **five** byte-identical 1201-byte copies, spanning an archived
      checkout, a retired one and all three live repositories. That is what
      Decision 4's category error looks like from the outside: `install.sh`
      wrote a hook into whichever repository the shell was sitting in, so this
      population mixes deliberate adoption with drive-by installs and nothing on
      disk separates them. It is the evidence for Decision 5 refusing to
      translate the hook into a marker unasked
- [ ] 0.3b **A census SHALL ask the forge whether a repository is archived, not
      only the disk.** Rewritten 2026-08-08 after the original version of this
      task — "record roadmap's retirement in the family instruction file" —
      turned out to be solving the wrong problem: the retirement *was* recorded,
      as GitHub's `archived` flag, set 2026-08-05. A checkout carries no field
      that says "retired", so a disk-only census reports a repository as live
      while its remote has been read-only for days. `gh api repos/<owner>/<name>
      --jq .archived` is one call per repository.
      Still worth doing separately: the family instruction file's retired-repos
      section lists only `agenticapps-dashboard`. **Outside this repository, so
      it is the operator's call** — noted so it is not lost, not claimed as scope
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
      case is gone. Section 3b is simpler by exactly one row.

      **Superseded again 2026-08-08 and re-measured, not inferred: four
      bindings.** The dashboard's checkout was deleted, taking its config with
      it. What remains is `claude-workflow`, `callbot`, `fbc-platform`
      (`.husky/_`, the genuine opt-out) and `fx-signal-agent`.
      Of those, **`claude-workflow` is a host repository scheduled for deletion
      at the end of the plan**, so the sweep leaves it alone: unsetting a binding
      in a directory that is going to be removed is work that returns nothing.
      The sweep's real subject is therefore **two** repositories

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
      predates this change.

      **Resolved 2026-08-07: accepted as recorded exceptions, no separate
      change.** Two reasons, in order of weight.

      First, **this task was testing a stricter claim than any spec makes.** The
      durable requirement is "One command installs the workflow, and it names no
      host", and its body is about the operator's interface — "installable by a
      single command that requires no host argument", "an operator who has never
      heard of the five hosts SHALL still get a working install". It says nothing
      about host names appearing in the source. All three sites satisfy the
      requirement as written: a bare run still takes no host argument and still
      names no host to the operator. The phrase "no host-named code outside
      `HOSTS` and `--check` strings" is this task's own gloss, and it is a
      tighter bar than the specification sets.

      Second, **they are transitional and already scheduled for deletion.**
      `ARCHIVED` names archived *checkouts*, not hosts, and `neutral_of()` exists
      only to map the archived host installers' vendored skills back to neutral
      ones. `fleet-carries-only-current` records those checkouts as deleted
      wholesale by Phase 5b, at which point `ARCHIVED`, `is_archived`,
      `neutral_of` and `sweep_vendored` are all dead code. Removing them now
      would delete the machinery that performs the conversion before the
      conversion has run

## 2. Publish and bind the global floor

- [x] 2.1 Publish the gate's `pre-commit` to the machine-level hooks directory
      through the arbitrating installer, with a version marker, exactly as the
      other three executables are published. **Built 2026-08-07** —
      `reference-implementations/global-floor/bind-global-floor.sh`, published to
      `~/.agenticapps/git-hooks/` under the `global-floor-version` key. Delegation
      is asserted by a recorder standing in for the helper, not inferred from the
      destination bytes: no assertion about the published file can tell a correct
      delegation from a `cp` that produced the same bytes, and a `cp` would
      silently overwrite a newer published hook
- [x] 2.1a **The published directory already holds a foreign file on this
      machine, and the binder overwrites it without saying so.** Measured
      2026-08-07: `~/.agenticapps/git-hooks/pre-commit` exists, dated 25 Jul,
      2270 bytes — it is **opencode's host-local variant**, not core's
      dispatcher, published by the archived opencode installer and never bound
      (no global `core.hooksPath` exists, per 0.4). Probed against a copy rather
      than the real file: it carries no `global-floor-version` marker, the
      arbitrating helper therefore reads it as `0.0.0` and installs over it,
      exit 0, reporting only `(was 0.0.0)`.
      **This is an asymmetry worth naming rather than a defect to fix here.**
      `install-core-git-hooks.sh` *refuses* a hook it does not own; the floor
      binder *overwrites* one, because the helper's ownership model is version
      markers and an unmarked file is the oldest possible version. The binding
      is protected — 2.3 — and the file in the directory is not. Feed this into
      2.9's preflight: what publishing will replace belongs in the same report
      as what the binding will newly govern
- [x] 2.1b **The published directory needed the same guard the dispatcher gives
      `hooks.d`, and did not have it.** Found by the §gate `cso` pass on this
      diff, not by review. The dispatcher refuses a symlinked or
      group/world-writable `hooks.d`; it cannot make that check about the
      directory it lives in, because by the time it runs anyone who could write
      there has already replaced it. Measured: `mkdir -p` over an existing
      symlink succeeds silently, and the run then published the dispatcher into
      the link's target **and bound `core.hooksPath` to it** — the machine's
      commit-time hook directory handed to whoever owned that target. Guard
      added ahead of publishing, symlink checked before `mkdir`, two cases in
      the suite.
      **Recorded honestly: this requirement was written after the code.** That
      is the wrong order and it is the red flag the workflow names. The
      alternative was dropping a demonstrated local-privilege hazard because it
      arrived at the wrong step, which is worse. It is a fresh requirement in
      the delta that no reviewer has seen — see open question 7
- [x] 2.2 Bind it with `git config --global core.hooksPath <dir>`. **Built and
      tested 2026-08-07**, publish first and bind second, with the interrupted
      run completing on re-run rather than starting over. **Not yet run for real
      on this machine** — that waits on 2.8c and 2.9, per the note below
- [x] 2.3 Refuse and report a foreign existing `core.hooksPath`; the step counts
      as skipped so the run exits non-zero. **Built.** The report names both the
      existing value and the value it would have set, and points at `hooks.d` as
      the supported way to compose — a refusal that does not say what to do
      instead is a refusal an operator routes around
- [x] 2.4 Report an existing binding that is already ours as satisfied, not as
      a no-op and not as a fresh install. **Built.** Compared by raw string
      first and physical path second: on macOS a home directory reached through
      a symlink spells the same directory two ways, and a binder that read its
      own binding as foreign would refuse permanently
- [x] 2.5 The published hook dispatches to the gate and propagates its exit
      status. **Built 2026-08-07** —
      `reference-implementations/global-floor/pre-commit`. Status is propagated
      **verbatim**, not collapsed to 1: the gate distinguishes its failure modes
      by status and flattening them discards the only machine-readable thing it
      produces. Fails open with a warning when the gate is absent, per §18
- [x] 2.6 The dispatcher composes with an operator-owned, machine-level
      `hooks.d` alongside the published directory, running each entry and
      failing the commit on the first non-zero exit. **Built.** `hooks.d` is a
      subdirectory of the published hooks directory, which git ignores because
      it only execs files named for a hook. Entries run in lexical order;
      non-executables, directories and debris are skipped; the first non-zero
      stops the rest, because a later entry running after an earlier refusal
      would act on the state the refusal existed to prevent
- [x] 2.7 The dispatcher SHALL NOT exec anything resolved from inside a
      repository — not `.git/hooks/`, not a tracked path. A global hook that
      falls back to repository-controlled code makes every clone executable at
      commit time, which is the property `core.hooksPath` exists to remove.
      Assert it as a negative test, not a convention. **Built, with two negative
      tests.** The concrete difference from the per-repository hook is the
      *absence* of its `[ -x "$GATE" ] || GATE="$(git rev-parse
      --show-toplevel)/bin/openspec-change-gate.sh"` fallback — that branch is
      correct for a hook a repository installs for itself and forbidden for one
      bound machine-wide
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
- [x] 2.8a Implement the predicate in the published hook, ahead of the gate call,
      with the negative test: a repository carrying a malformed `openspec/` tree
      and **no** marker commits successfully.
      **Prototyped and proven 2026-08-07** — one line ahead of the existing hook
      body, `git config --get agenticapps.workflow.enrolled >/dev/null 2>&1 ||
      exit 0`. Against an identical malformed `openspec/` tree: unenrolled exits
      0, enrolled exits 1 and blocks with the gate's own message. Both scenarios
      in the new requirement are therefore demonstrated, not assumed. What
      remains is landing it in the published hook and adding the case to the
      suite — the prototype is evidence, not the implementation
- [x] 2.8b Amend `init-project.sh` to set the marker, and **amend its header
      contract in the same diff**. It currently promises it writes "exactly two
      things: `openspec/`, and one instruction file ... No skills, no hooks, no
      host configuration." Enrolment is a third write. Restate the contract as
      two files and one local git config key rather than leaving a guarantee the
      script no longer keeps — and bump `init-project-version`
- [ ] 2.8c `--check` SHALL name a repository that carries `openspec/` but is not
      enrolled. Without this the marker degrades into the drifting declared-list
      option that was rejected for exactly that failure
- [x] 2.9 Preflight before binding: report every repository the new binding will
      newly govern, and require acceptance before `git config --global` is
      written. The census in `design.md` covers `~/Sourcecode` only, and the
      binding's reach is the whole machine — so the evidence gathered is
      narrower than the act performed.
      **Built 2026-08-08 with 9.4a, and Decision 7 changed what it reports.**
      Not "every repository the binding will newly govern" — that is the impact
      set, it includes everything `init-project.sh` enrolled earlier, and
      enumerating it needs the search Decision 7 removed. The preflight reports
      the MUTATION set, says in one line that it is not the impact set, and
      points at `--check` for the rest. A run with no names has an empty
      mutation set and asks nothing: an acceptance covering nothing is a prompt
      nobody can answer, and it would block every unattended install

## 3. Retire the per-repository copies

- [ ] 3.1 Remove the gate `pre-commit` from each repository in the **migration
      set**, and only after that repository is enrolled and the global binding
      is verified to govern it by resolving its hooks directory.
      **Rewritten 2026-08-07 by Decision 5** — it previously read "remove from
      each of the repositories carrying one, having confirmed the global binding
      is live first", which composed with the enrolment predicate to take every
      repository gated today from gated to silently ungated. "The binding is
      live" is a fact about the machine; "the binding governs this repository"
      is a fact about the repository, and a local `core.hooksPath` makes them
      different facts in five repositories today.
      **The migration set is three, not nine** — see the corrected population in
      0.3a. Archived and retired checkouts are excluded and reported as excluded
- [x] 3.2 `tools/install-core-git-hooks.sh` — **superseded. Decided 2026-08-07,
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
      a bound machine, which becomes the only way to reach it.
      **Landed 2026-08-07 and the swap was line-for-line as predicted.**
      `install.sh` is at **217** before and after — the budget assertion is
      `-le 217` and would have failed immediately otherwise. One departure from
      the old call site, deliberate: the `>/dev/null 2>&1` is gone, because the
      binder's foreign-binding report names the existing value and the value it
      would have set, and discarding its output would throw away the only
      surface that says either. Two test cases changed shape rather than
      wording — "a foreign pre-commit hook is refused" now asserts a foreign
      *global* `core.hooksPath`, since the machine installer no longer writes a
      per-repository hook and the old assertion would have passed because
      nothing happened rather than because something was refused
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
resolve anyway. **The sweep is how those five come under the floor** — the unset
is the mechanism, not a tidy-up beside it. It changes nothing only while no
global binding exists, which is the state it was measured in.

- [ ] 3b.1 Unset the local `core.hooksPath` in `callbot` and `fx-signal-agent`
      — **two configs, two bindings**, re-measured 2026-08-08. This is the act
      that brings both under the floor: while their local binding stands, the
      global one does not reach them, so the unset is what the floor's coverage
      of these two consists of.
      This has now been wrong twice in two days, in the same direction each
      time, which is the argument for 1.1-style re-measurement rather than a
      list maintained by hand. It read "four configs, five bindings" while the
      dashboard's linked worktree shared its config; that worktree went on
      2026-08-07, making it four and four. Then the dashboard's checkout itself
      went on 2026-08-08, and `claude-workflow` was excluded as a host
      repository scheduled for deletion — unsetting a binding in a directory
      that is about to be removed returns nothing
- [x] 3b.2 Confirm each named its own default hooks directory before unsetting,
      so the sweep is provably **redundant as a setting** rather than assumed to
      be. **Done 2026-08-07**, and the obvious check would have been circular:
      `git rev-parse --git-path hooks` *honours* `core.hooksPath`, so resolving
      it while the binding is set proves only that the binding is set. The
      comparison is therefore against `--git-common-dir`, which does not honour
      it. All five swept bindings equal `<common-dir>/hooks` exactly.
      `fbc-platform` is the only one that differs.
      **The measurement stands; the conclusion drawn from it does not.** It read
      "so the sweep is a proven no-op", and unsetting a redundant binding is a
      no-op only *while no global binding exists* — the state it was measured
      in, and still the state of this machine today. The instant the floor is
      bound, those same unsets are what hand five repositories to it. That is
      the intent and it is the opposite of a no-op. The correction is not
      cosmetic: "provably a no-op" was the argument that made writing to another
      repository's git config feel safe enough to need no authorization
      boundary, which is 3b.5 arrived at from the other side (Decision 6)
- [ ] 3b.3 Leave `fbc-platform`'s `.husky/_` binding untouched. It is a genuine
      opt-out protecting a real husky installation, and the change records it as
      such rather than treating it as drift
- [ ] 3b.4 Confirm after the sweep that the global binding governs each swept
      repository, by resolving its hooks directory rather than by inference
- [x] 3b.5 **Define the sweep's discovery and authorization boundary.** The
      requirements read as a general sweep while 3b.1 hard-codes four named
      repositories, so nothing states what set is walked, who authorises writing
      to another repository's config, what happens on partial failure, or
      whether a dry-run exists. A sweep that mutates git configuration outside
      the repository it runs in needs all four stated before it runs, not after.
      Raised by a reviewer.
      **Closed 2026-08-08 as Decision 7.** All four answered in the delta, and
      3b.1's hard-coded four stop being an embarrassment to explain away: naming
      the set *is* the boundary, so the hard-coding was the right shape wearing
      the wrong justification. The sweep does not walk anything, the operator
      authorises by naming a repository and accepting one preflight that reports
      every act first, and a repository that fails keeps its hook and is
      reported while the run continues and exits non-zero

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
- [x] 6.9 The dispatcher runs `hooks.d` entries and fails on the first non-zero
      — **done**, plus lexical ordering, debris skipping and an absent `hooks.d`
- [x] 6.9a `hooks.d` **itself** being a symlink is covered, not only its entries.
      Checking entry symlinks alone does not establish that the directory is
      operator-owned — repointing `hooks.d` redirects every entry at once. Assert
      ownership and permissions so another local user cannot install code that
      runs on every commit. Raised by a reviewer as MEDIUM/SECURITY.
      **Done** — refuses a symlinked `hooks.d`, one not owned by the caller, and
      one that is group- or world-writable, all checked before any entry runs
- [x] 6.10 The dispatcher does not exec a repository's `.git/hooks/pre-commit`
      even when one is present — the negative test for task 2.7. **Done**, and a
      second case covers the sharper form: with the machine gate *removed* and a
      repository-supplied `bin/openspec-change-gate.sh` present, the dispatcher
      fails open rather than resolving into the repository
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
- [ ] 7.2 Host-named code in the repository, before and after. **Measure against
      the requirement, not against the old gloss.** The bar is "a bare run takes
      no host argument and names no host to the operator", which is what
      `workflow-installation` actually requires. The three inherited sites task
      1.2 found (`ARCHIVED`, `neutral_of()`'s prefix stripping, its hard-coded
      `~/.claude/skills`) are accepted exceptions and SHALL be listed by name in
      the evidence, with Phase 5b named as their deletion trigger. What this task
      catches is a **new** site introduced by this change — the count of accepted
      exceptions must not grow from three
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

## 9. From the second plan-review round (2026-08-07)

`REVIEWS.md` round two: gemini APPROVE, codex REQUEST-CHANGES ×7, opencode
REQUEST-CHANGES ×8. **opencode completed this time** — the 180s default was the
whole reason it timed out last round; 420s was enough, so the standing "raise
`REVIEW_TIMEOUT` for a third opinion" question is closed and three vendors are
now on the record.

Three findings were **verified empirically and fixed in the same session**, all
three in the guards this change exists to be. They are recorded against the
tasks that had already been ticked, because each of those ticks was wrong:

- [x] 9.1 **2.8a's predicate read the wrong scope, and ignored the value.**
      `git config --get` resolves across system, global and local, so one
      `git config --global agenticapps.workflow.enrolled true` enrolled every
      repository on the machine — the measured defect the predicate was built to
      remove, reintroduced machine-wide by the predicate itself. It also exits 0
      for any value, so `false` enrolled. Both reproduced in a sandbox before
      being written up. Now `--local --type=bool` with an explicit comparison,
      three new cases. Raised independently by codex and opencode
- [x] 9.2 **2.7's prohibition was defeated by a single symlink, and the suite
      did not notice.** The dispatcher checked whether `hooks.d` *itself* was a
      symlink and never resolved its *entries*, so a link from `hooks.d` into a
      clone re-enabled repository-controlled execution at commit time while
      every other case in the suite still passed. Demonstrated end to end — the
      linked script ran, the hook exited 0 — then fixed and re-run against the
      same fixture. Entries now resolve canonically, on the target rather than
      the link text, and must land inside `hooks.d`. Task 2.7 was marked done
      last session "with two negative tests"; the spec had required this all
      along and said exactly why. `global-floor-version` 1.0.0 → 1.1.0
- [x] 9.3 A link whose target stays *inside* `hooks.d` still runs, asserted as a
      regression guard so 9.2's fix does not push operators toward copies that
      silently drift

**Not fixed here, and each needs a decision rather than a patch.** Listed
highest-consequence first:

- [x] 9.4 **Nothing enrols the repositories that are gated today.** Raised by
      codex and opencode independently, and it was the largest hole in the
      change. §3 removes the per-repository gate copies; the published hook
      exits 0 without the marker; 2.8b only covers `init-project.sh` for *future*
      projects. Composed, those three took every repository gated today from
      gated to **silently ungated at install time**.
      **Decided 2026-08-07 as design Decision 5**, with a normative requirement
      — "No repository is left with neither surface" — and five scenarios, so it
      survives archival rather than living only in prose. The migration enrols
      first, verifies the binding governs the repository by **resolving its
      hooks directory** rather than inferring from global config, and only then
      removes the local hook; anything failing leaves the hook in place and is
      reported. Rejected translating the existing hook into a marker unasked:
      `install.sh` wrote hooks into whichever repository the shell was sitting
      in, so the population mixes deliberate adoption with drive-by installs and
      nothing on disk separates them.
      Two corrections fell out of it: **the migration set is three, not nine**
      (0.3a), and 3.1's "having confirmed the global binding is live" was the
      wrong predicate — that is a fact about the machine, and what matters is a
      fact about the repository
- [x] 9.4a Implement it: fold the migration report into 2.9's preflight rather
      than building a second acceptance. What the binding will newly govern,
      what publishing will replace (2.1a) and what will be enrolled are one
      report and one acceptance, not three that have to agree.
      **Unblocked 2026-08-08 by Decision 7, which had to come first.** The
      migration writes git config and deletes hooks in *other* repositories, and
      9.10/3b.5 require that boundary stated before such a thing runs, not
      after — so implementing this first would have built exactly what the open
      finding forbids. The delta now carries "The migration acts only on
      repositories the operator names" with five scenarios.
      **Built 2026-08-08**, in `bind-global-floor.sh`, with 9.4b–9.4h in the
      same diff because each of them says what this code owes rather than
      naming separate work. The named set is POSITIONAL ARGUMENTS and
      `install.sh` passes none, which is what makes "acts only on repositories
      the operator names" true of the unattended path by construction rather
      than by a flag defaulting correctly. One preflight prints the publish, the
      binding and every act on every named repository, under one acceptance
      (`GLOBAL_FLOOR_ACCEPT_PLAN`, or `y` on a tty); declining publishes
      nothing, binds nothing and touches no repository. 28 cases in
      `tools/global-floor-bind.test.sh`, 76 in the suite
- [x] 9.4c **The census corrected the per-repository ordering, so the code owes a
      sweep step the tasks did not have.** Measured 2026-08-08 across all 61
      repositories under `~/Sourcecode`: `callbot` and `fx-signal-agent` each
      carry a local `core.hooksPath` naming their own default hooks directory,
      so git prefers it and the global binding does not govern them. Two of the
      three in the migration set therefore fail 3.1's verification step unless
      the redundant binding is swept first. The order is sweep → enrol → verify
      → remove, and §3b's sweep is a step *inside* the migration rather than a
      pass running beside it. Second time in this change that treating the sweep
      as cosmetic produced a wrong ordering; Decision 6 caught the first.
      **Corrected the same day by the plan review, before any code**: the order
      above is wrong and the right one is **enrol → sweep → verify → remove**.
      gemini and codex found it independently. Sweeping an unenrolled repository
      hands it to a dispatcher that exits 0 for want of the marker, so the gap
      between sweep and enrolment is a window with a hook file, a global binding
      and no enforcement — the very state this section forbids, reached through
      the binding rather than through the file. Enrolment is inert until the
      sweep, because the local hook predates the predicate and never reads it,
      so enrolling first costs nothing and closes the window.
      **Built in that order 2026-08-08**, and the order is asserted rather than
      the end state: the two orders leave the same disk and a different set of
      survivable interruptions, so a suite checking only the end state passes
      under both
- [x] 9.4b The interruption scenario needs a test that actually interrupts —
      kill the migration between two repositories and assert the invariant holds
      across the boundary, rather than asserting each repository in isolation
      and calling the composition proven.
      **Widened 2026-08-08 by the plan review**: between repositories is the
      easy boundary and not the dangerous one. Both reviewers located the real
      hazard *inside* a repository, so the interruption test SHALL cut after
      each of enrol, sweep and verify, not only between repositories.
      **Done 2026-08-08, and it interrupts for real.** A test-only seam in the
      binder was rejected — a production script carrying a branch that exists
      only for its tests has a branch that can be wrong in production — so the
      cut comes from outside: a `git` earlier on PATH passes the call through
      and then kills the process group. By GROUP and not by `$PPID`, because
      bash may fork an intermediate subshell for `x="$(git ...)"` and killing
      that one lets the binder continue with an empty value, which would pass
      the suite while proving nothing. Three cuts, one per step — **five as of
      the stage-2 correction in 9.4d**, because the global binding is an
      interruption point too, and for a repository with no local binding it is
      the only one that displaces its hook
- [x] 9.4d **Ordering, from the plan review — RED before GREEN.** The order is
      enrol → sweep → verify → remove. The test that matters asserts the
      negative: with the binder stopped immediately after the sweep, a commit in
      that repository is still gated. Under the rejected sweep-first order that
      commit succeeds, so the case fails before the fix and passes after it,
      which is the only thing that makes it a regression guard rather than a
      description.
      **Demonstrated both ways 2026-08-08.** Against a variant of the binder
      with the sweep moved ahead of the enrolment, exactly three cases fail and
      the one that matters fails on the commit: swept, unenrolled, and gated by
      nothing. Against the shipped order all 76 pass.
      **Corrected 2026-08-08 by the stage-2 review, and this is the second time
      the same window was closed against the wrong displacer.** All three cuts
      were taken against a repository whose local `core.hooksPath` is what
      displaces its hook — so all three were blind to the repository that has
      none, which is the shape `tools/install-core-git-hooks.sh` actually leaves
      behind and the shape one of the three measured repositories is in. For
      that repository the sweep is not the displacer: setting `core.hooksPath`
      globally stops `.git/hooks/` being consulted everywhere at once, and
      enrolling inside the per-repository loop reopened the window one step
      earlier and for every named repository together. Reproduced before the
      fix — cut at the binding, the commit succeeded with the gate hook still on
      disk. The enrolment now runs as its own pass immediately before the global
      binding and after every refusal, so a run that refuses still writes
      nothing into a named repository. Three cases added; two of them fail
      against the previous binder and pass against this one. 79 pass
- [x] 9.4e **Restore the swept binding when verification fails.** A repository
      enrolled and swept whose hooks directory then does not resolve to the
      floor is returned to the surface it had, rather than left holding a hook
      git no longer consults.
      **Built and tested 2026-08-08.** The enrolment is deliberately NOT rolled
      back with the binding: it is inert while the local binding stands, so
      unwinding it would be undoing something that is doing nothing. Forced at
      the point of observation rather than by fixture — on a correctly bound
      machine this state cannot arise, which is how the restore path would
      otherwise go untested until the day it mattered
- [x] 9.4f **Identity, from the plan review.** Canonicalise each name; reject
      without writes anything that is not the top of a repository; deduplicate
      by `--git-common-dir` so a relative path and a symlink to one repository
      are one entry. Cases for each, plus the linked-worktree report: naming one
      checkout modifies configuration every sibling shares, and the preflight
      names them or the "left entirely alone" guarantee is false for a worktree
      nobody mentioned.
      **Built 2026-08-08.** A name that is not the top of a repository stops the
      whole run rather than being skipped: a set that cannot be stated correctly
      cannot be accepted correctly either, and "rejected before any repository
      is modified" reads as the stronger thing. A subdirectory is rejected on
      the same test, because `rev-parse` inside one answers about the repository
      containing it and would migrate a repository nobody named
- [x] 9.4g **Recognise the hook before removing it.** Naming a repository is the
      operator's belief about what is there, never evidence about the file. An
      absent, foreign or unrecognisable `pre-commit` refuses that repository
      without writes. Same shape as 10.7 one level down, and the negative test
      is the one that matters: a repository named by mistake keeps the hook its
      operator wrote.
      **Built 2026-08-08, recognised twice** — once at the preflight and again
      immediately before the delete, because a whole publish and bind separate
      them and the operator accepted the removal of a file that was this
      workflow's gate at the time they read the report.
      **The security pass on this diff found the gap the marker leaves open.**
      Recognition narrows the delete to files this workflow WROTE, which is not
      the same as files inside the repository that was NAMED: a repository
      describes where its own hooks live, so a symlinked hooks directory sends
      the removal elsewhere while the preflight still prints a path inside the
      repository. Unlike a symlinked hook, it is invisible in the report.
      Reproduced before the guard was written — the file outside the repository
      was deleted and the run exited 0. Now refused, with a scenario in the
      delta
- [x] 9.4h **Cases the review found missing outright**: an unnamed repository is
      untouched; a repository enrolled earlier and not named is neither reported
      as newly governed nor modified; declining writes nothing downstream of the
      acceptance; one repository failing leaves the rest processed and the run
      exiting non-zero.
      **All four built and tested 2026-08-08.** The machine is bound even when a
      named repository fails: the failure is local to a repository, and refusing
      to bind a machine because one named path was wrong would be the larger act
      taken for the smaller reason
- [ ] 9.5 **The unwind requirement contradicts its own ordering.** "Publish
      before bind" plus "SHALL unset a binding it created if publishing did not
      complete" — if publishing precedes binding and publishing fails, there is
      no binding to unwind. Confirmed while implementing 2.1: the branch is
      unreachable and the code has no unwind because none is possible. Either
      delete the clause or give it the post-bind failure it was written for
- [x] 9.6 **Binding activates every hook type in the published directory, not
      just `pre-commit`.** codex, MEDIUM/SECURITY, and it generalises 2.1a:
      ownership and permissions establish who wrote a file, never that the
      operator intended it to run fleet-wide. `~/.agenticapps/git-hooks/` on
      this machine already holds a file nobody bound. Inventory and require
      consent, or refuse unexpected entries before binding.
      **Decided 2026-08-08 as Decision 6, and the finding understated it.** The
      structural form is publish-is-file-scoped, bind-is-directory-scoped: git
      runs every entry by name, so an unpublished `pre-push` becomes machine-wide
      the moment the binding lands. Normative as "Binding activates a directory,
      so its every entry is inventoried first" — per-entry consent, named, never
      a blanket prompt. **The file nobody bound was measured**: a 46-line
      `pre-commit` vendored from `opencode-workflow` dated 2026-07-25, unmarked,
      exporting `OPENSPEC_GATE_SELF=opencode` and describing the pre-2.0.0 rule
      in which `REVIEWS.md` blocks. It self-heals (unmarked reads 0.0.0, floor is
      1.1.0) — but named `pre-push` it would have gated every commit on the
      machine under an archived host's identity. A copy, not a symlink, so every
      symlink-scoped sweep walked past it
- [ ] 9.7 **The enrolment predicate and `hooks.d` have no stated ordering.** The
      hook exits 0 before the gate when unenrolled, so an operator's
      machine-level hooks never run in unenrolled repositories. Both readings
      are defensible; the spec picks neither. opencode
- [ ] 9.8 **"Identical in enforcement" is false for repositories without CI.**
      The design says CI "does not run on most of these repositories", which
      leaves one surface that `--no-verify` bypasses, where the removed
      PreToolUse hook gated edits regardless of commit flags. The design counts
      the latency loss and never counts the bypass-path loss. opencode
- [ ] 9.9 **The budget claim is forward-looking and only partly measured.**
      opencode is right that the sweep, the exemption key and the effective-
      binding `--check` are unwritten behaviour that no pre-implementation
      measurement can cover — and wrong about the one part now measurable: the
      Decision 4 swap landed 217 → 217, measured against a `-le 217` assertion.
      Show the arithmetic for what remains, or invoke the escape clause now
- [ ] 9.10 **Repository discovery is undefined** for both the sweep and
      `--check`'s "names any repository the floor cannot reach". Same finding as
      3b.5, raised again independently — worth promoting out of a sub-task.
      **The migration half is closed 2026-08-08 as Decision 7; the `--check`
      half is deliberately still open.** Discovery turned out to be unnecessary
      rather than hard: the floor governs only enrolled repositories and
      enrolment has exactly two sources, so the installer already holds the set
      a binding will newly govern and has nothing to search for. Measured across
      61 repositories before deciding — seven carry a gate hook, none is
      enrolled, and reducing seven to three takes four judgements that are not
      properties of any file on disk. 3b.5's four questions are answered in the
      delta: no set is walked, the operator authorises by naming and by
      accepting one preflight, a failed repository keeps its hook and is
      reported while the run continues, and the preflight is the dry-run.
      `--check` is read-only and reports about a machine rather than acting on
      one, so a declared root is defensible there and is not settled here —
      answering half a finding and closing the whole thing is how the other half
      disappears. Stays `[ ]` until that half lands
- [x] 9.11 **The `core-self-enforcement` contradiction.** codex HIGH: the design
      removes the host `PreToolUse` hook while the unchanged durable requirement
      still mandates it. Either carry a core-only exception explicitly or amend
      every affected requirement and scenario.
      **Fixed 2026-08-08 by amending, not excepting.** "Core provides and
      registers the gate against its own repository" is now a MODIFIED
      requirement in the delta: two interposition points core owns —
      `pre-commit` and CI — and the floor for everything else, with the whole
      block carried and every scenario amended. A core-only exception was
      rejected because it would exempt core from the floor it publishes, which
      inverts what core is for. The amendment states the cost rather than
      netting it out: the removed hook gated edits regardless of commit flags,
      both remaining local points are commit-time, and `--no-verify` bypasses
      one — which is where 9.8's honest version now lives
- [ ] 9.12 **`--project`'s removal is not normative** — stated in proposal,
      design and an open task, but no scenario requires rejection without
      writes, so it does not survive archival and cannot be tested. codex
- [x] 9.13 **3.5's gap is live, and it collides with the sweep.** Measured
      2026-08-07 after `9b322fc`: core has **no** local `core.hooksPath` and
      resolves the default `.git/hooks`, so the moment the global binding exists
      git prefers the published directory and core's own hook stops running
      silently — the inversion ADR-0028 forbids. There is nothing to preserve,
      only something to create. Worse, core's `<common-dir>/hooks` **is**
      `.git/hooks`, so the only value core's binding can take is exactly the
      value 3b.2's predicate classifies as redundant: **the sweep would unset
      the binding 3.5 exists to establish.** 3.4 anticipates this as "declare
      core's binding", which is now load-bearing rather than tidy. codex raised
      the establisher half; the collision is new.
      **Both halves closed 2026-08-08.** The collision half was already
      normative and I had not read far enough to see it: the delta specifies
      `agenticapps.hooksbinding = declared` as a git config key in the same
      local scope, and the sweep excludes a declared binding without inspecting
      its value. The establisher half is Decision 6 — **the binder does it**,
      setting core's local binding and declaration before the global one and
      refusing the global one if that fails. Every other candidate owner
      disclaims it in its own text: `install.sh` by Decision 4,
      `init-project.sh` by "no hooks, no host configuration",
      `fresh-clone-needs-nothing` by "nothing else", CI by being a detector.
      Re-measured today: global `core.hooksPath` unset, core's local unset,
      core's `<common-dir>/hooks` is `.git/hooks` and core's own hook is there —
      so the displacement is still latent and will fire on the first successful
      bind

- [x] 9.14 **The sweep is not a no-op, and 3b.2 proved the wrong thing.** Found
      while closing 9.13. 3b.2 confirmed all five bindings equal
      `<common-dir>/hooks` and concluded "the sweep is a proven no-op". Unsetting
      a default-valued local binding is a no-op **only while no global binding
      exists** — which is the state 3b.2 measured and is still true today. Once
      the floor is bound, those same five unsets are what hand five repositories
      to it. That is the intent and the opposite of a no-op: the sweep is the
      mechanism. It matters beyond wording, because "provably a no-op" is the
      argument that made writing to another repository's git config feel safe
      enough to need no authorization boundary — which is 3b.5, reached from the
      other side

## 10. Implementation the Decision 6 findings create

- [x] 10.1 The binder inventories `~/.agenticapps/git-hooks/` before binding and
      refuses on an entry it did not publish, until accepted by name. Per entry,
      naming it — never a blanket "unexpected files, proceed?" Acceptance is
      `GLOBAL_FLOOR_ACCEPT="<name> <name>"`, plus a per-entry prompt when stdin
      is a tty, which is the posture `install.sh` already takes for every other
      acceptance. The inventory runs **before the publish**, because the entry
      the publish replaces is the one that most needs reporting. Two carve-outs,
      both drawn from the requirement rather than convenience: `hooks.d` is the
      composition directory the dispatcher runs, so flagging it would fire the
      refusal on every correctly composed machine; and an unmarked `pre-commit`
      is reported but does **not** block, because it does not survive the run —
      unmarked reads as 0.0.0 and arbitration replaces it before anything is
      bound. Everything else refuses. Re-measured 2026-08-08: the vendored
      46-line `opencode` `pre-commit` is still sitting in that directory,
      unmarked and dated 2025-07-25, so the self-heal path is the one a real run
      takes today
- [x] 10.2 The binder establishes core's local binding and
      `agenticapps.hooksbinding=declared` **before** the global binding, and does
      not set the global one if either write fails. Two things the spec delta
      left open were settled by placement rather than by prose. A **foreign
      global binding is refused first**, before core is touched: refusing means
      the global binding is never set, so core's hook is never displaced, so
      there is no casualty to repair — and writing into a repository with
      nothing to repair is the shape Decision 4 removed. A **foreign LOCAL
      binding in core is reported, never overwritten**, the same posture the
      binder already takes one level up; husky sets exactly that, and a
      declaration left on somebody else's hooks directory would tell the sweep
      to protect it. `--git-common-dir` resolves the default directory, never
      `--git-path hooks`, which honours `core.hooksPath` and would let a wrong
      binding confirm itself
- [x] 10.3 Remove core's `PreToolUse` registration from `.claude/settings.json`,
      which 9.11's amendment now permits and 2.x requires. Confirm the
      `pre-commit` hook and CI still gate, since they become the only two.
      `.claude/settings.json` held nothing but that registration, so it is
      **deleted rather than emptied** — `{}` is dead text and dead text reads as
      a live guarantee. The wrapper at `.claude/hooks/openspec-change-gate.sh`
      **stays**: it is core's own instance of the shim contract, two suites read
      its version marker and its self-hosting resolution order as the profile
      they contrast against, and `project-hook-binding` provides for exactly
      this — a copy documenting **in-file** that it is intentionally
      unregistered has that decision preserved rather than reconciled away as
      drift. That paragraph is now in the file and
      `tools/test-claude-hook-wrapper.sh` asserts it. The suite's two
      registration cases are inverted (the registration must be **absent**) and
      two more added for the surfaces that now carry the whole load: CI runs the
      gate on `pull_request` and on pushes to `main`, and the installer that
      writes the `pre-commit` hook exists. 12 → 14 cases, RED first
- [x] 10.4 Reword 3b.1 and 3b.2 so the sweep is described as the mechanism that
      extends the floor's reach, not as a no-op. The measurement stands; the
      conclusion drawn from it does not. The §3b preamble and `proposal.md`
      carried the same claim in the same words — "a no-op in each, which is what
      makes it safe" — so all four are corrected together; a corrected task
      contradicted by its own section heading is not corrected. `design.md`'s
      "a no-op **setting**" is left alone: that describes the binding, which is
      genuinely redundant, not the unset
- [x] 10.5 RED before GREEN on all of the above: an unrecognised entry blocks the
      bind; acceptance by name allows it; a failed core-binding write aborts the
      global bind; core's hook still runs after a successful bind.
      `tools/global-floor-bind.test.sh` 18 → 43 cases, RED first in both halves,
      and every one of the 43 fails under `GLOBAL_FLOOR_BIND_BIN=/usr/bin/true`.
      Three drafted assertions passed under that wrong implementation and were
      tightened: "core's hook still runs" is satisfied by a binder that bound
      nothing, because with nothing bound `.git/hooks/` runs by default, so the
      global binding is now asserted alongside the marker. `run_binder` also
      reads stdin from `/dev/null`, or the tty prompt would hang the suite for
      whoever ran it from a terminal

- [x] 10.6 **The suite wrote into the repository it lives in, and only this
      change could surface it.** Three `install.test.sh` cases ran the real
      checkout's `install.sh`, which resolves the real binder, whose checkout is
      this one — so the first green run left core's own `core.hooksPath` and
      declaration set on the operator's machine. `GIT_CONFIG_GLOBAL` was pinned
      per case for exactly this class of leak and cannot cover it: a
      repository's local config path is fixed by the repository. Fixed at both
      ends — `new_core()` makes the copied checkout a real repository so those
      cases isolate, and `run_install` records the real repo's binding around
      every run, failing by case name and restoring what it found. Verified by
      removing one `new_core` and watching the guard fire

- [x] 10.7 **What the security pass found in the consent gate 10.1 had just
      built.** Both were reproduced end to end before being fixed, and both are
      the same shape: a gate that reported consent it had not obtained.
      - [x] **The acceptance list globbed.** `for a in $ACCEPT` is unquoted so
            the list splits on whitespace, and unquoted expansion also does
            *pathname* expansion. `GLOBAL_FLOOR_ACCEPT='*'` — what an operator
            types meaning "accept whatever is there" — expanded against the
            working directory the binder happened to run from; with a file named
            `pre-push` in it, the wildcard matched the entry and the machine
            bound. That is the blanket acceptance this requirement forbids in as
            many words, arriving through the shell rather than the design, and
            it accepts different entries depending on where the command was run.
            Fixed with `set -f` around the loop
      - [x] **A marked `pre-commit` was exempt, and the marker is a comment.**
            The inventory skipped `pre-commit` whenever it carried a version
            marker — but a marker cannot establish who wrote a file. A
            `pre-commit` carrying `9.9.9` is newer than the checkout's, so
            arbitration correctly declines to publish, the file survives, and
            the run bound the directory it sits in **while printing "holds
            nothing this installer did not publish"**. The false positive claim
            is the finding: a clean-inventory line exists so that a clean result
            is evidence rather than silence, and evidence that is sometimes
            false is worse than the silence it replaced. The carve-out was
            justified by "publishing replaces it", so where the publish does not
            replace it the justification goes too. The recognition test is now
            **the publisher's own exit status** rather than the presence of a
            comment — exit 3 means the file in place is not ours, and it goes
            through the same per-entry consent as any other entry. Exit 3 is
            still not a publish failure; it is no longer a bind decision either,
            and conflating the two was the hole
      - [x] The clean-inventory line moved to **after** the publish. Before it,
            the claim can be false, and the entry the arbitration declines to
            replace is exactly the one it would be covering up
      - [x] 43 → 48 cases, RED first on all five. No `.gstack/security-reports/`
            directory was created: this repo carries what the diagram requires,
            and the findings belong beside the tasks that produced them

## 11. What the Stage 2 code review found in `install.sh`

Stage 2 ran 2026-08-08 in a cleared session against the whole branch diff; the
artifact is `CODE-REVIEW.md` beside this file. The Critical it found is C1, and
it is not new — it is §10 not having landed yet, restated with the mechanism
reproduced end to end. The two below are its own findings, fixed here.

- [x] 11.1 A step reports its OWN outcome. The project-hook success line was
      `[ -n "$out" ] && [ "$SKIPPED" = 0 ]`, so a run whose artifact publishing
      failed said nothing at all about project hooks that had published and
      attested cleanly — "it did not happen" and "something unrelated failed"
      read identically. It also required the helper to have written to stdout,
      which is a fact about the helper rather than about the step. Now keyed on
      the helper's exit status alone
- [x] 11.2 `--host auto` ADDS to the named set instead of replacing it.
      `REQUESTED="$(detect)"` discarded every host the operator had named — and
      naming a host is what you do precisely when detection will not find it, so
      `--host auto --host codex` dropped the one request that needed making and
      reported success. `auto` is stripped from the set rather than left in it,
      because the "was any host requested" check one screen down would otherwise
      count it
- [x] 11.3 RED before GREEN on both, in `tools/install.test.sh`. The `--host
      auto` case needed `hide_command codex`: every host this installer knows is
      on the real PATH of the machine this was written on, and the case's PATH
      ends in the real one, so the first version of the assertion passed while
      proving nothing. **`install.sh` is back at exactly 217 executable lines**,
      its budget — both fixes were written long, measured at 229, and compacted
