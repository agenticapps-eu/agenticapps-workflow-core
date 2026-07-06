---
id: 15-knowledge-capture
section_type: declarative-contract
spec_version: 0.7.0
---

# 15 — Knowledge Capture

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below in their idiom. Prose, formatting,
skill naming, and the concrete wiring mechanism are at the host's
discretion. The keywords MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY
are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

This section is wired per **host** but activated per **repo**. A host
claiming conformance MUST ship the trigger wiring (15.1); a repo that
does not opt in via the configuration block (15.2) is skipped silently
(15.3) and both the host and the repo remain conformant. Conformance
checks live in §09.

## Intent

Transferable learnings currently die where they were made. A gotcha
whose root cause generalizes, a decision rationale with reusable
trade-offs, a tooling insight that made an agent fast or slow — today
these land in a per-repo `session-handoff.md`, get overwritten by the
next handoff, and never reach the next repo or the next host. ADRs and
CHANGELOGs capture repo-scoped facts by design; nothing captures the
cross-repo, cross-host lessons.

This section makes a cross-repo, human-readable memory a contract:
every host writes distilled learnings to **one note per repo** in the
operator's knowledge vault, at the same three ritual boundaries, under
the same note schema, so that a human can read and prune the memory
and any agent in any repo inherits it.

The architecture is the two-layer shape §10 established for
observability and ADR-0014 records: the normative contract lives in
this spec; each host ships its own generator/wiring in its own idiom;
and the repo stays self-contained because the destination path comes
from per-repo configuration, never from host skill logic (ADR-0017).

## Requirements

### 15.1 Trigger points

A conformant host implementation MUST attempt a knowledge-capture
write whenever it:

1. **writes a session handoff**,
2. **completes a plan**, or
3. **completes a phase**.

The write MUST be the final step of the ritual that triggered it,
executed after the handoff / plan / phase artifact itself is
committed. A failure of the knowledge-capture write MUST NOT fail,
block, or roll back the ritual — the artifact commit stands, and the
failure is reported as a single info/warning line.

### 15.2 Destination and per-repo configuration

The destination is **one note per repo**, named exactly after the repo
directory, inside the operator's vault. The reference deployment is:

```
~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/<repo-name>.md
```

The path MUST NOT be hardcoded in host skill logic. It MUST be read,
at trigger time, from the repo's planning configuration. A conformant
repo opts in by adding this block to `.planning/config.json`:

```json
"knowledge_capture": {
  "enabled": true,
  "note": "~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/<repo-name>.md"
}
```

- `enabled` — boolean. `false` disables capture for this repo without
  removing the block.
- `note` — absolute path (leading `~` MUST be expanded against the
  executing user's home directory) to this repo's single note.
  `<repo-name>` is written out literally per repo at configuration
  time — hosts do not substitute placeholders at runtime.

Reading the path from per-repo config keeps repos self-contained (a
host never embeds an operator's vault layout) and lets each machine
relocate or omit the vault without touching host code.

A host MUST write only to the configured note of the repo it is
running in. It MUST NOT create, modify, or delete any other file in
the destination folder or anywhere else in the vault (see 15.6).

### 15.3 Graceful skip

A host MUST skip the knowledge-capture write **silently** — at most
one informational line, no error, no ritual failure — when any of the
following holds:

- the `knowledge_capture` block is absent from `.planning/config.json`
  (or the file itself is absent),
- `enabled` is `false`, or
- the parent folder of the configured `note` path does not exist —
  the normal state on other machines, in CI, and in containers.

The host MUST NOT create the missing parent folder; an absent vault
means "not this machine", not "set up the vault".

### 15.4 Note schema

The note format is owned by the vault-side schema: the `CLAUDE.md`
that lives in the destination folder (reference deployment:
`~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/CLAUDE.md`)
is authoritative for hosts writing there. The rules below mirror that
schema (as of 2026-07-06) so this spec is self-contained; if the two
ever diverge, the vault-side schema wins for writes and this section
SHOULD be patched to match.

A note is created **from this template on first write** (MUST):

```markdown
---
type: agentic-learnings
repo: <repo-name>
path: ~/Sourcecode/<org>/<repo-name>
hosts: [<hosts that have written here>]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <repo-name> — Agentic Coding Learnings

## Key Learnings
- **<short title>** — one to three sentences. The transferable
  insight, not the status.

## Log
### YYYY-MM-DD — <handoff|plan|phase> — <short title> (<host>)
- learning 1
- learning 2
```

Write rules, per section:

- **`## Key Learnings` is curated.** On each write the host MUST
  reconcile the section: dedupe, merge related items, promote
  log entries that earned it, and demote or remove stale items. The
  target size is ~10–20 highest-value items. Each item is a bolded
  short title plus one to three sentences carrying the transferable
  insight, not the status.
- **`## Log` is append-only, newest first.** Existing entries MUST NOT
  be edited or deleted. New entries are prepended at the top of the
  section under a heading of exactly this shape:
  `### YYYY-MM-DD — <handoff|plan|phase> — <short title> (<host>)`,
  where the second field names the 15.1 trigger and `<host>` names the
  writing host implementation.
- The frontmatter `updated` field is set on every write; `hosts` lists
  each host that has written to the note.

### 15.5 Selectivity bar

Each triggered write contributes **1–5 learnings**. A learning
qualifies only if it is **transferable**: it would change how the same
agent, another agent, or another host works next time.

Qualifies:

- gotchas and root causes that generalize beyond the repo,
- decision rationale with reusable trade-offs,
- tooling and workflow insights (what made the agent fast or slow),
- patterns that worked or failed across hosts,
- wrong assumptions and what corrected them.

Does NOT qualify:

- status updates ("shipped PR #77"),
- restating the plan or the phase goal,
- repo-specific facts already captured in ADRs, handoffs, or
  CHANGELOGs,
- praise or filler.

If nothing clears the bar, the host MUST write nothing — no empty log
entries, no "no learnings this session" placeholders. A skipped write
at a trigger point is conformant; a padded one is not.

### 15.6 Vault safety

- The host MUST touch only the configured note. Everything else in the
  vault — other repos' notes, the folder's `CLAUDE.md`, sibling
  folders — is out of bounds.
- The note MUST NOT contain secrets, tokens, URLs with embedded
  credentials, or client-confidential data. Values of that kind are
  redacted before writing, per the same discipline §10.5 requires for
  event attributes.

## Examples

### Opted-in repo configuration (illustrative, not normative)

```json
{
  "knowledge_capture": {
    "enabled": true,
    "note": "~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/fx-signal-agent.md"
  }
}
```

### A conformant log entry (illustrative, not normative)

```markdown
### 2026-07-06 — phase — Wrapper flush races fire-and-forget emission (claude)
- SDK-level flush waits for the SDK's buffer, not for callers'
  in-flight goroutines; short-lived processes need an emission-layer
  drain before the SDK flush or events drop silently.
- A conformance baseline committed to the repo turns "did we regress?"
  into a diffable CI check instead of a re-audit.
```

Two items, both transferable; the phase's status ("shipped v0.3.2")
appears nowhere.

## Non-requirements

This section explicitly does NOT specify:

- The vault software. Obsidian is the reference deployment; the
  contract is a markdown note at a configured path.
- The wiring mechanism inside the host — a skill step, a hook, a
  subagent, a checklist item are all conformant if the 15.1 triggers
  fire.
- Synchronization of the vault across machines. The 15.3 skip rule
  exists precisely so unsynchronized machines stay conformant.
- The language of the insights (the vault-side schema permits German
  or English; English preferred).
- Any read path. Hosts MAY read the note for context at session start,
  but nothing here requires it.

## Conformance

A host implementation claiming conformance with this section MUST wire
all three 15.1 trigger points into its ritual instructions, MUST
resolve the destination exclusively from the repo's 15.2 configuration
block, MUST implement the 15.3 graceful skip, and — whenever it does
write — MUST honor the 15.4 schema, the 15.5 selectivity bar, and the
15.6 vault-safety rules. §09 names the three checks a conformance
review applies.

A repo without the `knowledge_capture` block is conformant-by-skip: no
delta declaration is required. A host with no session-handoff /
plan / phase rituals at all (e.g. a consumer-only artifact viewer per
§09) has no 15.1 trigger surface and is trivially conformant.
