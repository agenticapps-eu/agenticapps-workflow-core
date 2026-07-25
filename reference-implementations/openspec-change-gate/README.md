# openspec-change-gate — reference implementation

The normative implementation of [`spec/18-retargeted-change-gate.md`](../../spec/18-retargeted-change-gate.md).
Hosts **vendor this file**; they do not maintain their own.

| File | Purpose |
|---|---|
| `openspec-change-gate.sh` | The gate. Modes: hook (default), `--pre-commit`, `--ci`. Carries `# gate-version:` for installer arbitration. |
| `pre-commit` | Git hook wrapper — the floor that catches humans and non-hooked agents. Resolves the gate from `OPENSPEC_GATE`, or `OPENSPEC_CHANGE_GATE` as an alias. |
| `hooks/openspec-gate.ci.yml` | GitHub Actions workflow — the floor no local config can bypass. |

Conformance is executable, not prose:

```bash
tools/change-gate-conformance.sh reference-implementations/openspec-change-gate/openspec-change-gate.sh
tools/change-gate-conformance.sh --family     # score every host clone + the shared install
```

**Change behaviour here only alongside a matching harness row.** §18 requires the
gate be "demonstrable by direct script invocation with simulated payloads"; a row
is what makes that true.

## Exit codes

| Mode | Allow | Block |
|---|---|---|
| hook (default) | `0` | `2` (Claude PreToolUse convention) |
| `--pre-commit` | `0` | `1` |
| `--ci` | `0` | `1` |

Hook mode **fails open on a parse error** and never on policy. The distinction is
the whole design: an unparseable payload means the gate could not reason about
the call, so blocking would be guessing — and because the OpenSpec-artifact
exemption also never fires without a parsed path, it would block the write of
`proposal.md` itself, leaving a change that can never be authored, reviewed, or
unblocked. A missing review is not a parse error and always blocks.

## Environment

| Var | Effect |
|---|---|
| `GSD_SKIP_REVIEWS=1` | Documented escape hatch — bypasses the review clause. `validate` must still be green (see *Deviations*). |
| `OPENSPEC_GATE_STRICT=1` | Also block edits when there is *no* active change ("no code without a change"). |
| `MIN_REVIEWERS` | Reviewer threshold. Default `2`. |
| `OPENSPEC_BIN` | `openspec` CLI name/path. Lets the harness stub `validate` and test the gate hermetically. |
| `OPENSPEC_GATE_SELF` | Name of the implementing host; its own reviews do not count toward the threshold. |

## Vendoring into a host

1. Copy `openspec-change-gate.sh` to the host's `bin/`. Do not edit it — a
   host-local fix is how the copies diverged in the first place (issue #32).
2. **Copy `tools/change-gate-conformance.sh` too.** The CI workflow runs it
   against the vendored gate, and without it that step fails with
   `No such file or directory` — silently removing the check that exists to
   catch drift. Keep the two in sync: a stale harness certifies a stale gate.
3. Wire the host's `PreToolUse` (or equivalent) interposition point to pipe its
   tool-call payload to the script on stdin and act on the exit code.
4. Install `pre-commit` and the CI workflow. **A hook-only build is not
   conformant** — §18 makes the shell script the real enforcement surface,
   "including against a human editor", and a `PreToolUse` hook cannot gate the
   session that installed it.
5. Set `OPENSPEC_GATE_SELF` to the host's name so its own reviews are excluded.
   Scope it to the gate's own invocation — **do not export it job-wide.** Step 7
   runs in the same environment, and the harness measures a gate that must not
   see it (see the note there).
6. **Teach the host's installer to honour `# gate-version:`.** Every host writes
   to the shared `~/.agenticapps/bin/openspec-change-gate.sh`, so without
   arbitration it is last-writer-wins: a host still vendoring an older copy
   silently republishes it over a newer one and reverts the fix for every agent
   on the machine. Installers MUST compare the incoming marker against the
   installed one and refuse to downgrade (treat an unmarked file as `0.0.0`).
   `claude-workflow`'s `install.sh` is the worked example.
7. Run the harness. Report the result in the host's adoption PR. The harness
   `unset`s `OPENSPEC_GATE_SELF` itself, so an ambient value is harmless — but
   if you are scoring an older vendored harness that predates that, run it as
   `env -u OPENSPEC_GATE_SELF tools/change-gate-conformance.sh <gate>`. Use
   `env -u`, not `OPENSPEC_GATE_SELF=`: set-but-empty and unset differ for a
   `set -u` consumer that reads the variable without a `:-` default. A
   conformant gate scores one row short with the value leaked in — the
   two-reviewer row seeds `claude` and `codex`, so `=codex` correctly drops one
   and leaves a block.

If a host genuinely needs different behaviour, change it **here** and add a
harness row, then re-vendor. That is the point of this directory.

## Payload shapes

`edited_path_from_stdin` knows Claude Code, pi, opencode, a generic JSON-RPC
shape, and a bare fallback. A key it does not know yields an empty path, which
fails open — the gate then **silently stops enforcing** on that host, which is
exactly how the pi defect in #32 went unnoticed.

Paths arrive **absolute** from most hosts — Claude Code always sends an absolute
`file_path`. The `openspec/` exemption therefore resolves both the payload path
and `$ROOT` to their physical forms before comparing: `$ROOT` comes from `git
rev-parse --show-toplevel`, which resolves symlinks, so a repo reached through a
symlink would otherwise fail a plain string-prefix test and block the write of
`proposal.md` itself (fixed in 1.2.1). The final path component is never
resolved — it usually does not exist yet.

Adding a host means adding its key *and* a section-B harness row. Note that a B
row must drive a **code** edit, not an artifact write: under fail-open an
artifact write exits `0` whether or not the parser ever ran, so it certifies
nothing. The harness reports section B as inconclusive against a gate that fails
closed, for the same reason.

## Deviations from §18's truth table

One, deliberate and pinned by a harness row:

**`GSD_SKIP_REVIEWS` is applied after the validate check.** §18's row reads
unconditionally ("escape hatch set → allow"), but here `validate` red plus the
hatch still blocks. The hatch exists to bypass the *review* clause in an
emergency, not to ship a change whose spec delta does not parse. A host that
prefers the literal reading should change it here and flip the row, not diverge
locally.

Related asymmetry, worth knowing: a **missing `openspec` CLI blocks** (exit 2 —
an unvalidatable change must not pass), while a **missing gate in the
`pre-commit` wrapper allows** (exit 0 with a warning). Different postures on
"tooling absent" because the consequences differ: the first is a policy question
the gate cannot answer, the second is a commit hook that would otherwise train
people to reach for `--no-verify` and disable the floor permanently.

## Known constraint

`OPENSPEC_GATE_SELF` is interpolated into an awk regex, so a host name carrying
regex metacharacters will not anchor as written. Host names are bare tokens
(`pi`, `claude`, `codex`, `opencode`); this is documented, not guarded.
