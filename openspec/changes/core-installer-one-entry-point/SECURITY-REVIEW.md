# Security review — task 8.9 (`cso`)

Daily mode, scoped to this change: `install.sh`, the published artifacts, and
what the run left on the machine. Full report at
`.gstack/security-reports/2026-08-06-200900.json` (untracked — `.gstack/` was
added to `.gitignore`, which is where security reports belong).

Phases that apply to a shell repository with no package manager, no endpoints
and no credentials: 0, 1, 2, 4, 8, 9, 12, 13, 14. No secrets in the branch
diff, no tracked `.env`, no `eval`, no network fetch, no `sudo`, no
`chmod +x` of anything downloaded. Every filesystem operation in `install.sh`
is quoted; `~/.agenticapps/bin` is user-owned `0755` and is not on `PATH`.

Two findings. Nine candidates, seven filtered.

## HIGH (9/10, verified) — the bindings follow the working tree

`bind_one` symlinks each host's skill entry to `$ROOT/skills/<name>`, a path
**inside this checkout**. All five hosts now resolve there. Whatever the working
tree holds at load time is what five agents execute as their instructions.

The concrete path: someone opens a PR touching
`skills/agentic-apps-workflow/SKILL.md`, a maintainer runs `gh pr checkout` on
this machine to review it, and from that moment every host loads the submitted
file as its workflow instructions — before the review, by the agent doing the
reviewing.

**The fix is not to change the design.** Symlink-never-copy is the whole point,
and this session is the argument for it: repointing the binding changed the
host's live skill list mid-run, which is exactly the property that was wanted.
What is missing is that this is written down anywhere as a *security* property
rather than a convenience one. A checkout of this repository is live prompt code
for every host on the machine. That means a branch carrying skill changes gets
reviewed by reading the diff, never by checking it out — and if the review
machine ever needs both, it should bind to a pinned worktree of `main`.

Recorded here rather than fixed: it is a property of the topology, which is what
`one-enforcement-floor` and `docs/HOW-IT-FITS-TOGETHER.md` are about.

## MEDIUM (8/10, verified) — actions pinned to tags, not SHAs

Five `uses:` lines across the two workflows, all first-party
(`actions/checkout@v7`, `setup-node@v7`, `configure-pages@v6`,
`upload-pages-artifact@v5`, `deploy-pages@v5`). A moved tag runs attacker code
with the job's token, and `openspec-gate.yml` executes repository shell scripts.
First-party keeps this at MEDIUM. Worth SHA-pinning: that workflow already
documents choosing `pull_request` over `pull_request_target` for the same class
of reasoning, so the argument is accepted here already.

## Not new, and already deferred

Round four asked for control-character escaping and a PII policy on reported
paths and restore commands. That is still deferred to `screen-review-egress`,
where the PII policy lives. Naming it again here so the deferral stays visible
rather than becoming silence.

## What the run cleaned up

Worth recording: the `agenticapps-workflow` directory the run removed from
`~/.claude/skills/` was not a copied skill — it was a **full git clone**, `.git`
and `.github` and all, being loaded as a skill. It is preserved intact under
`~/.agenticapps/pre-install/`. Whatever else this change did, it took an entire
checkout out of a directory an agent host scans.

---

*`/cso` is an AI-assisted scan, not a substitute for a professional security
audit. It catches common patterns; it is not comprehensive and not guaranteed.*
