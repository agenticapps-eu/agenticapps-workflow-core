## 1. Settle what the contract covers before writing it

Answered during the first plan review, which found the delta had already made
these normative while the design still listed them as open. Carried, not
re-litigated.

- [x] 1.1 Decide whether `~/.agenticapps/bin/` is inside or outside the consent boundary — **the boundary is ownership, not location.** It is the workflow's own directory, used by nothing else, so writing it is what installing the workflow means: reported, not prompted. A location rule would have condemned all four installers, not two, and put a prompt in front of `PLAN-lightweight-fleet` step 2's publishing mechanism
- [x] 1.3 Name the opt-in flag and settle whether it is a flag, an environment variable, or both — **both**: `AGENTICAPPS_INSTALL_PREREQS=1` and `--install-prereqs`. Leaving the name open would have produced four spellings and made the non-interactive report, which must name the flag, unscoreable
- [x] 1.4 Confirm the answer to `PLAN-lightweight-fleet` step 4 does not moot this — **it does not, and the question was mis-framed.** More than one agent host is a settled constraint; only *which* hosts is open. A cross-host consent contract is permanently load-bearing, which is why it is written against "an installer" rather than an enumerated four
- [x] 1.2 Decide whether every prerequisite warrants an offer, or only ones the installer can install without imposition — **a system runtime is never offered** (Donald: "not thinking of npm"). `npm`, `node`, `git` and the host CLIs are detected and instructed only. What may be offered is a package installed *through* a runtime already present, which is the `@fission-ai/openspec` case the two unconsented installs actually perform
- [x] 1.5 Decide what happens to a prerequisite installed on the operator's behalf when the workflow is removed — **it is never removed automatically, and what is left behind is reported.** The ownership test runs in both directions: a package the operator accepted may now be resolved by projects this workflow did not install, so removing it is the very act consent exists to prevent. Offering to remove it was rejected — it prompts about the outcome the operator almost always wants, and adds a second consent surface to state and to score

## 2. Spec section

- [x] 2.1 Assign the section number and create `spec/NN-installer-prerequisites.md` with the standard declarative-contract frontmatter and header
- [x] 2.2 Write the detect-and-report requirement, which all four installers already satisfy — it is stated so the report is the observable, not so anything changes
- [x] 2.3 Write the consent requirement, scoped by the ownership boundary from 1.1, with the four write categories tabulated and the "could this change software the operator did not install by running this installer" test stated
- [x] 2.4 Write the requirement that repo-local writes need no separate acceptance, since without it the consent rule reads as forbidding installation altogether — including that this is not permission to replace a repo file the installer did not provision
- [x] 2.5 Write the non-interactive requirement: report and stop, never install and never assume satisfied — both silent answers convert an absent decision into a decision. Name the detection rule (stdin is not a terminal), or four hosts invent four notions of it
- [x] 2.6 Write the opt-in requirement using the names from 1.3, including that absence is never acceptance and that only installers capable of such an install are obliged to accept it
- [x] 2.7 Write the skipped-step requirement, so an installer that proceeds without a prerequisite cannot exit 0 having quietly done less — reporting alone is insufficient, since a zero exit is what an automated caller reads
- [x] 2.10 Write the consent-shape requirement: terminal input, explicit affirmative only, empty/unrecognised/EOF decline, one prompt per install command
- [x] 2.11 Write the version-drift requirement — a prerequisite present but older than required is an upgrade, and replacing a tool already on the machine needs the same acceptance as installing one
- [x] 2.12 Write the redaction requirement, since "print the exact command" plus CI logs is how a registry token gets published
- [x] 2.8 Add the Conformance section stating which requirements are MUST and which are SHOULD, and why
- [x] 2.9 Add the `CHANGELOG.md` entry naming the conformance impact for host implementers, and stating plainly that two hosts are non-conformant today

## 3. Conformance harness

- [x] 3.1 Create `tools/installer-prereq-conformance.sh` in the single-target shape — one installer path, abort on an unusable target, never exit 0 having scored nothing
- [x] 3.2 Score that the installer detects each prerequisite it uses, by cross-referencing the tools it invokes against the ones it checks for
- [x] 3.3 Score for an install command reachable outside the target repository — `npm i -g`, `pip install --user`, a write under `$HOME` — as the structural signal, since it does not depend on recognising phrasing
- [x] 3.4 Score whether each such command is guarded by a consent read or the opt-in flag, and fail when it is reachable without either
- [x] 3.5 Score that a non-interactive path exists and does not fall through to installing
- [x] 3.6 Report as INCONCLUSIVE, never as passing, every row that cannot be decided statically — a host must not reach a passing total on rows nobody scored
- [x] 3.7 Emit the coverage line on every run, naming how many rows were scored and how many were inconclusive, so a mostly-inconclusive run cannot read as a clean one

## 4. Tests

- [x] 4.1 Write `tools/installer-prereq-conformance.test.sh` with both directions pinned — a conformant reference installer that must pass every row, and violating ones that must each fail the specific row they violate
- [x] 4.2 Build a fixture reproducing the real `codex-workflow` / `opencode-workflow` shape — a bare `npm i -g` reachable with no prompt and no flag — and assert it fails
- [x] 4.3 Build a fixture reproducing the real `claude-workflow` / `pi` shape — detects and instructs, never installs — and assert it does NOT fail the consent row, since instructing without installing is conformant even though it does not offer
- [x] 4.8 Build a fixture that writes only into `~/.agenticapps/bin/` and assert it does NOT require consent but IS required to report — the ownership boundary's whole point, and the row that would have caught the location rule condemning all four installers
- [x] 4.4 Assert an installer that writes only inside the target repo needs no prompt and passes, so the rule cannot be satisfied by an installer that installs nothing
- [x] 4.5 Assert the opt-in flag path passes and the flag's absence is not read as acceptance
- [x] 4.6 Run under bash 3.2 with BSD sed and bash 5 with GNU sed in a container; record both totals
- [x] 4.7 Run `shellcheck -S warning` over every new script to zero findings

## 5. Wire up

- [x] 5.1 Add the test suite to `.github/workflows/openspec-gate.yml`
- [x] 5.2 Score `tools/install-core-git-hooks.sh` in CI — core's own installer, and unlike the four host ones it is core's to score
- [x] 5.3 Record whether core's own installer passes, and fix or accept-with-reason if it does not — shipping a contract core violates is the failure this repo has already had. **It did not pass, and was fixed.** `install-core-git-hooks.sh` resolves every destination it writes through `git rev-parse` and never checked that `git` is present, so it failed `prereq-detection`. Fixed rather than accepted: the check is three lines, and without it the failure surfaces as git's own "command not found", which names the symptom instead of the missing prerequisite. Now 3 passed, 0 failed, 4 inconclusive. Pointing the harness at core's own installer is also what exposed two harness defects that fixtures had not — see the group 3 commit

## 6. Close out

- [x] 6.1 Run `openspec validate --all` green — 8 passed, 0 failed
- [x] 6.2 Confirm no host repo was edited — all four working trees carry only pre-existing untracked files (2026-07-25 and 2026-07-31 mtimes, none from today). The installers were read, never written
- [x] 6.3 Report to the host repos that `codex-workflow` and `opencode-workflow` are non-conformant, with the harness output as the evidence — `CONFORMANCE-EVIDENCE.md`. The consent row sorts the fleet exactly as predicted: `codex-workflow:333` and `opencode-workflow:373` reach `npm i -g @fission-ai/openspec` unguarded; claude and pi pass it. Two findings the proposal did not predict: all four fail `prereq-detection` on an unchecked `git`, and `pi` alone fails the new `~/.agenticapps/` reporting obligation the migration plan assumed all four would gain
- [x] 6.4 Confirm the deferred curl-able installer is still recorded and gated on `PLAN-lightweight-fleet` step 4 — it was lost once already, which is why this change exists. Recorded in the proposal's Non-goals and Impact, and in the design's Decisions
- [x] 6.5 Open the PR and archive the change
