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

**All four also write into `~/.agenticapps/bin/` unconditionally** — the shared
change-gate and reviewer-cli (`claude-workflow:149`, `codex-workflow:211`,
`opencode-workflow:329`, `pi-agentic-apps-workflow:148`). A rule drawn at
"outside the repository" would therefore condemn all four, not two, and would
put a prompt in front of the mechanism `docs/PLAN-lightweight-fleet.md` step 2
designates as the primary way core publishes an artifact. This change draws the
line at **ownership** instead: `~/.agenticapps/bin/` is the workflow's own
directory, used by nothing else, so writing it is what installing the workflow
means. A global npm package is a namespace shared with software the workflow
did not install. That distinction is the change's central decision, and it is
what keeps the contract to the two genuinely unconsented installs.

Nobody decided this. It accumulated, exactly as the three unscoreable-target
behaviours did before §20 — and the same remedy applies: state the contract,
then score it.

The requirement itself was recorded during `host-neutral-agents-md` and
deliberately kept out of it: the installer should detect missing prerequisites
on whatever machine it runs on and **offer** to install them, with the operator
accepting before anything is installed. That change is now shipping and would
have carried the requirement into its archive with nothing acting on it.

## What Changes

- **A new spec section states the prerequisite contract**: an installer declares
  what it needs, reports what is missing, and changes no software the workflow
  does not own without the operator's explicit acceptance.
- **Consent attaches to ownership, not location.** Provisioning the target repo
  is what the operator asked for. Writing the workflow's own
  `~/.agenticapps/bin/` is what installing the workflow *is* — reported, not
  prompted. Mutating a third-party package manager's global namespace, or a
  host's global config, is neither, and requires acceptance.
- **Repository-local writes are covered but not unbounded** — an installer must
  still report, rather than silently replace, a repo file it did not provision.
- **A non-interactive run must not silently choose either answer.** With stdin
  not a terminal — CI, a piped `curl … | bash` — an installer cannot obtain
  consent, so it reports what is missing and exits rather than either installing
  anyway or pretending the prerequisite is satisfied. The detection rule is
  named, so four hosts do not invent four notions of non-interactive.
- **A named opt-in substitutes for the prompt**: `AGENTICAPPS_INSTALL_PREREQS=1`
  or `--install-prereqs`. Fixing the name is the point — four spellings would
  defeat "one answer stated once" and make the non-interactive report, which
  must name the flag, unscoreable. Required only of installers that can actually
  install something.
- **Consent has a stated shape**: read from the terminal, explicit affirmative
  only, empty/unrecognised/EOF declines, and one prompt per install command
  rather than one blanket prompt for a set the operator has not been shown.
- **Version drift counts as an install.** A prerequisite present but older than
  required is an upgrade, which replaces a tool already on the machine.
- **Printed commands are redacted**, since the transparency measure otherwise
  writes registry tokens into CI logs.
- **Skipped work exits non-zero**, because a zero exit is what an automated
  caller reads and reporting alone does not reach it.
- **A conformance harness scores the contract**, following the established
  `tools/*-conformance.sh` shape, so each host repo can adopt on its own
  schedule rather than requiring a coordinated four-repo PR train.
- **Behaviour change on adoption** for `codex-workflow` and `opencode-workflow`:
  an unattended run that previously installed `@fission-ai/openspec` will stop
  and report unless the operator accepts or sets the opt-in. Both describe the
  current behaviour as deliberate in their own comments, so it should be
  reverted deliberately rather than quietly. This is not marked BREAKING at the
  spec level because this change edits no host repo — nothing breaks until a
  host adopts, and adoption is that host's own change.

Explicitly **not** in scope:

- **The curl-able bash installer** (originally framed as this change's whole
  subject). Four installers already exist; a fifth is construction, and
  `docs/PLAN-lightweight-fleet.md` says deletion beats construction. Recorded in
  Impact below so it is not lost again — it was lost once, which is why this
  change exists.

  Note what that deferral does **not** rest on. Step 4 asks whether `codex`,
  `opencode` and `pi` are worth keeping, and it is tempting to read this
  contract as contingent on the answer. It is not: more than one agent host is
  a settled constraint, so a cross-host consent contract is permanently
  load-bearing. What step 4 can change is *which* hosts exist, which is also why
  the contract is written against any installer rather than an enumerated four.
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
  `pi-agentic-apps-workflow/install.sh`. Two are non-conformant today on the
  unconsented `npm i -g`; all four gain the reporting obligation on their
  `~/.agenticapps/bin/` write, and all four gain the offer, which none of them
  makes.
- **Deferred, recorded so it is not lost a second time**: the curl-able bash
  installer. Its value tracks how many installers there are to replace, which
  `docs/PLAN-lightweight-fleet.md` step 4 may change — but the consent contract
  itself does not depend on that answer.
