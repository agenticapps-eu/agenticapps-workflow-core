---
reviewers: [gemini, codex]
models: [gemini-cli-0.28.2-default-unpinned, gpt-5.6-sol]
verdicts: [REQUEST-CHANGES, REQUEST-CHANGES]
rounds: 2
reviewed_artifacts_sha: 6e8f33dec9dcc9b93ee4c6d8a09173b7ae62bcd087e0d03467872a2d0c4a48c5
previous_round_sha: 3e82e443ad32543b8d5431d74daba65b7c0d934b4bc1ae99cb6ce36d4cc436f4
---

# Change review — core-installer-one-entry-point

Two rounds, two vendors, neither of them the authoring vendor (claude). Both
rounds returned REQUEST-CHANGES from both reviewers. Round two was capped by
agreement: its findings are recorded and resolved here, not sent back again.

Round one's findings and their resolutions are in the git history of this file.
Round two's findings are different from round one's rather than repeats, which
is the evidence that the revision landed — and the evidence that the plan was
further from ready than round one made it look.

## Round 2 — Reviewer: gemini (gemini-cli 0.28.2, model not pinned)

VERDICT: REQUEST-CHANGES

- [HIGH] tasks 3.7 — the negative test is scoped to bindings "installed by this
  workflow", which is unverifiable and leaves out exactly the bindings a manifest
  gap would miss. Scan every known host skill directory for symlinks into any
  known-archived checkout, regardless of manifest membership.
- [MEDIUM] design, `--project` — "generalised by `cd`, not by modification"
  contradicts a flag that takes a path. A flag that ignores its own argument is a
  bug waiting to happen.
- [MEDIUM] tasks — nothing tests that a published executable is executable.
- [LOW] spec, the budget — "report the overage" gives no way to proceed, which
  makes the budget a suggestion. Define what is mandatory versus deferrable.

## Round 2 — Reviewer: codex (gpt-5.6-sol, reasoning effort high)

VERDICT: REQUEST-CHANGES

- [HIGH] design, `--project` hooks — `install-core-git-hooks.sh` is
  core-specific: the hook it writes resolves
  `<repo>/reference-implementations/…`, which a consuming project does not have.
  It cannot install a project shim by changing directories. It also refuses an
  in-worktree `core.hooksPath`, contradicting task 2.4's unqualified success case.
- [HIGH] design, publishing `database-sentinel` — routing it through
  `install-shared-artifact.sh` bypasses the declared-set and manifest attestation
  `project-hook-binding` requires. That helper gives monotonic replacement, not
  attestation. Publish project hooks through `install-project-hooks.sh`.
- [HIGH] spec, recoverability — the shared-artifact installer overwrites an older
  or equal destination without preserving it, and a backup taken by `install.sh`
  before delegating is racy: the destination can change before the helper takes
  its lock. Either add backup-under-lock to the helper or withdraw the guarantee
  for published artifacts.
- [HIGH] design/tasks, currency — comparing version markers is not currency. A
  hand-edited executable carrying the same marker reports as current, which is
  round one's H7 failure repeated one level down. `project-hook-binding` defines
  currency by byte comparison against the authority checkout and distinguishes
  unreadable, ahead, stale, and same-version-different-bytes.
- [HIGH] tasks 6.7–6.8 — the opencode plugin is created and behaviour-tested but
  never installed. There is no `wire_opencode`, no acceptance, no backup, no
  idempotence, no failure handling.
- [HIGH] spec, binding target states — the requirement promises an outcome for a
  regular file and defines none, and it replaces every foreign symlink without
  acceptance even when the link belongs to unrelated software.
- [HIGH] design/task 6.11, instruction-file provisioning — **no canonical
  provisioner exists in core.** `tools/agents-md-conformance.sh` is a checker
  that relies on externally supplied add and remove commands; it does not write
  the section. No template, no version source, no frontmatter-preserving writer.
- [MEDIUM] design, the legacy manifest — the actual name-to-outcome mapping is
  still absent, and testing "every name in the manifest" against that same
  manifest is circular.
- [MEDIUM] spec, skipped work — exit 3 from the shared-artifact installer is
  contractually *success* (the destination is newer), but the delta calls it
  "skipped", and skipped requested work must exit non-zero. Classify it as
  satisfied.
- [MEDIUM] spec, non-interactive acceptance — the required named opt-in has no
  flag or variable name, and the five-mode interface does not mention it.
- [MEDIUM] tasks 4.1 — "every pre-existing hook survives byte for byte" is
  incompatible with rendering the document through `jq`, which reserialises.
  Require semantic preservation, and byte equality only of the backup.
- [MEDIUM] spec/tasks, check mode — the requirement demands version and currency
  for every binding; the tasks test only bound versus unbound.
- [MEDIUM] tasks, rollback evidence — backup naming, collision, retention,
  permissions, backup failure and recovery-after-removal are unspecified, and the
  before state is printed rather than recorded as durable evidence.

## Not counted

- opencode — not run, either round. Its `opencode.json` pins no model, so rule 4
  cannot be satisfied: an unpinned client may resolve to the authoring vendor.
- codex, round one first attempt — exit 4 at the default 300s; re-run at
  `REVIEWER_TIMEOUT=900` and counted on the second attempt. `gpt-5.6-sol` at high
  reasoning effort does not fit a 300s bound on a change this size. Worth raising
  the default for this vendor.

## Resolution

I verified the four findings that would change the plan, rather than deferring.
Three are confirmed, and two of them are worse than the reviewer stated.

**The project hook installer is core-specific — confirmed, line 162.** The hook
it generates resolves
`${OPENSPEC_GATE:-$ROOT/reference-implementations/openspec-change-gate/openspec-change-gate.sh}`.
That is ADR-0028's self-hosting inversion working exactly as designed: core
gates itself with its own working tree. A consuming project has no
`reference-implementations/` directory, so this script cannot bind a project at
all, by `cd` or otherwise. The project shim is a *different artifact* —
`reference-implementations/project-hooks/openspec-change-gate.shim.sh` — with a
different installer. My design named the wrong one, and the sentence
"generalised by `cd`, not by modification" was wrong twice over: gemini caught
that it contradicts the flag, codex caught that the target cannot work.

**No canonical instruction-file provisioner exists — confirmed.** Searching this
repository for the mandated marker across shell sources returns the conformance
*test*, the authoring-conventions spec, and the capability spec. No writer. So
`--project` delegates to something that does not exist, and building it is a
deliverable of unknown size: a section template, a version source, frontmatter
placement, byte preservation outside the markers, and consent to update.

**`database-sentinel` needs the attesting installer — confirmed by
`~/.agenticapps/manifest.tsv`,** which carries exactly the project-hook
artifacts with version and sha256, and nothing else. That manifest is the
attestation, and `install-shared-artifact.sh` does not write it.

**Currency by marker is not currency — accepted.** `project-hook-binding` has a
requirement titled "Currency is judged against an authority checkout". A marker
comparison cannot see a hand-edited file.

Every other finding is accepted as stated. Nothing is rejected. Two corrections
to my own round-one resolutions are worth naming, because I recorded them as
settled and they were not: exit 3 is success and I called it skipped, and I
claimed a delegation target that cannot serve the case I claimed it for.

### The consequence, and why this file stops here rather than iterating

Round two did not find polish. It found that two of the three things this
installer was going to *delegate to* do not cover `--project`: the hook
installer is core-only by design, and the provisioner does not exist. Round one's
central insight — orchestrate, do not reimplement — holds for the host side and
does not hold for the project side, because on the project side there is
currently nothing to orchestrate.

That is a scope discovery, not a defect to patch in a third round. The 200-line
budget was already at risk before it; with a provisioner and a project-shim path
added it is not credible, and the spec forbids meeting it by dropping a promised
mode.

So this change is **paused for a scope decision** rather than revised again. The
recommendation, recorded here so the reasoning survives:

> Split it. Land the host side — publish, bind skills, replace legacy bindings,
> wire claude/codex/opencode, `--check` — as this change. Move `--project` to its
> own change, because `--project` is not one flag on an installer; it is a
> project-shim installer plus an instruction-file provisioner that core does not
> yet have, and pretending otherwise is how a 200-line installer becomes the next
> thing nobody wants to use.

Applying the accepted findings to the host side is straightforward and mostly
already written above. `--project` needs its own proposal, and its own review.
