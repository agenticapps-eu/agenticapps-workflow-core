## Context

Four host repos each ship an `install.sh`. They agree on detecting
prerequisites and disagree on what to do next.

| Installer | Prerequisites checked | On a missing `openspec` |
|---|---|---|
| `claude-workflow` | `openspec` | prints `npm i -g …`, never installs |
| `codex-workflow` | `codex`, `npm`, `openspec` | `npm i -g` automatically, no consent |
| `opencode-workflow` | `opencode`, `npm`, `openspec` | `npm i -g` automatically, no consent |
| `pi-agentic-apps-workflow` | `openspec`, `pi` | prints `npm i -g …`, never installs |

The auto-installing pair say so on purpose. `opencode-workflow/install.sh`:
"openspec is the front end's core dependency — auto-install it (like the old
`npx gsd-opencode` bind) rather than only instructing." That is a considered
position, not an oversight, which is why this change has to argue with it
rather than treat it as a bug to quietly repair.

None of the four prompts for consent. The single construct that pattern-matched
a confirmation, in `codex-workflow/install.sh`, is post-install advice about
trusting a hook and gates nothing.

Two constraints shape the work, both inherited. Core owns the contract but not
the installers — they live in four separate repos — and core already has the
mechanism for exactly that: a `tools/*-conformance.sh` harness a host runs
against its own artifact. And `docs/PLAN-lightweight-fleet.md` says deletion
beats construction, and that new machinery waits on the step-4 question of
whether `codex`, `opencode` and `pi` are worth keeping at all.

## Goals / Non-Goals

**Goals:**

- One answer to "may an installer install things on my machine", stated once.
- Unattended installation stays possible, with the decision visible at the call
  site rather than buried in the installer.
- The contract is machine-checkable by a host repo without core executing it.
- Nothing new is built that step 4 might delete.

**Non-Goals:**

- The curl-able bash installer. See Decisions.
- Editing the four host installers. This change defines what they satisfy.
- Prescribing each host's dependency list. `codex` needing `codex` and `pi`
  needing `pi` is legitimate host-specific variation; only the consent
  behaviour is shared.
- Consent for repository-local writes. Running an installer against a repo is
  the request to change that repo.

## Decisions

**The boundary is the target repository, not the file count.** Consent attaches
to writes that outlive and outrange the operator's request — a global npm
package, `~/.agenticapps/bin/`, a host's global config — and not to
provisioning the repository they pointed the installer at. The alternative
boundaries are worse in both directions: prompting per repo-local file makes the
installer unusable, and prompting only for "large" installs needs a size rule
nobody can state. *Alternative considered:* consent for anything the installer
did not create in this run. Rejected — that catches idempotent re-provisioning
of files the installer itself wrote last time, which is the normal case.

**A non-interactive run reports and stops rather than picking a default.** The
tempting defaults are "install anyway" (today's codex/opencode behaviour, which
is the defect) and "assume declined and continue" (which exits 0 having done
less than the operator thinks). Both convert an absent decision into a silent
one. This is the same rule §20 settled for an unscoreable target: an
unanswerable question is reported, never answered by assumption. *Alternative
considered:* treat non-interactive as implied consent, on the grounds that CI
wants the tool installed. Rejected — that is precisely the current behaviour,
and CI is where an unreviewed global install is least visible.

**An explicit flag substitutes for the prompt.** Without one, requiring consent
would make unattended installs impossible and invite exactly the fork that skips
the check. With one, the decision is recorded at the call site where it can be
read in a CI config or a shell history, rather than inside a script where it
cannot. The flag's absence is never acceptance — otherwise the flag would be
decoration.

**Core binds this with a conformance harness, not by editing the installers.**
The established shape, and the same reasoning as `host-neutral-agents-md`: core
cannot land a coordinated four-repo change without the PR train
`PLAN-lightweight-fleet` principle 2 forbids, and a contract stated in prose
alone has already drifted undetected in this repo more than once.

**Scoring an installer is harder than scoring a file, and the harness must not
pretend otherwise.** Consent behaviour is only fully observable by running the
installer, and running four hosts' installers is not something core can do
safely — they write to the operator's machine, which is the very thing under
discussion. So the harness scores what is statically checkable (does the script
install outside the repo; is that install reachable without a flag or a prompt)
and reports the rest as inconclusive rather than passing it. A row that cannot
be scored is reported inconclusive per §20, never green. *Alternative
considered:* run each installer in a container. Better fidelity, but it makes
core's CI depend on four external repos being checked out, and the failure mode
— a host repo absent, so the row silently does not run — is the one §20 exists
to prevent.

**The curl-able installer is deferred, not dropped.** This change was originally
framed as building it. Four installers already exist; a fifth is construction,
and `PLAN-lightweight-fleet` says not to build before step 3 and that everything
waits on step 4 — whether `codex`, `opencode` and `pi` are live. If they are
archived, three of the four installers disappear and a curl-able one has almost
nothing left to install. The consent defect is live today regardless of that
answer, so it is separated and done first. Recorded in the proposal's Impact so
it is not lost a second time — it was lost once already, which is why this
change exists.

## Risks / Trade-offs

**This is a breaking behaviour change for two hosts, and their comments say the
current behaviour is deliberate.** → It should break loudly rather than be
quietly reverted. The opt-in flag preserves every unattended workflow that
actually wants the install; what stops working is the case where nobody chose.

**The contract is unenforced until each host adopts it.** → The harness makes
non-adoption visible per host, so adoption sequences instead of coordinating.
Two hosts are non-conformant today and will report as such the day they run it.

**Static scoring cannot see everything.** A script could obtain consent in a way
the harness does not recognise, or bypass it through an indirection. → Rows the
harness cannot decide report inconclusive, and inconclusive is excluded from the
scored total, so a host cannot reach a passing total on rows nobody scored.

**This may be work on a host being deleted.** → It is a spec section plus one
harness, no new runtime machinery, and the spec section survives host archival
because `claude-workflow`'s installer is subject to it too.

## Migration Plan

1. The spec section lands; core ships the harness; core's CI scores
   `tools/install-core-git-hooks.sh`, the one installer that is core's own.
2. Each host repo runs the harness and adopts on its own schedule.
3. `codex-workflow` and `opencode-workflow` gain the prompt and the opt-in flag.
   Their current auto-install becomes the flag's behaviour, so the capability is
   preserved and only the default changes.
4. `claude-workflow` and `pi-agentic-apps-workflow` gain the offer, which they
   do not have today — they only instruct.

Rollback is deleting the harness and reverting the spec section; no downstream
repo depends on this until it adopts.

## Open Questions

- **Which prerequisites warrant an offer at all.** Offering to install `npm` or
  a host CLI is a much larger imposition than offering to install one global npm
  package, and the contract currently treats them alike.
- **Whether `~/.agenticapps/bin/` is inside or outside the boundary.** It is
  outside the target repo by the rule as written, so writing the shared gate
  would require consent — but `PLAN-lightweight-fleet` step 2 makes that write
  the primary publishing mechanism, and prompting on it every time would be
  friction against the one thing that repo wants to be cheap.
- **Whether step 4's answer changes this change's value.** If three hosts are
  archived, this reduces to a contract over `claude-workflow`'s installer and
  core's own, which is still worth stating but is a much smaller claim.
