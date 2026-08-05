## Why

Two of the four host installers install software on the operator's machine
without asking. `codex-workflow/install.sh` and `opencode-workflow/install.sh`
both run `npm i -g @fission-ai/openspec` when the CLI is absent, and the code
says so deliberately — "the front end's core dependency — auto-install it ...
rather than only instructing." A global npm write is not a repo-local side
effect: it changes a tool that every other project on that machine resolves.

The other two never install. `claude-workflow` and `pi-agentic-apps-workflow`
detect the same missing CLI and print the command for the operator to run. So
the fleet has two incompatible answers to the same question, and no installer
implements the third option — offering, and letting the operator accept.

| Installer | Prerequisites checked | On a missing `openspec` |
|---|---|---|
| `claude-workflow` | `openspec` | prints `npm i -g …`, never installs |
| `codex-workflow` | `codex`, `npm`, `openspec` | **`npm i -g` automatically, no consent** |
| `opencode-workflow` | `opencode`, `npm`, `openspec` | **`npm i -g` automatically, no consent** |
| `pi-agentic-apps-workflow` | `openspec`, `pi` | prints `npm i -g …`, never installs |

None of the four prompts for consent anywhere. The one construct in
`codex-workflow/install.sh` that reads like a confirmation is post-install
advice about trusting a hook, not a gate on installing anything.

Nobody decided this. It accumulated, exactly as the three unscoreable-target
behaviours did before §20 — and the same remedy applies: state the contract,
then score it.

The requirement itself was recorded during `host-neutral-agents-md` and
deliberately kept out of it: the installer should detect missing prerequisites
on whatever machine it runs on and **offer** to install them, with the operator
accepting before anything is installed. That change is now shipping and would
have carried the requirement into its archive with nothing acting on it.

## What Changes

- **A new spec section states the prerequisite contract**: an installer detects
  what it needs, reports what is missing, and installs nothing outside the
  target repository without the operator's explicit acceptance.
- **Consent is required only for writes outside the target repo.** Provisioning
  files into the repo the operator pointed the installer at is the thing they
  asked for. Installing a global npm package, writing to `~/.agenticapps/bin/`,
  or touching a host's global config is not implied by that request.
- **A non-interactive run must not silently choose either answer.** With no TTY
  — CI, a piped `curl … | bash` — an installer cannot obtain consent, so it
  reports what is missing and exits rather than either installing anyway or
  pretending the prerequisite is satisfied.
- **An explicit opt-in flag substitutes for interactive consent**, so automated
  installs remain possible without inventing an implied yes.
- **A conformance harness scores the contract**, following the established
  `tools/*-conformance.sh` shape, so each host repo can adopt on its own
  schedule rather than requiring a coordinated four-repo PR train.
- **BREAKING** for `codex-workflow` and `opencode-workflow`: an unattended run
  that previously installed `@fission-ai/openspec` will now stop and report
  unless the operator accepts or passes the opt-in flag. That is the point of
  the change, and it is the behaviour their own inline comments describe as a
  deliberate choice — so it needs reverting deliberately, not silently.

Explicitly **not** in scope:

- **The curl-able bash installer** (originally framed as this change's whole
  subject). Four installers already exist; a fifth is construction, and
  `docs/PLAN-lightweight-fleet.md` says deletion beats construction and that
  new machinery waits on the step-4 question — whether `codex`, `opencode` and
  `pi` are live enough to keep. The consent defect is live today regardless of
  that answer, so it is separated out and done first. The curl-able installer
  is recorded in Impact below, gated on step 4, so it is not lost again.
- **Editing the host repos' installers.** This change defines what they must
  satisfy and ships the harness that scores it; they change on their own
  schedule, as with `host-neutral-agents-md`.
- **Which prerequisites each host needs.** The contract is about consent and
  reporting, not about the dependency list, which is legitimately host-specific
  (`codex` checks for `codex`, `pi` for `pi`).

## Capabilities

### New Capabilities

- `installer-prerequisite-consent`: an installer detects its prerequisites,
  reports which are missing, and obtains the operator's acceptance before
  installing anything outside the target repository. Covers what counts as
  outside, what a non-interactive run must do, the opt-in flag that substitutes
  for a prompt, and what an installer must report when it proceeds without a
  prerequisite.

### Modified Capabilities

None. No existing capability under `openspec/specs/` states requirements about
installer behaviour or prerequisite handling.

## Impact

- **New spec section** — the prerequisite contract, alongside §12's
  authoring conventions and §20's harness-reporting contract. Section number
  assigned during design.
- **`tools/installer-prereq-conformance.sh`** (new) and its test suite, scoring
  a named installer against the contract in both directions.
- **`.github/workflows/openspec-gate.yml`** — runs the new suite, and scores
  core's own `tools/install-core-git-hooks.sh`, which unlike the host
  installers *is* core's to score.
- **Host installers, not edited here**: `claude-workflow/install.sh`,
  `codex-workflow/install.sh`, `opencode-workflow/install.sh`,
  `pi-agentic-apps-workflow/install.sh`. Two are non-conformant today.
- **Deferred, recorded so it is not lost a second time**: the curl-able bash
  installer. Gated on `docs/PLAN-lightweight-fleet.md` step 4 — if `codex`,
  `opencode` and `pi` are archived, three of the four installers disappear and
  a curl-able one has almost nothing left to install.
