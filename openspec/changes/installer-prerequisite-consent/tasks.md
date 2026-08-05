## 1. Settle what the contract covers before writing it

- [ ] 1.1 Decide whether `~/.agenticapps/bin/` is inside or outside the consent boundary — it is outside by the rule as written, but `PLAN-lightweight-fleet` step 2 makes writing it the primary publishing mechanism, so prompting every time works against the one thing that doc wants cheap
- [ ] 1.2 Decide whether every prerequisite warrants an offer, or only ones the installer can install without imposition — offering to install `npm` or a host CLI is a different size of act from one global npm package, and the spec currently treats them alike
- [ ] 1.3 Name the opt-in flag and settle whether it is a flag, an environment variable, or both, checking it against what the four installers already parse so adoption does not collide with an existing option
- [ ] 1.4 Confirm the answer to `PLAN-lightweight-fleet` step 4 does not moot this — if `codex`, `opencode` and `pi` are archived, this reduces to `claude-workflow`'s installer plus core's own, which is still worth stating but is a smaller claim than the proposal makes

## 2. Spec section

- [ ] 2.1 Assign the section number and create `spec/NN-installer-prerequisites.md` with the standard declarative-contract frontmatter and header
- [ ] 2.2 Write the detect-and-report requirement, which all four installers already satisfy — it is stated so the report is the observable, not so anything changes
- [ ] 2.3 Write the consent requirement, scoped to writes outside the target repository, with the boundary from 1.1 named explicitly
- [ ] 2.4 Write the requirement that repo-local writes need no separate acceptance, since without it the consent rule reads as forbidding installation altogether
- [ ] 2.5 Write the non-interactive requirement: report and stop, never install and never assume satisfied — both silent answers convert an absent decision into a decision
- [ ] 2.6 Write the opt-in flag requirement using the name from 1.3, including that the flag's absence is never acceptance
- [ ] 2.7 Write the skipped-step reporting requirement, so an installer that proceeds without a prerequisite cannot exit 0 having quietly done less
- [ ] 2.8 Add the Conformance section stating which requirements are MUST and which are SHOULD, and why
- [ ] 2.9 Add the `CHANGELOG.md` entry naming the conformance impact for host implementers, and stating plainly that two hosts are non-conformant today

## 3. Conformance harness

- [ ] 3.1 Create `tools/installer-prereq-conformance.sh` in the single-target shape — one installer path, abort on an unusable target, never exit 0 having scored nothing
- [ ] 3.2 Score that the installer detects each prerequisite it uses, by cross-referencing the tools it invokes against the ones it checks for
- [ ] 3.3 Score for an install command reachable outside the target repository — `npm i -g`, `pip install --user`, a write under `$HOME` — as the structural signal, since it does not depend on recognising phrasing
- [ ] 3.4 Score whether each such command is guarded by a consent read or the opt-in flag, and fail when it is reachable without either
- [ ] 3.5 Score that a non-interactive path exists and does not fall through to installing
- [ ] 3.6 Report as INCONCLUSIVE, never as passing, every row that cannot be decided statically — a host must not reach a passing total on rows nobody scored
- [ ] 3.7 Emit the coverage line on every run, naming how many rows were scored and how many were inconclusive, so a mostly-inconclusive run cannot read as a clean one

## 4. Tests

- [ ] 4.1 Write `tools/installer-prereq-conformance.test.sh` with both directions pinned — a conformant reference installer that must pass every row, and violating ones that must each fail the specific row they violate
- [ ] 4.2 Build a fixture reproducing the real `codex-workflow` / `opencode-workflow` shape — a bare `npm i -g` reachable with no prompt and no flag — and assert it fails
- [ ] 4.3 Build a fixture reproducing the real `claude-workflow` / `pi` shape — detects and instructs, never installs — and assert it does NOT fail the consent row, since instructing without installing is conformant even though it does not offer
- [ ] 4.4 Assert an installer that writes only inside the target repo needs no prompt and passes, so the rule cannot be satisfied by an installer that installs nothing
- [ ] 4.5 Assert the opt-in flag path passes and the flag's absence is not read as acceptance
- [ ] 4.6 Run under bash 3.2 with BSD sed and bash 5 with GNU sed in a container; record both totals
- [ ] 4.7 Run `shellcheck -S warning` over every new script to zero findings

## 5. Wire up

- [ ] 5.1 Add the test suite to `.github/workflows/openspec-gate.yml`
- [ ] 5.2 Score `tools/install-core-git-hooks.sh` in CI — core's own installer, and unlike the four host ones it is core's to score
- [ ] 5.3 Record whether core's own installer passes, and fix or accept-with-reason if it does not — shipping a contract core violates is the failure this repo has already had

## 6. Close out

- [ ] 6.1 Run `openspec validate --all` green
- [ ] 6.2 Confirm no host repo was edited
- [ ] 6.3 Report to the host repos that `codex-workflow` and `opencode-workflow` are non-conformant, with the harness output as the evidence
- [ ] 6.4 Confirm the deferred curl-able installer is still recorded and gated on `PLAN-lightweight-fleet` step 4 — it was lost once already, which is why this change exists
- [ ] 6.5 Open the PR and archive the change
