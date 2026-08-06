## 1. Harness, and the RED cases for the floor

TDD, RED before GREEN. The suite runs against a fake `HOME` and a scratch git
repo, so no test touches the real machine — that is task 1.1, and nothing below
it can be trusted until it exists.

- [x] 1.1 `tools/install.test.sh`: per-case temp `HOME` and temp git repo; the
      suite fails if `install.sh` writes outside them
- [x] 1.2 RED: a bare run publishes the payload and installs core's pre-commit
      hook, with no host present
- [x] 1.3 RED: the run exits 0 when no host is installed, and says none was bound
- [x] 1.4 RED: `git` missing fails the run, names `git`, publishes nothing
- [x] 1.5 RED: an optional dependency absent, with nothing requesting it,
      completes and exits 0, printing the install command but not running it
- [x] 1.6 RED: the budget — `install.sh` is at most 250 executable lines (raised from 200 by spec amendment; see the requirement)
- [x] 1.7 RED: `--help` names every mode and names the host-config opt-in flag

## 2. RED cases for delegation

- [x] 2.1 RED: the three workflow executables are published through
      `install-shared-artifact.sh` with the right marker key per artifact, and
      the destination is not written by any other means
- [x] 2.2 RED: the project-hook set is published through
      `install-project-hooks.sh`, and `manifest.tsv` afterwards carries a row per
      declared artifact — the attestation the arbitrating helper does not write
- [x] 2.3 RED: a declared project hook missing from the source is reported and
      fails the step, rather than publishing a smaller set silently
- [x] 2.4 RED: a destination holding a strictly newer version is left intact and
      counted **satisfied** — the exit-3 path — and does not by itself make the
      run exit non-zero
- [x] 2.5 RED: every published artifact is executable at its destination
- [x] 2.6 RED: core's hook is installed through `install-core-git-hooks.sh`; a
      foreign pre-commit hook is refused, not replaced

## 3. RED cases for bindings

One case per row of the target-state table in the design, because the first
draft named states it defined no outcome for.

- [x] 3.1 RED: skills appear as symlinks into the checkout, never regular files
      or directories
- [x] 3.2 RED: a symlink into a checkout the legacy manifest names is replaced
      outright and reported, naming its old target
- [x] 3.3 RED: a symlink to something unrecognised is replaced only with
      acceptance; declined, it is left and counted skipped
- [x] 3.4 RED: a *directory* at the target is reported as a copy and replaced
      only with acceptance; declined, it is left and counted skipped
- [x] 3.5 RED: a *regular file* at the target is reported and replaced only with
      acceptance; declined, it is left and counted skipped
- [x] 3.6 RED: a dangling symlink and a relative symlink are each resolved before
      judgement, and any replacement is an absolute link
- [x] 3.7 RED: symlink creation failure reports and continues, and does not copy
- [x] 3.8 RED: every legacy name in the manifest is replaced or removed, and each
      outcome is reported by name
- [x] 3.9 RED: **the negative test, and it must not consult the manifest** —
      seed a host skill directory with a binding into an archived checkout under a
      name the manifest does *not* carry; after a run the scan over every known
      host skill directory reports it. A test that reads the manifest to decide
      what to look for cannot fail this way, which is the point
- [x] 3.10 RED: replaced bindings are preserved at a reported path and the
      restore command is stated

## 4. RED cases for writing no host configuration

Group 4 was thirteen wiring cases. Host wiring left this change after round
three, and the cases went with it — replaced by the ones that prove it is gone,
which assert the FILES rather than the absence of the functions. A test that only
checked the functions were deleted would pass against an installer that wrote the
same files by another route.

- [x] 4.1 RED: binding a host creates no host configuration file and modifies no
      existing one, while the skills still bind — the negative test the whole
      narrowing rests on
- [x] 4.2 RED: the removed opt-in exits 64 with the argument named, rather than
      being accepted, ignored, or treated as a no-op
- [x] 4.3 RED: `install.sh` references no host configuration artifact, and
      `hosts/` does not exist
- [x] 4.4 RED: a full run with `jq` hidden completes and mentions `jq` nowhere —
      it was Tier 2 for the JSON merge alone, so its absence must now be
      invisible rather than politely reported
- [x] 4.14 RED: auto-detection ignores a directory whose host is not installed,
      and reports the shared `~/.agents/skills` binding once, naming both hosts

## 5. RED cases for check mode

- [x] 5.1 RED: `--check` on an empty `HOME` reports everything absent and creates
      no file
- [x] 5.2 RED: `--check` reports a published artifact behind the checkout as
      present, names both versions, and marks it not current
- [x] 5.3 RED: **currency is by content** — an artifact hand-edited while keeping
      the checkout's version marker is reported not current, and distinguished
      from one that is merely behind. This case fails against a
      marker-comparison implementation, which is why it exists
- [x] 5.4 RED: an artifact newer than the checkout is reported as ahead, not as
      stale and not as current
- [x] 5.5 RED: an unreadable artifact, and one whose marker will not parse, are
      each reported as such rather than as absent or current
- [x] 5.6 RED: `--check` distinguishes a bound host from an unbound one, and an
      unrequested unbound host alone does not make the exit non-zero
- [x] 5.7 RED: a full run twice leaves identical machine state

## 6. RED cases for preserved copies

Round two found backup naming, collision, retention, permissions and failure all
unspecified. Each is a case.

- [x] 6.1 RED: two runs replacing the same target leave two preserved copies; the
      first is not overwritten
- [x] 6.2 RED: a preserved copy carries the permissions of what it preserved
- [x] 6.3 RED: a preservation that cannot be written aborts that step, and the
      target is left unmodified
- [x] 6.4 RED: the restore command the summary prints actually restores, run
      verbatim

## 7. Implementation

- [x] 7.1 `install.sh` skeleton: the four modes, Tier 1 check for `git` and
      `bash`, and the satisfied/skipped accounting that drives the exit code
- [x] 7.2 Tier 2 reporting: check the optional dependencies, print install
      commands, run none
- [x] 7.3 Publish the three workflow executables through
      `install-shared-artifact.sh`; treat exit 3 as satisfied
- [x] 7.4 Publish the project-hook set through `install-project-hooks.sh`
- [x] 7.5 Install core's own hook through `install-core-git-hooks.sh`
- [x] 7.6 `bind_skills`: the target-state table from the design, plus the legacy
      manifest as written data
- [x] 7.7 `install_hosts`: one path for every host, with no per-host branch —
      the moment one exists the second is cheap
- [x] 7.10 `--host auto`: detect by host executable
- [x] 7.11 `--check`: version and content-wise currency per artifact
- [x] 7.12 Green through every RED case in groups 1–6

## 8. Verification

- [x] 8.1 Green on 1.6 — the budget. If it cannot be met, defer from the
      deferrable list in the stated order and report each deferral. Do not drop
      `--host auto`; it is normative
- [x] 8.2 Whole suite green; `openspec validate --all` green; the gate exits 0
- [x] 8.3 Record the before state: `./install.sh --check` on the real machine,
      **saved to a file**, not printed and scrolled past
- [ ] 8.4 Run `./install.sh --host auto --replace-unrecognised` for real;
      confirm legacy bindings are gone and every previously-bound host is still
      bound. No configuration opt-in is passed because there is no longer one to
      pass, which is what makes this run safe to do beside live sessions
- [ ] 8.5 Confirm a fleet project's shim still resolves
      `~/.agenticapps/bin/openspec-change-gate.sh` unchanged
- [ ] 8.6 Confirm `manifest.tsv` afterwards carries the declared set. The
      retired `normalize-claude-md.sh` row **survives**: `install-project-hooks.sh`
      carries forward every row outside the declared set by design, so removing
      it needs explicit pruning and is not this change's to do
- [ ] 8.7 Confirm no host configuration file was created or modified by the
      real run — the machine-level check that matches test 4.1
- [ ] 8.8 Code review on the diff — the independent read that follows
      implementation, distinct from the plan review already in `REVIEWS.md`
- [ ] 8.9 `cso`

## 9. Hand off what was deferred

- [x] 9.1 The `--project` follow-up is **superseded, not opened**. Its successor
      is `one-enforcement-floor`, which drops `--project` outright: with the git
      floor bound machine-wide there is no per-repository hook left for it to
      install, and what remained — the instruction-file provisioner — depends on
      a question that change deliberately leaves open
- [ ] 9.2 Re-run the plan reviewers. `REVIEWS.md` describes a scope that no
      longer exists: it reviewed an installer that wired three hosts
