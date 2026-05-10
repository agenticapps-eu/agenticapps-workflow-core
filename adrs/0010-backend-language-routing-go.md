# ADR-0010: Backend language routing for Go

**Status:** Accepted
**Date:** 2026-05-03
**Linear:** —

## Context

Many AgenticApps backends are written in Go, but the workflow scaffolder previously
treated all phases as language-agnostic. Stage 2 review (the code-review gate; see
spec section 02) ran the same checklist regardless of language, missing Go-specific
issues that language-aware linters and patterns catch:

- Idiomatic error wrapping
- Context propagation correctness
- Slice/map allocation pitfalls
- Resilience patterns for long-running services (retry, graceful shutdown, observability)
- DI framework idioms (wire/dig/fx)

Two community skill packs cover this gap:

- **`samber/cc-skills-golang`** — 40+ skills covering style, naming, errors, testing,
  security, observability, performance, concurrency, context, DI, CLI, config, gRPC,
  GraphQL, swagger. Each skill ships measured eval data (e.g. `golang-modernize` -61%
  error rate, `golang-samber-do` -81%).
- **`netresearch/go-development-skill`** — Production resilience: package structure,
  go-cron with FakeClock testing, retry/backoff/graceful shutdown, Docker client
  patterns, golangci-lint v2, fuzz/mutation testing, Prometheus observability.

They compose — samber covers breadth + idioms, netresearch covers production resilience.

## Decision

1. Add a **Backend language routing** section to the host's workflow-config artifact
   declaring which skill packs auto-trigger on which file extensions.
2. Add **language-specific code-quality gates** as an extension of post-phase Stage 2
   in the host's enforcement-plan document.
3. Document install commands in the host's README under **Per-language skill packs**.
4. Both Go skill packs are installed **per-project**, not globally.

The routing is declarative — it tells the agent which skills to invoke when a Go phase
is detected. The skills themselves self-scope by file content.

## Alternatives Rejected

- **Global install of both Go packs.** Rejected — non-Go repos would pay the context
  cost (skill descriptions still load even when not triggered), inflating context for
  TS-only or Python-only projects.
- **One bundled "polyglot" skill.** Rejected — bundling forces every project to absorb
  every language's rules. Per-language skills compose cleanly and let each language
  evolve independently.
- **Skip language routing entirely; rely on universal Stage 2 reviewer to know Go.**
  Rejected — generic reviewers miss language-specific anti-patterns. The samber eval
  data shows measurable error-rate reductions; ignoring those gains is leaving
  quality on the table.
- **Wait until netresearch publishes a stable release.** Rejected — the package is
  already in production use elsewhere; waiting indefinitely defers value. We adopt
  now and re-evaluate if the maintainer disappears.

## Consequences

**Positive:**
- Go phases get language-aware Stage 2 review, catching idiom violations and resilience
  bugs that generic review misses.
- Per-project installs keep context cost off non-Go repos.
- Routing is declarative + extensible — adding Python or Rust packs follows the same
  pattern (one row in the workflow-config artifact, one row in the enforcement plan).

**Negative:**
- Per-project install requires one extra `git clone` per Go repo — not amortizable.
  Tracked: a future migration could ship a one-liner installer.
- Bus factor on `samber/cc-skills-golang` and `netresearch/go-development-skill` is
  solo-maintainer. Mitigation: both are MIT-licensed; we can fork if abandoned.

**Follow-ups:**
- The migration framework introduced in ADR-0013 absorbs future Go skill pack
  additions.
- Python skill pack TBD; cross-referenced from the workflow-config artifact to the
  host README's Per-language skill packs section.

## References

- `samber/cc-skills-golang`: https://github.com/samber/cc-skills-golang
- `netresearch/go-development-skill`: install via the upstream pack's README. The
  upstream package name and subcommand have not been independently verified across
  hosts; verify against the upstream README before adoption.

---

*This ADR documents a host-agnostic decision. For host-specific bindings (concrete
paths, skill names, plugin invocations), see each host repo's documentation.*
