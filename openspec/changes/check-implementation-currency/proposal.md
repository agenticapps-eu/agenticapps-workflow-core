## Why

On 2026-08-03 `tools/provisioning-check.sh` reported this machine
`COMPLETENESS complete`, `INTEGRITY attested`, "This machine is provisioned. The
shims will resolve." — while it was running `database-sentinel` 1.0.0 and
`normalize-claude-md` 1.0.0, three landed fixes behind what core ships. Measured
on the published copies: `normalize-claude-md` took `CLAUDE.md` from 0644 to
**0600**, and `database-sentinel` did **not** block `DELETE FROM public.users`.

**The comparison that would have caught it already exists.** `--source-check DIR`
compares each executed copy against core's maintained implementation, and its own
comment states this proposal's premise verbatim: *"A machine can be perfectly
attested against a manifest that published last month's implementation."* It was
built by task 3.2a-ii and it works — pointed at a stale tree it reports `DIFFERS`
on both artifacts.

The defect is therefore not a missing check. It is three narrower things:

1. **The summary ignores it.** With `--source-check` reporting `DIFFERS` on both
   artifacts, the tool still prints "This machine is provisioned. The shims will
   resolve." Reproduced. The source finding increments the finding count and
   changes no verdict.
2. **It is opt-in, off by default, and its absence is undisclosed.** A run without
   the flag reads identically to a run where the stronger question was asked and
   answered. The tool lives *inside core*, so the authority is almost always
   right there — defaulting off is what made the fifteen hours possible.
3. **The spec does not model it at all.** `project-hook-binding` defines the state
   as a pair and says of `attested`: "This is the only value on either axis under
   which the fleet's protections may be described as running as documented." That
   is false, and the capability has a tool doing something its own state
   vocabulary cannot express — the usual drift inverted, code ahead of spec.

Related and unfixed: `# <hook>-version:` was defined alongside `# shim-contract:`
and **nothing compares it**. The source check compares bytes only, so it can say
*differs* but never *older*, *newer*, or *by how much* — and never names a remedy.

## What Changes

- **Promote the existing source comparison to a reported axis, `currency`:**
  `current` / `stale` / `unknown`. Same comparison, given a name, a verdict and a
  place in the state vocabulary.
- **Default it on** when the authority is locatable from the tool's own location,
  which is inside core. `--source-check DIR` is retained as the explicit override;
  `--no-source-check` opts out. **BREAKING for output format only**: a default run
  gains a `CURRENCY` line.
- **The summary stops overclaiming.** "This machine is provisioned" requires
  `complete` + `attested` + `current`. Under `unknown` it says which question was
  not asked, rather than reading like a clean bill.
- **Scope the comparison to the declared set.** `openspec-change-gate`,
  `reviewer-cli` and `run-plan-review` live in the same bin, are published by
  `install-shared-artifact.sh`, and already report "no maintained file — cannot
  compare". They are out of this manifest's scope and SHALL NOT be reported stale.
- **Use the version markers for the message**: direction, both versions, and a
  remedy chosen per condition. Comparison stays byte-based; the marker supplies
  the words. Ordering is component-wise numeric, reusing `semver_cmp` from
  `project-hook-conformance.sh` — a lexical compare puts `1.10.0` below `1.9.0`
  and would point the operator at the wrong remedy.
- **Narrow the claim honestly**: currency is measured against a *checkout*. An
  equally stale checkout and install agree and report `current`, so the axis says
  "matches this authority checkout", never "matches what core ships".

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `project-hook-binding`: the per-machine state gains a third axis modelling a
  comparison the tooling already performs; the "running as documented" clause is
  narrowed from `attested` to `attested` + `current`; the implementation version
  marker gains the comparison and message rules the shim marker already has.

## Impact

- `tools/provisioning-check.sh` — default-on resolution, the `CURRENCY` verdict,
  per-condition remedies, the corrected summary, `--no-source-check`.
- `tools/project-hook-provisioning.test.sh` — the four `stale` sub-cases, the
  `unknown` sub-cases, the out-of-scope artifacts, and the summary text itself.
- `reference-implementations/project-hooks/README.md` — the state vocabulary,
  documented there as a pair.
- **`provisioning-check.sh` is not published to the shared bin** and is not in
  `ARTIFACTS`; it only runs where core is checked out. That makes `unknown` rare
  rather than common — the opposite of this proposal's first draft — and it means
  the axis costs nothing in the ordinary case.
- No shim, project, published artifact or manifest format changes.
