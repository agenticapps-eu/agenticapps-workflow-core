## Why

The workflow enforces itself at three surfaces: a host hook before an Edit/Write
tool call, a git `pre-commit` hook, and CI. Only one of the three is
host-specific, and it is the weakest of the three.

Three measurements make the case, and all three were taken on this machine
rather than reasoned about:

**The host hook does not enforce what people think it enforces.** With no active
change, `gate_check` returns 0 and edits proceed — the permissive default
(`openspec-change-gate.sh:506`). So the hook does not stop code being written
without a spec. It stops code being written while an *open* change's delta fails
to parse, and `pre-commit` and CI catch that same condition anyway. Its only
unique contribution is latency: it says so now rather than at commit.

**The gate's own git hook argues it is not the floor.** Its header states the
case against itself: a `PreToolUse` hook "is loaded at session start and cannot
gate the session that installed it, and it does not exist at all for a human
with an editor."

**The host hook was where nearly all host-specific cost sat.** 27 of the
installer's then-250 executable lines, all 293 lines of `hosts/`, one of the two
consent flags, the `jq` dependency, and three implementations to keep in step.
That argument was accepted and acted on in `core-installer-one-entry-point`,
which was narrowed to remove the wiring before it ever ran; the repository now
contains no host-named code. It is restated here because it is half of why the
floor should move: with the host hook gone, the git hook is no longer one
surface among three, it is the surface.

Separately, the per-repository git hook has already produced the divergence it
exists to prevent. Measured 2026-08-07: eleven repositories carry a `pre-commit`,
over ten distinct hooks directories. Nine of those are this gate, in **four
different sizes** — 1201, 1376, 2270 and 5844 bytes. One authority, nine copies,
four versions, and nothing on the machine reports the divergence.

The tenth is `fbc-platform`'s husky installation, which matters to the design
rather than to this argument and is treated in `design.md`.

And the divergence is not the worst of it. `cparx` carries **no `pre-commit` at
all**, `core.hooksPath` unset both globally and locally — so the repository the
fleet work is measured against has no git floor whatsoever. A per-repository
install does not merely diverge; it silently omits.

Linear issue: none yet.

## What Changes

- **CHANGED: the git floor becomes global.** The gate's `pre-commit` is
  published once to a machine-level hooks directory bound by
  `git config --global core.hooksPath`, rather than copied into each
  repository's `.git/hooks/`. One file, every repository, no divergence
  possible.
- **REMOVED: `--project`.** The deferred follow-up is dropped rather than
  built. With behaviour in the trigger skill and the floor global, what
  remained for it to install was a per-repository copy of a hook that is now
  machine-level.
- **ADDED: the redundant local bindings are swept.** Six repositories already
  set a local `core.hooksPath`, which git prefers over the global one, so the
  new floor would not reach them. Five name the directory git would resolve
  anyway and are unset — which is how those five come under the floor, not a
  tidy-up beside it. The unset changes nothing only while no global binding
  exists; the moment one does, it is the act that hands the repository over.
  `fbc-platform`'s `.husky/_` is a real opt-out and is left alone.
- **CHANGED: `--check` reports the global binding** — whether
  `core.hooksPath` is set, whether it points at the published directory, and
  whether the published `pre-commit` is current by content.
- The installer keeps: publishing the payload, binding skills by symlink,
  removing legacy and archived bindings, and `--check`. Those are unaffected.

## What this change deliberately does not do

**It does not remove the shim mechanism or `project-hook-binding`.** That
capability governs every fleet-shared hook, not only the gate;
`database-sentinel` is shimmed too. A global `core.hooksPath` changes where the
gate's `pre-commit` lives, not whether a repository may compose additional
hooks. Collapsing that capability is a separate argument on separate evidence.

**It does not move the §11 coding discipline or the workflow rules out of
`~/.claude/CLAUDE.md`.** That is a prerequisite for the claim that "nothing
host-specific remains", and it is its own change with its own risk: deleting a
rule that has no other home deletes the rule.

**It does not settle whether a project still needs a workflow section in
`AGENTS.md`.** `host-neutral-instruction-files` requires exactly one whenever an
agent is provisioned, on the grounds that a repo listing an agent and carrying
no section is "pointed at a workflow the file does not describe". If the trigger
skill carries the workflow globally, that premise weakens. It is not resolved
here because it is a different question about a different capability, and
answering it by implication is how a requirement gets repealed without anyone
deciding to repeal it. Recorded in `design.md` as the change this one most
likely spawns.

## Sequencing — the blocker is cleared

`workflow-installation` did not exist in `openspec/specs/` when this change was
written, so a `MODIFIED` delta had nothing to modify and this change was blocked
on `core-installer-one-entry-point` being archived.

**That happened on 2026-08-06.** The predecessor is in
`openspec/changes/archive/2026-08-06-core-installer-one-entry-point/` and
`openspec/specs/workflow-installation/spec.md` is durable truth. The delta here
now has something to modify, and this change is first in the chain — it must
land before `projects-bind-not-copy`, which removes `cparx`'s `PreToolUse`
entry and would otherwise leave it with no gate at all rather than a better one.

**The host wiring is no longer this change's to remove.** It was going to be —
and the plan was to run the installer first, wire three hosts, then delete the
wiring one change later. That was rejected: it ships a release whose installer
edits configuration files the next release un-edits. The wiring was instead
stripped from the predecessor before it ever ran, so this change inherits an
installer that already writes no host configuration and only has to move the
floor.

What remains sequenced is ordinary: archive the predecessor, then apply this.

## Impact

- Affected capabilities: `workflow-installation` (delta here) and
  **`core-self-enforcement`, which this change modifies and must carry its own
  delta**. ADR-0028 has core's interposition points resolve the *working-tree*
  gate and states the shared install "SHALL NOT be consulted"; one hook
  published machine-wide cannot satisfy that. Worse, `tools/install-core-git-hooks.sh`
  resolves its destination with `git rev-parse --git-path hooks`, which honors
  `core.hooksPath` — so once the binding is global that installer writes into
  the machine-level directory, and either refuses permanently on a foreign
  marker or publishes core's working-tree-resolving hook to every repository on
  the machine. **That delta now exists** at
  `specs/core-self-enforcement/spec.md`: the inversion is kept, core sets a
  local `core.hooksPath` that git prefers over the global binding, the
  installer refuses when the resolver returns the machine-level directory, and
  core's binding is declared so the sweep cannot mistake it for redundant.
- `change-gate-enforcement` and `project-hook-binding` are read but not
  modified — see `design.md` for why each survives untouched.
- Affected code: `install.sh`, `tools/install.test.sh`,
  `tools/install-core-git-hooks.sh`, `reference-implementations/openspec-change-gate/pre-commit`.
- **BREAKING** for any machine relying on a per-repository hook install. The
  nine existing copies are superseded by the global binding, not orphaned — the
  global path serves them all.
