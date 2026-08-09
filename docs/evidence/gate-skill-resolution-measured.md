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
- **The `*-impeccable-audit` and `*-database-sentinel-audit` aliases must not be
  deleted.** On codex and opencode they are the *sole* providers of those two
  canonical names. They look like legacy vendoring and are load-bearing.
- **The six gstack-derived prefixed links removed on 2026-08-09 were genuine
  duplicates** — `codex-cso` and `gstack-cso` both declared `cso` on the same
  host. That removal stands; it deduplicated rather than deleted.

## The one real gap this surfaced

Nothing in core *guarantees* `impeccable` and `database-sentinel` stay bound to
codex and opencode. They persist only because `install.sh`'s `sweep_vendored`
rebound the archived host-installer links to live sources. `bind_dir` iterates
`$ROOT/skills/*` and `$UPSTREAM/skills/*`, and neither skill is in either — so
if those aliases are ever deleted, no installer run recreates them and two gates
silently lose their skill on two hosts.

That is a real fragility and it is **not fixed**. It needs its own change, sized
against the installer's line budget (216 of 217 as of this date — the budget
clause's "measures 210, leaving 7" is stale).

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
