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

**The boundary is ownership, not location.** Consent attaches to writes that can
change software the workflow does not own — a third-party package manager's
global namespace, a host's global configuration — and not to provisioning the
repository the operator pointed the installer at, nor to the workflow's own
shared directory.

This is a correction. The first draft of this design drew the line at "outside
the target repository", and the first plan review found what that costs: all
four installers write the shared change-gate and reviewer-cli into
`~/.agenticapps/bin/` unconditionally (`claude-workflow:149`,
`codex-workflow:211`, `opencode-workflow:329`,
`pi-agentic-apps-workflow:148`). The location rule therefore condemned all four
rather than the two with the actual defect, and put a prompt in front of the
mechanism `PLAN-lightweight-fleet` step 2 designates as the primary way core
publishes an artifact — friction against the one operation that document wants
to stay cheap. The proposal, design and migration plan all said "two". They were
wrong on their own rule.

The ownership test is: *could this write change software the operator did not
install by running this installer?* `~/.agenticapps/bin/openspec-change-gate.sh`
cannot — nothing else on the machine uses it, and installing the workflow is
what the operator asked for. `npm i -g @fission-ai/openspec` can: it mutates a
shared namespace and may upgrade or replace a package other projects resolve.
That is a real difference in kind, not a carve-out for convenience.

The workflow's own directory is still **reported**, so the exemption does not
make the write invisible — which is what would turn a principled boundary into
a loophole.

*Alternatives considered:* consent for everything outside the repo — the
original rule, rejected above on evidence. Consent only for "large" installs —
needs a size rule nobody can state. Consent for anything the installer did not
create in this run — catches idempotent re-provisioning of files the installer
itself wrote last time, which is the normal case.

**A non-interactive run reports and stops rather than picking a default.** The
tempting defaults are "install anyway" (today's codex/opencode behaviour, which
is the defect) and "assume declined and continue" (which exits 0 having done
less than the operator thinks). Both convert an absent decision into a silent
one. This is the same rule §20 settled for an unscoreable target: an
unanswerable question is reported, never answered by assumption. *Alternative
considered:* treat non-interactive as implied consent, on the grounds that CI
wants the tool installed. Rejected — that is precisely the current behaviour,
and CI is where an unreviewed global install is least visible.

**An explicit flag substitutes for the prompt, and the spec names it.** Without
one, requiring consent would make unattended installs impossible and invite
exactly the fork that skips the check. With one, the decision is recorded at the
call site where it can be read in a CI config or a shell history, rather than
inside a script where it cannot. The flag's absence is never acceptance —
otherwise the flag would be decoration.

Leaving the *name* open, as the first draft did, would have produced four
spellings across four hosts and defeated the "one answer stated once" goal this
change is for. It would also make the non-interactive report unscoreable, since
that report has to name the flag that authorises the install. Fixed as
`AGENTICAPPS_INSTALL_PREREQS=1` / `--install-prereqs`. The obligation to accept
it is scoped to installers that can actually perform such an install, so a
detect-and-instruct installer is not required to advertise a capability it does
not have.

**Consent has a stated shape, not just a stated requirement.** Terminal input,
explicit affirmative only, empty and unrecognised and EOF all decline, one
prompt per install command. Left open, four hosts would ship four prompts with
four defaults — the divergence this contract exists to remove, reintroduced one
level down. Defaulting to no is the direction that fails safe: a declined
install is recoverable by re-running, an unwanted global install is not.

**Removal is not the mirror of installation — nothing installed on the
operator's behalf is taken away.** The ownership test runs in both directions.
A global package the operator accepted may, by the time the workflow is
removed, be resolved by projects this workflow never touched; uninstalling it
would change software the workflow does not own, which is the act consent
exists to prevent. So the uninstaller leaves it and reports what it left,
naming the command that removes it — the same reporting obligation that keeps
the `~/.agenticapps/bin/` exemption from making a write invisible.

*Alternative considered:* offer to remove it, with the same prompt shape as the
install. Symmetric, and rejected on the same grounds the blanket prompt was: it
asks about the outcome the operator almost always wants, and buys that symmetry
with a second consent surface to state, to implement four times, and to score.

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
   Their current auto-install becomes the opt-in's behaviour, so the capability
   is preserved and only the default changes.
4. `claude-workflow` and `pi-agentic-apps-workflow` gain the offer, which they
   do not have today — they only instruct.
5. All four gain the reporting obligation on their `~/.agenticapps/bin/` write.
   No prompt, no behaviour change — they must say what they wrote there. This is
   the step the "two hosts are affected" framing missed entirely: every
   installer is touched by this contract, just not all in the same way.

Rollback is deleting the harness and reverting the spec section; no downstream
repo depends on this until it adopts.

## Open Questions

The `~/.agenticapps/bin/` boundary, which the first plan review found was an
open question the delta had already made normative, is answered above: it is the
workflow's own directory, so it is reported rather than prompted.

Step 4's answer is **not** an open question for this change, though the first
draft treated it as one. More than one agent host is a settled constraint — only
which hosts is open — so a cross-host consent contract is permanently
load-bearing rather than contingent on a fleet that might collapse to one. That
is also why the contract is written against "an installer" rather than an
enumerated four.

Remaining, and genuinely open:

- **Which prerequisites warrant an offer at all.** Offering to install `npm` or
  a host CLI is a much larger imposition than one global npm package, and
  installing a system runtime is platform-dependent in a way a shell script
  handles badly. The contract currently treats them alike, and probably should
  not — the likely answer is that runtimes are detected and instructed, never
  offered.
- **How a harness recognises consent statically.** It can find an install
  command and look for a guard, but a script could obtain acceptance in a shape
  the harness does not recognise, or reach the install through an indirection.
  Rows that cannot be decided report inconclusive, so this bounds what the
  harness can claim rather than what the contract requires.
Uninstall was on this list and is now answered under Decisions: a prerequisite
installed on the operator's behalf is never removed automatically, and what is
left behind is reported.
