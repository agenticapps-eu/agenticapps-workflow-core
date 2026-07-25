# openspec-change-gate — reference implementation

The normative implementation of [`spec/18-retargeted-change-gate.md`](../../spec/18-retargeted-change-gate.md).
Hosts **vendor this file**; they do not maintain their own.

| File | Purpose |
|---|---|
| `openspec-change-gate.sh` | The gate. Modes: hook (default), `--pre-commit`, `--ci`. |
| `pre-commit` | Git hook wrapper — the floor that catches humans and non-hooked agents. |
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
| `GSD_SKIP_REVIEWS=1` | Documented escape hatch — bypasses the review clause. `validate` must still be green. |
| `OPENSPEC_GATE_STRICT=1` | Also block edits when there is *no* active change ("no code without a change"). |
| `MIN_REVIEWERS` | Reviewer threshold. Default `2`. |
| `OPENSPEC_BIN` | `openspec` CLI name/path. Lets the harness stub `validate` and test the gate hermetically. |
| `OPENSPEC_GATE_SELF` | Name of the implementing host; its own reviews do not count toward the threshold. |

## Vendoring into a host

1. Copy `openspec-change-gate.sh` to the host's `bin/`. Do not edit it — a
   host-local fix is how the copies diverged in the first place (issue #32).
2. Wire the host's `PreToolUse` (or equivalent) interposition point to pipe its
   tool-call payload to the script on stdin and act on the exit code.
3. Install `pre-commit` and the CI workflow. **A hook-only build is not
   conformant** — §18 makes the shell script the real enforcement surface,
   "including against a human editor", and a `PreToolUse` hook cannot gate the
   session that installed it.
4. Set `OPENSPEC_GATE_SELF` to the host's name so its own reviews are excluded.
5. Run the harness. Report the result in the host's adoption PR.

If a host genuinely needs different behaviour, change it **here** and add a
harness row, then re-vendor. That is the point of this directory.

## Payload shapes

`edited_path_from_stdin` knows Claude Code, pi, opencode, a generic JSON-RPC
shape, and a bare fallback. A key it does not know yields an empty path, which
fails open — the gate then **silently stops enforcing** on that host, which is
exactly how the pi defect in #32 went unnoticed.

Adding a host means adding its key *and* a section-B harness row. Note that a B
row must drive a **code** edit, not an artifact write: under fail-open an
artifact write exits `0` whether or not the parser ever ran, so it certifies
nothing. The harness reports section B as inconclusive against a gate that fails
closed, for the same reason.

## Known constraint

`OPENSPEC_GATE_SELF` is interpolated into an awk regex, so a host name carrying
regex metacharacters will not anchor as written. Host names are bare tokens
(`pi`, `claude`, `codex`, `opencode`); this is documented, not guarded.
