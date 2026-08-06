# Session Handoff — 2026-08-06 (eighth session)

**Next action: the real install run.** It is smaller and safer than it was this
morning, because the installer no longer touches host configuration at all.
Command and expectations at the bottom. Nothing is blocked.

Branch `feat/one-skills-payload`, five commits this session, all green.

## Accomplished

- **Round 3 reviews** (`b707a5f`) — gemini APPROVE, codex REQUEST-CHANGES. Two
  findings verified against the code and fixed (`1bbe826`):
  - `preserve()` wrote skill backups *inside* the directory the host scans, so
    removing the duplicate trigger skill left `agenticapps-workflow.pre-install.1`
    carrying `skill/SKILL.md`. A loader that deep-scans nested `SKILL.md`
    re-registers it — the run would delete one duplicate and create another.
    Backups now mirror to `~/.agenticapps/pre-install/`. Test 6.1b is a proven
    negative test: without the fix it fails naming the leftover.
  - The claim that the first run drops the stale `normalize-claude-md.sh`
    manifest row is **false**. `install-project-hooks.sh:216` re-emits every row
    outside the declared set by design.
- **The change was narrowed** (`cc37fe5`): host hook wiring removed *before* the
  installer was ever run. `install.sh` 250 → 210 executable lines, `hosts/`
  deleted, tests 58 → 46.
- **`one-enforcement-floor` proposed** (`4fc06cc`) — the successor: move the git
  floor to a machine-level `core.hooksPath`, drop `--project`. Plus
  `docs/HOW-IT-FITS-TOGETHER.md`, the topology doc under `docs/WORKFLOW.md`.
- **Round 4 reviews** — both REQUEST-CHANGES, both correct; fixed in `87d1448`.
  See Decisions.

## Decisions

- **Host hooks are dropped.** Three measurements: `gate_check` returns satisfied
  with no active change (`openspec-change-gate.sh:506`), so the hook never
  enforced spec-before-code; the condition it *did* enforce is caught again at
  `git commit` and in CI; and it was every host-specific line in the repo — 27
  in `install.sh`, 293 in `hosts/`, one consent flag, and `jq`. The gate's own
  `pre-commit` header argues the same: a PreToolUse hook "cannot gate the
  session that installed it, and it does not exist at all for a human with an
  editor." What is lost is in-session latency, nothing else.
- **Narrow, don't ship-then-delete.** Donald's call, and it was right. The
  original plan was to run the installer without the config opt-in and delete
  the wiring in the successor. That ships a release whose installer edits config
  files the next release un-edits, and puts 320 known-dead lines in `main`.
- **The git floor goes global** — `git config --global core.hooksPath`. Nine
  repos on this machine carry the gate at **four different byte sizes** (883,
  1201, 2270, 5844). Verified the displacement risk is empty: those nine are the
  only non-sample hooks on the machine, all of them this gate, no husky or
  lefthook. Also verified that `core.hooksPath` wins and `.git/hooks/` is
  ignored silently — I had this backwards first.
- **`--project` is dropped, not deferred.** With the floor machine-wide there is
  no per-repo hook left for it to install. **This releases the Phase 5b
  sequencing constraint**, and the codex adapter and opencode plugin blockers
  are gone with `hosts/`.
- **Budget is 217, not 228.** gemini caught the arithmetic. Reversing only the
  two wiring items of the 200→250 raise gave 228, but the measured removal was
  40 lines — 18 of them predated the raise. 200 − 18 + 35 = 217. Implementation
  is 210; headroom 7, deliberately tight.
- **The equivalence derivation is now normative** (strip host prefix, strip
  `-audit`, candidate must exist and not itself be archived, remove rather than
  widen). Flagged three times across two vendors. The objection that
  `codex-impeccable-audit → impeccable` is a name transformation and not a
  capability comparison is **correct** and accepted on stated bounds, not waved
  off. An explicit reviewed mapping is the right answer if a mis-rebind is ever
  observed.

## Files modified

- `install.sh` — wiring removed; 210 executable lines
- `hosts/` — deleted
- `tools/install.test.sh` — 46 cases; new 4.1/4.2/4.3 assert the *files*, not the
  absence of the functions. `host_exec` moved to the scaffolding after three
  cases passed calling a function that no longer existed
- `openspec/changes/core-installer-one-entry-point/{proposal,design,tasks}.md`,
  `specs/workflow-installation/spec.md`, `REVIEWS.md`
- `openspec/changes/one-enforcement-floor/` — new
- `docs/HOW-IT-FITS-TOGETHER.md` — new

## Next session: start here

Do the real run. Read `openspec/changes/core-installer-one-entry-point/tasks.md`
§8 first; `docs/evidence/install-check-before.md` is the restore reference and
`./install.sh --check` still matches it byte for byte.

```
./install.sh --host auto --replace-unrecognised
```

It rebinds 13 bindings, removes 7, and **writes no host configuration** — there
is no config opt-in to pass any more, which is what makes it safe beside live
sessions. Everything replaced is preserved under `~/.agenticapps/pre-install/`
and the run prints the restore command. Expect 26 archived bindings to go to 0.

Then 8.6 (`manifest.tsv` — the `normalize-claude-md.sh` row **stays**), 8.7 (no
host config file was created or modified), 8.8 code review on the diff, 8.9
`cso`. Then archive, which unblocks `one-enforcement-floor`.

## Open questions

1. **`one-enforcement-floor` has no plan review yet** (its task 8.2). It has no
   code and won't for a while, which is when a plan review is cheapest.
2. **Two round-4 findings deliberately not actioned.** Codex wants the delta to
   enumerate host/directory/marker tables — same objection as round 3, and it
   means duplicating data that lives in one place in the code; wants Donald's
   call. And escaping control characters in reported paths, which belongs with
   `screen-review-egress` where the PII policy already lives.
3. **`--check` still reports a binding into an archived checkout as plain
   `bound`** — it never runs `scan_archived`, which is install-mode only. The
   spec makes check-mode reporting distinctions the first deferrable item, so
   deferring is legitimate; but it also requires deferrals be reported, and
   nothing reports this one.
4. **The trigger skill that loads is still the wrong one.**
   `~/.claude/skills/agentic-apps-workflow` resolves to the 402-line copy in the
   **archived** `claude-workflow` checkout, not core's 235-line v4.0.0. The run
   fixes this. It is also the live counter-evidence for question 5.
5. **Does `AGENTS.md` still need a workflow section** once the skill carries the
   workflow? `host-neutral-instruction-files` says yes. Deliberately not settled
   by the hooks work — repealing a requirement as a side effect is how a rule
   disappears without anyone deciding.
6. **`~/.config/opencode/rules/gsd-oc-work-hard.md`** is a live global rule file
   reaching opencode, left over from GSD. The 2026-08-05 audit recorded opencode
   as having "no global instruction file at all"; that was about the `AGENTS.md`
   paths it probed, not the hosts' capability. Codex reads `~/.codex/AGENTS.md`.
7. **`workflow.mmd` still says the gate requires "REVIEWS ≥ 2".** Untrue since
   gate 2.0.0.
8. **PRs #87 and #88 remain open**, as do the five fleet PRs. This work sits on
   top of them.
9. `.planning/` is still untracked and still being written to by something.
