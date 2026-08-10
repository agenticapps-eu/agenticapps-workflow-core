# ADR-0014: Observability architecture for AgenticApps projects

**Status:** Accepted
**Date:** 2026-05-15
**Linear:** —
**Spec trajectory:** v0.2.0 (initial §10) → v0.2.1 (cparx-pilot patches: §10.5 recoverer note, §10.7.1 module-root rule) → v0.3.0 (§10.9 conformance enforcement)

## Context

AgenticApps projects span four service surfaces by default — frontend (Cloudflare Pages or similar), backend (Fly.io or similar), edge worker (Cloudflare Workers), and edge function / database (Supabase). Future projects will add more (queue consumers, scheduled tasks, third-party webhooks). Up to v0.1.0 of the workflow spec, observability is unspecified: each project either has none, or wires a vendor SDK ad-hoc into whichever surface the author thought of first. The current state has three measurable failure modes:

1. **No cross-surface correlation.** A request that touches frontend → worker → backend → Supabase cannot be reconstructed from logs because no shared identifier propagates. Debugging requires inferring causality from timestamps, which is unreliable under load.
2. **Vendor lock-in by accident.** When a vendor SDK is called directly from application code in 30+ call sites, swapping vendors becomes a refactor. The first vendor chosen becomes load-bearing through inertia.
3. **Inconsistent coverage.** Errors are caught in some handlers and logged, swallowed in others. Business events (signups, payments) are emitted in some flows and missed in others. There's no checklist that says "this project is instrumented."

A first-principles deconstruction of the problem (2026-05-10) showed that "install Sentry" — the natural first move — answers a destination question but leaves all three failure modes intact. The architectural decisions are upstream of the destination decision.

A second motivation: agents debugging AgenticApps projects need structured, queryable, correlated events. They cannot reason about a system they cannot observe. The same instrumentation that helps a human SRE helps an agent investigator. Building one observability discipline serves both audiences.

A third motivation, surfaced at v0.3.0: instrumenting a project once is necessary but not sufficient. Without a mechanism to detect *regression*, a freshly instrumented project drifts back toward inconsistent coverage as new handlers, outbound calls, and business events ship without their corresponding observability hooks. The pilot report at `fx-signal-agent/.scan-report.md` (2026-05-14) demonstrated the shape of post-adoption gap accumulation; v0.3.0 closes that loop with §10.9.

## Decision

Adopt a **two-layer observability architecture**: a normative contract in the core workflow spec, and a per-host generator skill that produces conformant code for each tech stack. v0.3.0 extends the contract with conformance enforcement primitives so the architecture stays load-bearing after initial adoption.

### Architecture

```
agenticapps-workflow-core/
├── spec/
│   └── 10-observability.md      # the contract — declarative, RFC 2119
└── adrs/
    └── 0014-observability-architecture.md   # this ADR

<host-workflow-repo>/
└── <generator-skill>/           # the generator — host-specific
    ├── <invocation-manifest>    # subcommand routing (init / scan / scan-apply)
    ├── stacks/                  # per-stack templates
    │   ├── ts-cloudflare-worker/
    │   ├── ts-cloudflare-pages/
    │   ├── ts-supabase-edge/
    │   ├── ts-react-vite/
    │   └── go-fly-http/
    ├── scan/                    # brownfield validator
    │   ├── detectors.md
    │   └── checklist.md
    └── policy-template.md       # default redaction + sampling policy

<project>/
├── lib/observability/           # vendored, generated code
│   ├── index.{ts|go}
│   └── policy.md
├── .observability/
│   └── baseline.json            # conformance baseline (§10.9, added v0.3.0)
└── <instruction-file>           # the host's canonical project-prose file
                                 # with observability metadata block
```

### The contract (core spec §10)

The spec defines, in declarative-contract form:

- A **wrapper interface** (`logEvent`, `captureError`, `startSpan`) that is the only path application code uses to emit observability data.
- An **event envelope** with seven required fields (`trace_id`, `span_id`, `service`, `env`, `event`, `severity`, `attrs`).
- **W3C `traceparent`** as the cross-service correlation primitive.
- **Mandatory instrumentation points**: handler entry, outbound calls, caught errors, business events.
- **Operational requirements**: non-blocking emission, fail-safe behavior, PII redaction, sampling rules.
- **Destination independence**: the vendor or backend is configuration; switching destinations does not modify application code.
- **Generator obligation**: every conformant host MUST provide a scaffolder + brownfield validator + delta-scan + baseline maintenance.
- **Conformance enforcement** (added v0.3.0): delta scan, baseline file, CI-integration guidance, optional pre-commit hook.

The contract is host-agnostic and vendor-agnostic. It says nothing about Sentry, OpenTelemetry, Axiom, or any specific function name.

### The generator (per-host observability skill)

Each host repo ships a skill that:

- Detects the project's tech stack(s) and resolves each stack's module root per §10.7.1.
- Scaffolds `lib/observability/` for each detected stack from per-stack templates.
- Wires `traceparent` middleware into request handlers at the correct boot points.
- Validates an existing project against the spec's mandatory instrumentation points and emits a confidence-ranked report.
- Applies high-confidence insertions only with explicit per-file or per-batch confirmation.
- Maintains `.observability/baseline.json` and supports `--since-commit` delta scans for CI gates (added v0.3.0).

The generator's output is **vendored into the project** — a copy of the wrapper code lives in `lib/observability/`, not as a dependency on a published package. The skill regenerates idempotently when the contract or templates change.

### Default destination (host choice)

The spec does not mandate a default destination. The first reference implementations ship Sentry as the default destination because:

- Sentry's SDKs are mature for every stack the reference implementations support (Workers, Node, Go, browsers).
- Sentry already speaks OTLP-compatible protocols for traces, so the wrapper can emit using the SDK without coupling the application to Sentry-proprietary idioms.
- Adoption friction is lower when the default vendor is one project owners already have an account with.

Sentry is configured as a destination behind the wrapper, not as the wrapper itself. Application code never imports vendor SDKs directly. Adding a second destination (PostHog for analytics, Axiom or Grafana Cloud as an alternative log sink) is a config change in `lib/observability/`, not a code change in any service. Other host implementations MAY pick different default destinations as long as the destination-independence requirement (§10.6) holds.

### Brownfield support via scan + apply

Existing AgenticApps projects adopt this architecture via a migration in the migrations framework (ADR-0013). The migration invokes the generator skill in scan mode, presents a confidence-ranked gap report, and offers to apply high-confidence insertions with diff preview.

The scan validator's output is the canonical answer to "is this project conformant with §10?" — agents and humans alike read it. As of v0.3.0, the validator also writes `.observability/baseline.json` so future scans can be diffed against the current conformance state, and CI workflows can fail PRs that increase the high-confidence-gap count (§10.9.3).

## Alternatives Rejected

- **Install a vendor SDK directly in every service.** Rejected — produces vendor lock-in by accident (failure mode 2 above) and gives no path to multi-destination emission. The wrapper indirection is one extra file per service in exchange for vendor portability for the life of the project. The trade favors the wrapper at any scale beyond throwaway prototypes.

- **Adopt OpenTelemetry SDKs directly with no wrapper.** Rejected — OTel is the right *protocol* but the wrong *application surface*. OTel's API surface is broad (TracerProvider, MeterProvider, Logger, Resource, propagators, samplers...); making application code call it directly leaks complexity. The wrapper exposes three operations and routes them through OTel-or-Sentry-or-whatever underneath. OTel becomes a destination implementation detail, not the project's observability vocabulary.

- **Single observability service with a logo wall (Datadog, New Relic, Honeycomb).** Rejected — these tools solve a problem one or two scales above where AgenticApps projects sit today. Their pricing is structured around enterprise volume; their lock-in is harder than Sentry's because the agent-and-tracing data model is more proprietary. Revisit at the scale where their pricing makes sense; until then, the wrapper makes the choice reversible at any time.

- **One vendor per concern (Sentry for errors, PostHog for analytics, Axiom for logs) wired into application code.** Rejected — gives three SDK call sites in every service, three configuration surfaces, three on-call integrations. The wrapper unifies the call surface; multiple destinations are configured in one place. PostHog and Axiom remain available as additional destinations, but they're routed via the wrapper, not imported by handlers.

- **Publish `lib/observability` as an internal package.** Rejected — adds a release cycle between the spec, the templates, and the project. AgenticApps projects evolve fast and benefit from the ability to diverge slightly in their wrapper (e.g. add a project-specific attribute). Vendoring keeps each project self-contained; the skill regenerates the wrapper on demand if the contract or templates change. The cost — the wrapper code is duplicated across N projects — is minor at the project counts we're operating at.

- **Spec-only, no generator.** Rejected — spec without generator means each project owner re-implements the wrapper from prose. That guarantees drift in semantics (the exact non-blocking behavior, the exact PII policy, the exact span attributes) even when the prose is identical. The generator is what makes the spec mechanically enforceable.

- **Generator-only, no spec.** Rejected — generator without spec means the contract lives in the generator's templates. When a second host wants to ship an equivalent generator, there is no canonical reference for what "equivalent" means — the templates *are* the specification, and they are written in a single language. The spec is what makes the contract host-portable.

- **Auto-apply scan results without confirmation.** Rejected — telemetry insertions in a brownfield project are noisy and easy to get wrong. The same logic that makes lint-fix opt-in applies here. Confirmation per file or per batch keeps the user in control and produces reviewable PRs.

- **Defer observability until first incident.** Rejected — the projects in question are pre-launch but on the runway to public traffic. Adding observability after the first production incident is exactly when the on-disk archaeology is most expensive. The cost of building this now is bounded; the cost of building it under incident pressure is not.

- **Enforcement via lint rule rather than CI gate (v0.3.0 alternative).** Rejected — lint runs in the editor and the CI step, but a lint rule that fires "this handler has no startSpan" is brittle: handlers are detected by shape (function signature, route registration), which varies per framework. The scan validator already encodes per-language detection; reusing it as the CI gate (via delta scan + baseline diff) keeps one detection surface to maintain. Lint rules MAY layer on top as a developer-ergonomic warning, but the load-bearing enforcement is the CI gate.

- **Auto-update baseline on every scan run (v0.3.0 alternative).** Rejected — auto-updating the baseline on every scan would let new gaps slip into the baseline silently. The decision: baseline updates happen only on successful `scan-apply` (because the apply implies an explicit human decision) or via an explicit `--update-baseline` flag. CI scans never write the baseline.

## Amendment — 2026-08-10 (reference implementation dropped Axiom)

`agenticapps-observability` **ADR-0037** removed the Axiom destination adapter
from every stack it generates. The default role map is now
`errors→sentry, logs→none, analytics→none`: logs are the wrapper's structured
JSON line on console/stdout, captured by each runtime's native log product.
Propagation to consuming projects is that repo's migration 0024 (consumer axis
1.22.0→1.23.0).

**Nothing in this ADR or in spec §10 required amending.** Both are
vendor-agnostic by construction — §10.8 specifies `- logs:
<vendor-or-self-hosted>`, and every mention of Axiom below is an *example* of a
destination someone could configure, never a prescribed default. The §10.6
destination-independence requirement is what made the removal a config-shaped
change rather than a refactor, which is the property this ADR was written to
buy.

This note exists only so a reader does not infer from "PostHog and Axiom remain
available as additional destinations" that the reference generator ships an
Axiom adapter. It does not. Axiom remains *implementable* against the unchanged
`Destination` contract; it is simply no longer *implemented*.

## Consequences

**Positive:**

- AgenticApps projects gain end-to-end correlation across Cloudflare → Fly → Supabase via `traceparent` propagation. A request can be reconstructed from a single trace ID across all services without inferring causality from timestamps.
- The destination vendor is reversible. Replacing the default destination with Axiom, Grafana Cloud, or a self-hosted OTel collector is a config change. Application code never knows.
- Adding a new destination (PostHog for product analytics) is a sink registration in the wrapper, not a refactor across handlers.
- Agents debugging projects get structured, queryable events with consistent envelope shape across services. The mandatory checklist gives them a sharp signal: "this file conforms to §10.4 #1, #2, #4 but not #3."
- New AgenticApps projects scaffold with observability wired in by default. There's no "I'll add it later" path.
- Existing projects adopt non-destructively via the migrations framework + scan command + per-file consent.
- v0.3.0's enforcement layer prevents post-adoption drift: once a project is at baseline N, PRs that would increase the high-confidence-gap count fail CI. Instrumentation stays load-bearing without manual audits.
- The contract-in-spec, generator-in-skill split is reusable: future cross-cutting concerns (auth, feature flags, rate limiting) can adopt the same shape — declarative spec section + per-host generator + baseline + CI gate.

**Negative:**

- Significant upfront scaffolding: spec section, ADR, generator skill, per-stack templates (TS Cloudflare Worker, TS Cloudflare Pages, TS Supabase Edge, TS React Vite, Go Fly HTTP — five at v0.2.0), scan detectors, scan checklist, brownfield migration, and now (v0.3.0) delta-scan support, baseline maintenance, and reference CI workflow per host. The payoff is downstream — every future project gets observability "for free" — but the first-version cost is not zero.
- The wrapper indirection has runtime cost: one extra function call per emission, one extra middleware on the request path. At normal traffic this is irrelevant; at extremely high request rates, the indirection is measurable. Mitigation: the wrapper is fire-and-forget by spec (§10.5), so the cost is bounded to function-call overhead, not transport overhead.
- The brownfield scan is heuristic. It will produce false positives (flagging a `try`/`catch` that doesn't need `captureError`) and false negatives (missing a queue consumer hidden behind a custom abstraction). The opt-in apply model contains the false positives; documentation in `scan/checklist.md` lists the known false-negative shapes so reviewers know what to look for.
- Vendoring the wrapper means N copies across N projects. When the contract changes, N projects need regeneration. Mitigation: the generator skill is idempotent and re-runnable. When §10 ships a new version, the migration framework propagates regeneration as a single command per project.
- The spec section + ADR + skill must be kept aligned. If the spec says "MUST emit `severity`" and the templates ship without it, conformance is silently broken. Mitigation: the scan validator IS the conformance check — running it against any project is a fast verification that the project still satisfies §10. v0.3.0's `policy_hash` field in the baseline catches a related drift class — when `policy.md` changes underneath a baseline, CI surfaces it.
- The v0.3.0 CI gate adds one more CI step per PR. The delta scan is bounded by the file count in the PR, not the project size, so the runtime is small. Mitigation: hosts MAY tune the delta-scan implementation per their toolchain.

**Follow-ups:**

- After three projects have adopted this (cparx, fx-signals, dashboard or a third), audit whether the contract's mandatory instrumentation points (§10.4) are right. Remove any that produce mostly noise; add any that proved load-bearing in practice.
- Consider whether to add a `lib/observability/dashboard.md` template — a project-specific Grafana / Sentry dashboard layout that ships with the wrapper. Defer until at least one project's dashboard has stabilized in production use.
- Evaluate OpenTelemetry as a *destination* (rather than the application surface) once Sentry's OTLP support and Axiom's free tier are both confirmed working in production. The wrapper makes this evaluation a config experiment, not a refactor.
- Track an explicit "observability budget" per project: error volume, log volume, sampling rates, monthly cost. Add to the project instruction file's metadata block once we have data.

### v0.3.0 follow-up

Shipped in v0.3.0:

- §10.9 conformance enforcement (delta scan + baseline file + CI-integration guidance + optional pre-commit hook). This closes the post-adoption regression loop that was deferred from v0.2.1 (gap G7 in the rollout plan). The pilot report at `fx-signal-agent/.scan-report.md` motivated the timing — without enforcement, the instrumentation discipline degrades as the project grows.

Remaining pending for v0.4.0 (or later):

- The deferred §10.4 split into handler-entry vs background-work entry points (gap G3 from the cparx pilot 2026-05-10). The current §10.4 #1 conflates HTTP handler entry, edge function entry, scheduled-task entry, and queue-consumer entry. Background-work entries have different naming conventions, different attribute requirements, and different parent-span semantics; merging them into one bullet has caused detector ambiguity in the pilot. File as a v0.4.0 candidate; revisit after at least one more project adopts and the detector behavior is measured.
- Whether the baseline file should also track *medium-confidence* gap counts as a separate CI gate threshold (today only high-confidence gaps gate the merge). Defer until at least one host's CI workflow ships and accumulates data on false-positive rates at the medium-confidence level.

## References

- Spec section: `spec/10-observability.md` (v0.3.0)
- ADR-0013: Migration framework — the mechanism by which existing projects adopt this architecture
- W3C Trace Context Level 1: https://www.w3.org/TR/trace-context/
- RFC 2119 (RFC keywords): https://www.rfc-editor.org/rfc/rfc2119
- First-principles deconstruction (2026-05-10 conversation)
- cparx pilot report (2026-05-10) — surfaced gaps G1, G3, G4, G7 that motivated the v0.2.1 amendments and v0.3.0 enforcement layer
- fx-signal-agent pilot report — concrete example of post-adoption gap accumulation

---

*This ADR documents a host-agnostic decision. For host-specific bindings (concrete paths, skill names, plugin invocations), see each host repo's documentation.*
