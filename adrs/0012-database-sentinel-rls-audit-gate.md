# ADR-0012: database-sentinel as RLS audit sub-gate (post-phase + finishing)

**Status:** Accepted
**Date:** 2026-05-03
**Linear:** —

## Context

The security gate (see spec section 02 — generic CSO-style audit) covers OWASP-level
concerns at a phase boundary, but it is not a database-specialist auditor. It does
not check Supabase Row Level Security policies against known anti-patterns, does not
validate Postgres role grants against CVE databases, and does not probe MongoDB or
Firebase configurations for exposed-by-default behaviors.

`Farenhytee/database-sentinel` is a multi-host skill that audits database backends
for security misconfigurations. The Supabase phase ships:

- 27 anti-patterns drawn from CVE-2025-48757 and 10 security studies
- 7-step audit with safe dynamic probing (no destructive queries)
- Scored report with severity levels (Critical / High / Medium / Low)
- Exact fix SQL per finding (DDL ready to run)

It composes with the security gate rather than replacing it: the security gate covers
the broad OWASP threat model, database-sentinel goes deep on RLS / auth bypass /
storage exposure / ghost auth / MongoBleed (CVE-2025-14847) / pgBouncer
CVE-2025-12819 / mysql_native_password drift.

## Decision

Wire `database-sentinel` into the AgenticApps workflow at two gate points:

1. **Post-phase sub-gate (under `security`)** — when the security gate fires AND
   the phase scope matches `supabase|postgres|mongodb`, run
   `database-sentinel:audit`. Output: `DB-AUDIT.md` in the phase directory.
   Critical or High findings BLOCK branch close; fix or accept via ADR using the
   host's database-security acceptance ADR template.
2. **Finishing gate (`db_pre_launch_audit`)** — before any AgenticApps client
   app goes live (branch on main + pre-launch checklist active), run
   `database-sentinel:audit` over the full project surface (every supported
   backend, not phase-scoped). Zero Critical, zero High required to clear the
   gate. The audit's surface scope is conveyed via a `scope` field in the
   host's hook-config rather than a fabricated CLI flag, since the upstream
   skill is natural-language invoked and exposes no `--full` flag at adoption
   time. See Consequences for the spec deviation note.

Patches landed (per the original action plan §2):

- The host's workflow-config artifact — Post-Phase `security` row replaced with
  expanded version that names the sub-gate
- The host's hook-config JSON — `post_phase.security.sub_gates[]` array
  with the database-sentinel entry; `finishing.db_pre_launch_audit` entry
- The host's instruction-file sections artifact — Post-Phase Hook expanded to
  document the sub-gate, the BLOCKING semantics for Critical / High, and
  the override path via the new ADR template
- The host's enforcement-plan document — Post-phase gates row added
- A new standalone ADR template file for database-security acceptance

## Alternatives Rejected

- **Replace the generic security gate with database-sentinel for DB phases.**
  Rejected — the two cover orthogonal concerns. The security gate covers
  OWASP top 10 and cross-cutting security (CSRF, XSS, SSRF), database-sentinel
  covers database-specific misconfigurations. Replacing one with the other
  loses coverage in the dropped axis.
- **Run database-sentinel as a peer post-phase gate (not a sub-gate of the
  security gate).** Rejected — sub-gating expresses the conditional dependency:
  database-sentinel only fires when the broader security gate fires AND
  the scope matches a supported backend. As a peer gate it would have to
  re-implement the trigger logic.
- **Make Critical / High findings advisory rather than blocking.**
  Rejected — vibe-coded apps ship with default-readable RLS policies
  (CVE-2025-48757 root cause). Advisory severity is what got us to "27
  anti-patterns from 10 studies" in the first place. Block on Critical / High,
  with explicit ADR override for cases where the team accepts the risk.
- **Append the database-security acceptance section to the host's
  instruction-file sections artifact instead of a standalone template.**
  Rejected — the instruction-file sections artifact is already long and the
  ADR section is a distinct concern. A standalone file is easier to copy
  into project ADRs.
- **Skip the finishing-stage `db_pre_launch_audit` and rely on per-phase
  audits.** Rejected — per-phase audits run on the changed scope only;
  pre-launch is a full-surface audit including dimensions a feature phase
  might never touch (storage policies, role grants, anonymous access).

## Consequences

**Positive:**
- Database security misconfigurations caught at phase boundary, not
  after deploy.
- Critical / High blocking semantics make it impossible to ship known-bad
  RLS policies without explicit, time-boxed ADR acceptance.
- The exact SQL DDL output from database-sentinel makes fixes
  drop-in-able — no "I don't know how to fix this" friction.
- Pre-launch full audit catches dimensions per-phase audits skip.
- Acceptance ADRs create an auditable trail of accepted risks with
  owners and re-audit dates.

**Negative:**
- One more external skill dependency. Bus factor: solo maintainer
  (`Farenhytee`). Mitigation: skill is a markdown skill file; we can fork
  and self-host if the upstream is abandoned. The 27 anti-pattern catalog
  is portable knowledge.
- Adds ~30–60 seconds per security-scoped phase (DB-AUDIT.md generation).
- Pre-launch full audit can produce many findings on legacy projects;
  expect a non-trivial pre-launch acceptance backlog the first time.
- Acceptance template adds process overhead — but the alternative (no
  override mechanism) makes the gate impractical.

**Follow-ups:**
- Future host phases should detect the `Farenhytee/database-sentinel` skill
  install state and prompt to install when not present (analogous to how
  the migration framework from ADR-0013 handles missing skills).
- After 4 weeks of usage, count Critical / High accept-rate vs fix-rate.
  If accept-rate dominates, the gate severity may be too aggressive — or
  the team's compensating-controls discipline needs tightening.
- **Spec deviation:** the original action plan specified the finishing
  skill as `database-sentinel:audit --full`. The upstream skill is
  natural-language invoked and has no `--full` CLI flag (verified by
  Stage 2 review). The patch was applied with the suffix dropped and a
  `scope` JSON field added to convey "full-surface" semantics in
  schema rather than via a fabricated flag. If a future
  `database-sentinel` release adds genuine CLI flags, revisit and
  consider re-adding `--full` in line with upstream conventions.

## References

- `Farenhytee/database-sentinel` skill — installed per host into the host's
  skills directory.
- Database-security acceptance ADR template — host-side artifact referenced
  by the override path.
- CVE-2025-48757 (Supabase RLS default-permissive): cited in upstream skill docs
- CVE-2025-14847 (MongoBleed): cited in upstream skill docs
- CVE-2025-12819 (pgBouncer): cited in upstream skill docs

---

*This ADR documents a host-agnostic decision. For host-specific bindings (concrete
paths, skill names, plugin invocations), see each host repo's documentation.*
