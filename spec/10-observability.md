---
id: 10-observability
section_type: declarative-contract
spec_version: 0.3.2
---

# 10 — Observability

> **Changes since 0.3.0**
> - §10.5 — added MUST-level **Flush primitive** obligation. Wrappers
>   MUST expose a `Flush(timeout)` (or idiomatic equivalent) that drains
>   in-flight emission goroutines/microtasks INTO the destination SDK's
>   transport BEFORE draining the SDK's own buffer. Short-lived processes
>   (CLI tools, migrations, tests) MUST call it before exit; long-running
>   services need not. Generators in languages with runtime-await for
>   short-lived processes (Cloudflare Workers via `ctx.waitUntil`, Deno
>   Deploy) MAY satisfy the obligation implicitly; generators in languages
>   without (Go) MUST expose `Flush` explicitly. Witness: factiv/cparx
>   2026-05-18 Sentry adoption verification — wrapper-routed events were
>   silently dropped from CLI smoke tests because the SDK's flush
>   raced against fire-and-forget emission goroutines.
> - No conformance impact on hosts that already drain via host-runtime
>   await (`ts-cloudflare-worker`, `ts-cloudflare-pages`, `ts-supabase-edge`,
>   `ts-react-vite`); they satisfy the obligation implicitly today.
>   The obligation moves from "implicit best-practice" to "explicit MUST"
>   so future generators (Rust, Python, Node-on-bare-V8) cannot ship
>   without it.

> **Changes since 0.2.1**
> - §10.7 — fifth generator-obligation bullet added: generators MUST
>   support delta scan and maintain a project baseline file per §10.9.
> - §10.8 — added an OPTIONAL `enforcement:` sub-block to the project
>   metadata example, declaring baseline / CI workflow / pre-commit
>   paths.
> - §10.9 — new sub-section: conformance enforcement. Defines three
>   primitives (delta scan, baseline file, CI-integration guidance)
>   that generators MUST support so projects do not silently regress
>   after instrumentation.
> - No conformance impact on hosts already at 0.2.1. §10.9 obligations
>   on *projects* are SHOULD (with one MUST inside §10.9.3 about
>   opt-out visibility); obligations on *generators* are MUST.
>
> **Changes since 0.2.0**
> - §10.5 — added a note clarifying the interaction between the wrapper's
>   fail-safe behavior and host-framework recoverer middleware (cparx pilot
>   2026-05-10, gap G4).
> - §10.7 — clarified that generators MUST resolve target paths against the
>   *language module root* (e.g. the directory containing `go.mod`,
>   `package.json`, `Cargo.toml`), not the project root, so multi-language
>   monorepos and projects with non-root module manifests are supported
>   (cparx pilot 2026-05-10, gap G1).
> - No conformance impact on hosts already at 0.2.0.

**Section type**: declarative contract. Host implementations MUST satisfy the requirements below; prose, formatting, function naming, and destination vendor are at the host's discretion.

This section uses the keywords MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY as defined in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Intent

Every project produced by a conformant workflow implementation emits a stream of structured, correlated events from every service surface — frontend, backend, edge worker, edge function, scheduled task, queue consumer. Those events are queryable by humans during debugging and by agents during automated investigation. The destination of the events is a configuration choice; the emission contract is part of this spec.

The architectural premise: errors, logs, and product-analytics events are the same primitive — timestamped facts with attributes — separated by cadence and audience, not substance. A conformant implementation models them through one wrapper, one envelope, and one correlation primitive (`traceparent`).

## Requirements

### 10.1 Wrapper interface

A conformant project MUST expose, in every service-language used by the project, an observability wrapper module that provides at least these three operations. Function names and ergonomic shape are at the host's discretion; the *semantic contract* is what conforms.

- **logEvent(envelope)** — records a structured event. MUST be non-blocking on the request path. MUST NOT raise to the caller on transport failure.
- **captureError(error, envelope)** — records a thrown or returned error along with envelope context. MUST associate the error with the active span if one exists. MUST attach the error's stack trace when the runtime exposes one.
- **startSpan(name, attributes) → span** — opens a span representing a unit of work. The returned span MUST support attribute attachment, status setting (`ok` or `error`), and explicit completion.

The wrapper MUST be the only path by which application code emits observability data. Direct calls to vendor SDKs from application code are non-conformant.

### 10.2 Event envelope

Every event emitted via the wrapper MUST carry the following fields:

- `trace_id` — the W3C trace ID of the active trace (32 hex chars).
- `span_id` — the span ID of the active span (16 hex chars).
- `service` — string identifier of the emitting service (e.g. `cparx-backend`, `fx-signals-worker`).
- `env` — deployment environment (`dev`, `staging`, `prod`, or other host-defined value).
- `event` — short snake_case event name from a project-defined enumeration (e.g. `user_signup`, `payment_failed`, `request_completed`).
- `severity` — one of `debug`, `info`, `warn`, `error`, `fatal`.
- `attrs` — open key-value map of event-specific attributes.

Additional fields are permitted. The seven fields above are the minimum.

### 10.3 Trace context propagation

A conformant project MUST propagate trace context across every service boundary using the W3C `traceparent` header as defined in [W3C Trace Context Level 1](https://www.w3.org/TR/trace-context/).

- The first service to handle a request (the edge — typically the frontend or an edge worker) MUST generate a `traceparent` if none is present on inbound traffic.
- Every outbound HTTP request, RPC call, queue enqueue, scheduled-task dispatch, or database call that crosses a service boundary MUST carry the active `traceparent`.
- Every inbound handler MUST read `traceparent` (when present) and bind the resulting trace context to the request scope, such that any event emitted during request handling carries the matching `trace_id` and `span_id`.

A conformant project MUST NOT use a vendor-proprietary header as the *primary* correlation mechanism. Vendor SDKs MAY add their own headers in addition to `traceparent`.

### 10.4 Mandatory instrumentation points

A conformant project MUST emit observability data at all of the following points:

1. **Handler entry.** Every HTTP handler, edge worker fetch handler, edge function entry point, scheduled task entry point, and queue consumer entry point MUST open a span at entry and close it at exit. The span MUST be named after the handler (e.g. `POST /api/users`, `cron.daily-digest`).
2. **Outbound calls.** Every outbound HTTP, RPC, or cross-service database call MUST be wrapped in a child span of the current request span. The child span MUST carry an attribute identifying the target (`upstream.service`, `db.statement` or similar).
3. **Caught errors.** Every `try`/`catch` block — or language equivalent (`if err != nil` in Go, `Result::Err` in Rust, error boundaries in React) — that handles a non-trivial error MUST call `captureError` with the error and an envelope before deciding whether to swallow, rethrow, or recover. Trivial expected errors (input-validation failures, expected `not_found`s) MAY be excluded; each project defines what "trivial" means in a `lib/observability/policy.md` (or equivalent) document.
4. **Business events.** State transitions with product or compliance significance — signups, payments, subscription changes, key data mutations, permission changes — MUST emit a `logEvent` with severity `info` and an `event` name drawn from the project's enumeration.

A conformant project MAY add further instrumentation points (per-query database tracing, custom metric emission, etc.). The four above are the minimum.

### 10.5 Operational requirements

- **Non-blocking emission.** The wrapper MUST NOT block the request path on observability transport. Implementations SHOULD batch and flush asynchronously or use fire-and-forget delivery. A broken or slow observability destination MUST NOT degrade end-user latency or availability.
- **Flush primitive (added v0.3.2).** Wrappers MUST expose a `Flush(timeout)` primitive (or equivalent — `flush`, `await observability.flush()`, etc., as idiomatic per language) that drains in-flight emission goroutines/microtasks INTO the destination SDK's transport BEFORE draining the SDK's own buffer. Long-running services need not call `Flush` — per-request emission units have time to complete naturally before the next request arrives, and the SDK transport keeps its buffer drained in steady-state. **Short-lived processes (CLI tools, one-off migrations, tests, smoke verifiers) MUST call `Flush` before exit** to avoid silently dropping events. This is required because the destination SDK's flush waits for *its* buffer to drain, not for callers' fire-and-forget goroutines/microtasks that have not yet enqueued; calling the SDK's flush directly on a short-lived process races against the emission layer. Generators MAY satisfy this implicitly if the host runtime drains all pending promises before exit (e.g. Cloudflare Workers via `ctx.waitUntil`, Deno Deploy isolates); generators in languages without runtime-await for short-lived processes (e.g. Go) MUST expose `Flush` explicitly. Implementations MUST report success when the wrapper's emission units have all completed even when the destination SDK was never configured (no DSN, no client), since the emission-layer drain is the only contract `Flush` has in that mode. The witness for this requirement was a goroutine-vs-flush race surfaced in factiv/cparx's 2026-05-18 Sentry adoption verification: wrapper-routed events were silently dropped from CLI smoke tests while direct SDK calls arrived as expected, isolating the bug to the emission layer. See `add-observability/templates/go-fly-http/observability.go` `Flush(timeout)` for a reference implementation and `add-observability/templates/go-fly-http/observability_test.go` `TestFlushDrainsInFlightEmissions` for the contract test.
- **Fail-safe behavior.** Failures inside the wrapper — network errors, vendor SDK exceptions, malformed envelopes — MUST NOT propagate to the caller. The wrapper MUST log a single warning per failure window (host-defined window length) and continue.
- **PII discipline.** The envelope `attrs` field MUST NOT contain unredacted secrets, tokens, passwords, full payment card numbers, or other regulated identifiers as defined by applicable law (GDPR, PCI-DSS, HIPAA where relevant). Each project MUST publish a redaction policy in `lib/observability/policy.md` (or equivalent) listing which attributes are scrubbed and how.
- **Sampling.** The wrapper MAY sample `debug` and `info` events. Events of severity `error` or `fatal` MUST NOT be sampled. Span sampling MAY be applied to traces but MUST preserve any trace containing an `error`-or-higher event.

> **Note on host recoverer interaction (added v0.2.1).** When a project
> already uses a framework-level panic/error recoverer (e.g. Chi's
> `chimw.Recoverer`, Express's error handler, Fastify's `setErrorHandler`),
> the observability wrapper's middleware SHOULD be mounted *inside* the
> recoverer (i.e. the recoverer wraps the wrapper). The wrapper captures
> errors via `captureError`, then re-raises so the existing recoverer can
> apply its normal behavior (typically returning a 500). Mounting the
> wrapper outside the recoverer is conformant but means the wrapper
> sees the recovered response rather than the original panic, reducing
> the value of error capture. This is a recommendation, not a MUST —
> implementations MAY differ if their recoverer integrates differently.

### 10.6 Destination independence

The destination that receives events — a hosted service (Sentry, Axiom, Grafana Cloud, Honeycomb), a self-hosted collector, an event-sourced database table, a webhook, or a combination — is a configuration choice. A conformant project MUST be able to change its destination without modifying application code outside the wrapper module.

A host implementation MAY recommend a default destination. The spec recommends OTLP-compatible destinations to maximize portability but does not require them. A conformant project MAY emit to multiple destinations simultaneously (e.g. errors to one service, analytics to another) provided the application code uses only the wrapper interface.

### 10.7 Generator obligation

A conformant workflow implementation (the *host*) MUST provide a generator — a skill, a scaffolder, a setup command, or equivalent — that does all of the following:

- **Scaffolds** the wrapper module for each tech stack the host supports, such that the generated wrapper satisfies sections 10.1–10.6 of this spec.
- **Wires** trace propagation middleware into the project's request-handling layer at project scaffold time, so a fresh project conforms by default.
- **Validates** an existing project against the mandatory instrumentation points (10.4) and produces a confidence-ranked report of gaps. Validation MUST be available as a command separate from scaffolding.
- **Applies** proposed instrumentation insertions only with explicit per-file or per-batch confirmation. Auto-application without consent is non-conformant.
- **Supports delta scan and maintains the baseline** per §10.9. The baseline file is the source of truth for "what conformance level is this project currently at?", read by CI gates and by the dashboard.

The generator's implementation language, distribution mechanism, and invocation syntax are at the host's discretion. What conforms is the produced output and the validation behavior.

#### 10.7.1 Module-root path resolution (added v0.2.1)

The generator's target paths (where wrapper, middleware, and policy files are written) MUST be resolved relative to the **language module root** for the stack being scaffolded, not relative to the project's repository root. The language module root is the directory containing the canonical manifest for that stack:

| Stack family | Module-root manifest |
|---|---|
| Go | `go.mod` |
| Node / TypeScript | `package.json` |
| Rust | `Cargo.toml` |
| Python | `pyproject.toml`, `setup.py`, or `setup.cfg` |
| Deno | `deno.json` or `deno.jsonc` |

When a project contains multiple module roots (a common shape for monorepos — e.g. `frontend/package.json` + `backend/go.mod` in one repo), the generator MUST run independently for each detected stack and emit files into each stack's own module root. The same generator invocation MAY produce wrappers for multiple stacks in one pass.

A conformant generator MUST NOT assume the manifest lives at the repository root. Detecting the manifest is part of stack detection (§10.7 first bullet).

This rule was added after the cparx pilot (2026-05-10) showed that the original wording allowed an interpretation where the project root and the module root were conflated, producing files at the wrong location for projects with non-root module manifests.

### 10.8 Project metadata

A conformant project's primary instruction file — whichever filename the host runtime treats as canonical project-level guidance — MUST declare:

```yaml
observability:
  spec_version: 0.3.0     # spec version this project conforms to
  destinations:           # list of configured destinations
    - errors: <vendor-or-self-hosted>
    - logs: <vendor-or-self-hosted>
    - analytics: <optional>
  policy: lib/observability/policy.md
  enforcement:                                        # OPTIONAL — added v0.3.0
    baseline: .observability/baseline.json
    ci: <host-specific-ci-workflow-path>              # e.g. .github/workflows/observability.yml
    pre_commit: optional                              # one of: optional | enabled | disabled
```

This metadata is the citation that lets validators, drift reports, and future agents reason about the project's observability posture without reading code.

The `enforcement:` sub-block is OPTIONAL. Projects that omit it default to: baseline at `.observability/baseline.json` if a baseline file exists, no CI gate, no pre-commit hook. Projects that declare the `enforcement:` sub-block MUST satisfy the corresponding §10.9 requirements for each field they list (see §10.9 for the per-field contract).

### 10.9 Conformance enforcement (added v0.3.0)

A conformant project SHOULD prevent observability conformance from silently regressing in new development. To enable this, generators (per §10.7) MUST support three primitives — delta scan, baseline file, and CI-integration guidance — and MAY ship a fourth (pre-commit hook). The primitives below are host-agnostic; each host's reference implementation realizes them in its own toolchain.

#### 10.9.1 Delta scan

The scan subcommand MUST accept a `--since-commit <ref>` flag (or equivalent host-native convention) that limits findings to source files modified between `<ref>` and the working tree. The output format and confidence-classification rules from the full scan (§10.7 third bullet) apply unchanged; the only difference is the scope of files walked.

The delta-scan output is the input to CI gates that block PRs introducing new gaps. A conformant generator MUST emit, alongside the human-readable scan report, a machine-readable summary of the delta's high-confidence-gap count so the CI gate (§10.9.3) can compare it against the baseline without re-parsing markdown.

#### 10.9.2 Baseline file

Generators MUST maintain a canonical baseline file recording the current conformance state. The baseline's path is `.observability/baseline.json` — canonical. Hosts MAY support alternate paths via configuration, but `.observability/baseline.json` MUST be the default and MUST be the path the dashboard reads.

The baseline's JSON shape:

```json
{
  "spec_version": "0.3.0",
  "scanned_at": "2026-05-14T08:30:00Z",
  "scanned_commit": "7fa848a...",
  "module_roots": [
    { "stack": "go-fly-http", "path": "backend/" },
    { "stack": "ts-react-vite", "path": "frontend/" }
  ],
  "counts": {
    "conformant": 47,
    "high_confidence_gaps": 0,
    "medium_confidence_findings": 3,
    "low_confidence_findings": 1
  },
  "high_confidence_gaps_by_checklist": {
    "C1": 0,
    "C2": 0,
    "C3": 0,
    "C4": 0
  },
  "policy_hash": "sha256:..."
}
```

Fields:

- `spec_version` — the §10 version against which the baseline was computed.
- `scanned_at` — RFC 3339 timestamp of the last full scan.
- `scanned_commit` — the project commit SHA at scan time.
- `module_roots` — array of detected stacks and their module-root paths (§10.7.1).
- `counts` — aggregate counts across all stacks and checklists.
- `high_confidence_gaps_by_checklist` — per-checklist breakdown of high-confidence gaps. The checklist IDs (e.g. `C1`, `C2`) are host-defined and SHOULD map 1:1 to the §10.4 mandatory points; richer breakdowns MAY be added without breaking the schema.
- `policy_hash` — sha256 of the project's `lib/observability/policy.md` (or equivalent) at scan time. The hash is the citation that lets the CI gate detect when the policy has changed and the baseline needs re-validation.

Generators MUST update the baseline whenever `scan-apply` successfully modifies code, and MUST expose a manual override (e.g. `scan --update-baseline`) that recomputes the baseline without applying any fixes. The baseline file is committed alongside `policy.md` so its values track the project's history.

A project that declares `enforcement.baseline` in its §10.8 metadata block MUST have the baseline file present at the declared path. A project that omits the `enforcement:` sub-block MAY omit the baseline file; in that case, no CI gate is implied.

#### 10.9.3 CI-integration guidance

Each host SHOULD ship a reference CI workflow (e.g. GitHub Actions YAML for the Claude reference implementation; equivalent for the pi and codex reference implementations) that:

1. Runs the delta scan (§10.9.1) on every PR.
2. Compares the delta scan's high-confidence-gap count against the baseline file from the PR's merge-target branch.
3. Fails the PR if the count increases.
4. Surfaces the new findings as a PR comment.

Projects MUST be able to opt out of the CI gate by deleting or emptying the baseline file, but MUST NOT be able to opt out silently — the workflow MUST log a clear message if the baseline file is missing or empty so reviewers see that enforcement is disabled.

A conformant CI workflow MAY also compare the `policy_hash` field of the baseline against the current `policy.md` hash and fail (or warn, per host preference) on mismatch, since a changed policy invalidates the baseline's redaction and trivial-error assumptions.

#### 10.9.4 Optional: pre-commit hook

Hosts MAY provide a pre-commit hook template that runs the delta scan against staged changes and warns on new gaps. The hook MUST be skippable via the host's normal mechanism (`--no-verify` for git). Pre-commit enforcement is friendlier but skippable; CI enforcement (§10.9.3) is the load-bearing layer.

## Examples

### Minimal envelope (transport-agnostic)

```json
{
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "service": "cparx-backend",
  "env": "prod",
  "event": "user_signup",
  "severity": "info",
  "attrs": {
    "user_id": "u_8f2c1",
    "signup_method": "google_oauth"
  }
}
```

### W3C traceparent header

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

The four fields are version, trace ID, parent span ID, and flags. See the [W3C Trace Context spec](https://www.w3.org/TR/trace-context/#traceparent-header) for the full grammar.

### Conformant call sites (illustrative, not normative)

```ts
// Handler entry — section 10.4 #1
const span = startSpan("POST /api/users", { route: "/api/users" })
try {
  // Outbound call — section 10.4 #2
  const dbSpan = startSpan("db.users.insert", { "db.statement": "INSERT INTO users" })
  await db.insert(...)
  dbSpan.end()

  // Business event — section 10.4 #4
  logEvent({ event: "user_signup", severity: "info", attrs: { user_id, method } })
  span.end()
} catch (err) {
  // Caught error — section 10.4 #3
  captureError(err, { event: "user_signup_failed", severity: "error" })
  span.end({ status: "error" })
  throw err
}
```

## Non-requirements

This section explicitly does NOT specify:

- The vendor or hosted service that receives events.
- The exact function names of the wrapper (`logEvent` vs `log` vs `track` are equivalent if semantics match).
- The on-disk location of the wrapper module within the project.
- The framework for outbound-call instrumentation (a fetch interceptor, an HTTP middleware, a Supabase client wrapper — all conformant if `traceparent` propagates correctly).
- The format of the `event` enumeration. Each project defines its own.
- The retention period or storage model at the destination.
- The specific CI provider, pre-commit toolchain, or dashboard implementation. §10.9 defines primitives; hosts choose deployments.

## Conformance

A host implementation claiming conformance with spec version 0.3.0 MUST satisfy every MUST and MUST NOT in this section. SHOULD requirements raise conformance level above the minimum. Failure to satisfy a MUST is non-conformance and SHOULD be tracked as a gap in the host's `reference-implementations/` entry.

A project produced by a conformant host implementation is itself conformant only if its scaffold output satisfies sections 10.1–10.6 and the project declares its observability metadata per section 10.8. A project additionally claiming §10.9 enforcement coverage MUST declare its `enforcement:` sub-block per §10.8 and MUST maintain the baseline file referenced therein.
