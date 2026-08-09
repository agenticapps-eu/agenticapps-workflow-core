# Gate skills resolve on every host — measured 2026-08-09

A change was proposed, reviewed and closed in one session on the finding
recorded here. No code was written. This file exists so the next reader measures
at the right layer instead of repeating the mistake.

## The claim that was wrong

After gstack was reinstalled natively on claude, codex and opencode, the four
gate skills the workflow names — `cso`, `qa`, `impeccable`, `database-sentinel` —
were reported as resolving **on claude only**.

That measurement was:

```sh
[ -e "$host_skills_dir/$name/SKILL.md" ]
```

It tests the **directory basename**. Both codex and opencode key skill identity
on the **declared frontmatter name**. The directories are named
`gstack-qa`, `codex-impeccable-audit` and so on; the names they declare are
`qa` and `impeccable`. So the test reported MISSING for four skills that were
present and reachable the whole time.

## The correct measurement

```sh
grep -lm1 "^name: $skill\$" "$host_skills_dir"/*/SKILL.md
```

| Gate | codex — declaring directory | opencode — declaring directory |
|---|---|---|
| `cso` | `gstack-cso` | `gstack-cso` |
| `qa` | `gstack-qa` | `gstack-qa` |
| `impeccable` | `codex-impeccable-audit` | `opencode-impeccable-audit` |
| `database-sentinel` | `codex-database-sentinel-audit` | `opencode-database-sentinel-audit` |

Confirmed first-hand rather than inferred, by probing a live codex session:

```
cso: YES /Users/donald/.claude/skills/gstack/.agents/skills/gstack-cso
qa: YES /Users/donald/.claude/skills/gstack/.agents/skills/gstack-qa
impeccable: YES /Users/donald/.agents/skills/impeccable
database-sentinel: YES /Users/donald/.claude/skills/database-sentinel
LOADER-KEY: frontmatter-name
```

**The gate table resolves on every installed host, and always did.** It needs no
prefixed-name fallback, no additional binding, and no installer budget raise.

## What follows

- **A directory name is not a skill name.** Any sweep, gate check or inventory
  that enumerates directories is measuring packaging, not identity. This is the
  same shape as the recorded lesson that sweeps see symlinks rather than
  directories: the cheap enumeration answers a question next to the one asked.
- **The `*-impeccable-audit` alias must not be deleted.** On codex and opencode
  it is the *sole* provider of the canonical name `impeccable`. It looks like
  legacy vendoring and is load-bearing.

  > **`database-sentinel` was removed entirely later the same day, by operator
  > decision.** The measurement above is left as recorded because it was true
  > when taken, but the skill checkout and both `*-database-sentinel-audit`
  > aliases are gone from every host, and no host declares that name now. So the
  > "must not be deleted" caution applies to `impeccable` only. A prior session
  > handoff claimed the *skill* was a live gate that stays while only the *hook*
  > was retired; that was wrong, and both are now gone.
- **The six gstack-derived prefixed links removed on 2026-08-09 were genuine
  duplicates** — `codex-cso` and `gstack-cso` both declared `cso` on the same
  host. That removal stands; it deduplicated rather than deleted.

## The one real gap this surfaced

Nothing in core *guarantees* `impeccable` stays bound to codex and opencode. It
persists only because `install.sh`'s `sweep_vendored` rebound an archived
host-installer link to a live source. `bind_dir` iterates `$ROOT/skills/*` and
`$UPSTREAM/skills/*`, and the skill is in neither — so if that alias is ever
deleted, no installer run recreates it and the design gate silently loses its
skill on two hosts.

The gap was originally written up for two skills. `database-sentinel` has since
been removed deliberately, which closes its half by subtraction rather than by
fixing anything: the gate now names a skill that exists nowhere, which is a
different problem and is tracked with the gate's removal.

The `impeccable` fragility is real and **not fixed**. It needs its own change,
sized against the installer's line budget (216 of 217 as of this date — the
budget clause's "measures 210, leaving 7" is stale).

## Review record

Both reviewers returned REQUEST-CHANGES; neither is this host's vendor.

- **codex (gpt-5.6-sol)** found it: *"the diagnosis confuses directory basename
  with skill identity … the claimed missing lookup is unproven and likely
  measured at the wrong layer."* It also caught, correctly, that the design's
  claim that the legacy audit links had been deleted was false.
- **gemini** independently objected that a `*-<name>` glob is too permissive
  (`notes-qa` would match) and that prose-defined resolution is untestable. Both
  are moot with the fallback gone, and both would have been right had it shipped.

Prompt sha256: `c8644faa26198962d1505fd3b1e8ee0b1cd34f9e1a68419c7d20ff821f16274f`

The step-2b review paid for itself here: two reviewer calls, no implementation,
a change closed before a line of code existed.
