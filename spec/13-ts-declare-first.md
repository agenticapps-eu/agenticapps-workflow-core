---
id: 13-ts-declare-first
section_type: declarative-contract
spec_version: 0.4.0
---

# 13 — TS Declare-First Skill

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below in their idiom. Prose, formatting, file
paths, and the concrete skill name are at the host's discretion. The
keywords MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are used per
[RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Concept

A *declare-first* discipline for TypeScript projects authors the API
surface as a `declare`-only type-level file before any implementation
or test exists. Tests are written against the declared surface; the
implementation is written last, against the contract the tests
already pin down.

The discipline is a strengthening of test-driven development for
projects where the type system is the project's primary contract
language. In ordinary TDD, the test names the behavior and the
implementation's signature emerges. In declare-first, the signature
is fixed up front and the test exercises the *signature plus
behavior*, which means the implementation has no opportunity to
diverge from the declared surface without breaking the type check.

The skill named in this section is host-specific. Host implementations
targeting TypeScript projects SHOULD provide a skill (commonly named
`ts-declare-first`, but the name is at the host's discretion) that
satisfies the requirements below. Host repos own the skill files; this
section owns the contract.

This section piggy-backs on §06 (Evidence Rules) for the verification
shape of "tests fail with the expected message before implementation
lands." It introduces no new evidence shapes.

## Trigger

- **MUST** be triggered explicitly by the operator (the agent or the
  human running the workflow) when a TypeScript module's API surface
  is being authored.
- **MUST** be triggered implicitly by the host's GSD design phase when
  the phase plan introduces a new TypeScript module AND the project's
  `package.json` declares TypeScript as the primary language (e.g.
  `"types"` field present, `"main"` resolves to a `.ts` or compiled
  output, or `typescript` in `dependencies` / `devDependencies` with
  the host's project-type heuristic identifying it as TS-primary).
- **MAY** be triggered for modules in projects that are not
  TypeScript-primary (e.g. a TS subdirectory of a polyglot repo). The
  trigger is host-tunable; the obligation that the trigger exists is
  not.

## Phase 1 — Declaration surface

- **MUST** produce a `declare`-only type-surface file as Phase 1
  output. The file's content is exactly:
  - `declare class`, `declare function`, `declare const`,
    `declare let`, `declare var` statements; and/or
  - `interface` and `type` definitions; and/or
  - `export` re-exports of the above.
- **MUST NOT** contain any implementation body. Function bodies,
  class method bodies, expression initialisers for `declare const`,
  and any other executable code are non-conformant in this file.
- **MUST** be type-check-clean: running `tsc` (or `tsc --noEmit` per
  the optional gate below, or the host's idiomatic equivalent) against
  the declaration file alone produces zero diagnostics.
- **SHOULD** colocate the declaration file with the eventual
  implementation under a convention recognisable to the host (e.g.
  `foo.declare.ts` alongside `foo.ts`, or `foo/index.declare.ts`
  alongside `foo/index.ts`). The convention is host-defined; the
  separation is not.
- **MAY** include `@throws` / `@deprecated` / parameter-constraint
  JSDoc on declared symbols. These do not count as implementation.

## Phase 2 — Tests against the declared surface

- **MUST** produce test files that import and exercise the declared
  surface as Phase 2 output, after the declaration file exists and
  type-checks clean.
- **MUST** include at least one test per declared symbol. A symbol
  that is type-only (`type`, `interface`) MAY be exercised indirectly
  via a value-level symbol that consumes it.
- **MUST** cover happy-path, error-path, and edge-case behavior per
  the host's existing test rules (the spec is silent on the concrete
  test framework; `vitest`, `node:test`, `deno test`, `bun test`, and
  `jest` all qualify).
- **MUST** be observable as failing in the expected way at the moment
  of authoring — the type check succeeds (the symbols exist as
  declarations), but the test runner reports the expected failure
  (the implementations do not yet exist). This is the contract test
  the implementation will be measured against.
- **SHOULD** record the expected-failure output as evidence per §06
  before any implementation is written.

## Phase 3 — Implementation

- **MUST NOT** allow implementation code to be authored until both the
  declaration file and the test file exist, the declaration file
  type-checks clean, and the test file fails in the expected way.
- **MUST** be authored such that its exported signatures match the
  declared signatures exactly. The implementation file replaces the
  declarations — it is not allowed to widen, narrow, or rename a
  signature relative to the declaration without an ADR explaining the
  deviation.
- **SHOULD** preserve the declaration file as the surface contract
  once implementation lands. Options for preservation:
  1. Keep the `.declare.ts` file as the public type surface and
     re-export from it; the implementation file is non-public.
  2. Delete the `.declare.ts` file once the implementation's
     `.d.ts` (emitted by `tsc`) supersedes it, recording the
     transition in the commit message that lands the implementation.
  The host MAY pick either option per module; mixed strategies within
  a repo are permitted.

## Verification gates

- **MUST** integrate with the host's existing `verification` gate (see
  §02). The evidence rows for a declare-first module's `must_have`
  include:
  1. The Phase-1 commit hash whose diff is the declaration file.
  2. The Phase-2 commit hash whose diff is the test file, plus the
     test-runner output line(s) demonstrating expected failure.
  3. The Phase-3 commit hash whose diff is the implementation file,
     plus the test-runner output line(s) demonstrating the tests now
     pass.
- **MUST NOT** allow a single commit to land both Phase 1 and Phase 3
  (declarations and implementation in one commit). The atomic-commit
  sequence is the structural evidence that the discipline was
  followed; collapsing it erases the evidence.

## Optional gates

- **MAY** support `tsc --noEmit` (or the host's equivalent
  type-check-only gate) as the Phase-1 validity check, in lieu of full
  compilation. When the host has a faster check available (e.g.
  `tsserver` in-editor diagnostics, `@biomejs/biome check`, a
  language-server query), it MAY use that instead, provided the check
  produces the same diagnostics `tsc` would for the declaration file.

## Illustrative example (non-normative)

The following three-file shape illustrates the discipline for a small
bounded-queue module. It is illustrative; the host's actual file
layout, test framework, and naming may differ.

### `bounded-queue.declare.ts` (Phase 1)

```ts
/**
 * A FIFO queue with a fixed maximum capacity. Enqueue is rejected
 * when the queue is full; dequeue returns undefined when empty.
 */
export declare class BoundedQueue<T> {
  constructor(capacity: number);
  readonly capacity: number;
  readonly size: number;
  /** Returns true if the item was added; false if the queue is full. */
  enqueue(item: T): boolean;
  /** Returns the front item, or undefined if empty. */
  dequeue(): T | undefined;
}
```

### `bounded-queue.test.ts` (Phase 2)

```ts
import { describe, it, expect } from 'vitest';
import { BoundedQueue } from './bounded-queue';

describe('BoundedQueue', () => {
  it('reports capacity from the constructor', () => {
    const q = new BoundedQueue<number>(3);
    expect(q.capacity).toBe(3);
    expect(q.size).toBe(0);
  });

  it('preserves FIFO order on enqueue/dequeue', () => {
    const q = new BoundedQueue<string>(3);
    q.enqueue('a'); q.enqueue('b'); q.enqueue('c');
    expect(q.dequeue()).toBe('a');
    expect(q.dequeue()).toBe('b');
    expect(q.dequeue()).toBe('c');
  });

  it('rejects enqueue at capacity', () => {
    const q = new BoundedQueue<number>(2);
    expect(q.enqueue(1)).toBe(true);
    expect(q.enqueue(2)).toBe(true);
    expect(q.enqueue(3)).toBe(false);
    expect(q.size).toBe(2);
  });

  it('returns undefined when dequeueing empty', () => {
    const q = new BoundedQueue<number>(2);
    expect(q.dequeue()).toBeUndefined();
  });
});
```

At Phase 2, the import resolves to `bounded-queue.declare.ts` via the
host's resolution convention (path alias, declaration-file
re-export, or compiler trick). The type check succeeds; the test
runner reports four failures — there is no constructor body, no
methods, no values. This expected-failure output is the §06 evidence
that the contract is in place before any implementation lands.

### `bounded-queue.ts` (Phase 3)

```ts
export class BoundedQueue<T> {
  readonly capacity: number;
  private items: T[] = [];

  constructor(capacity: number) {
    this.capacity = capacity;
  }

  get size(): number {
    return this.items.length;
  }

  enqueue(item: T): boolean {
    if (this.items.length >= this.capacity) return false;
    this.items.push(item);
    return true;
  }

  dequeue(): T | undefined {
    return this.items.shift();
  }
}
```

The implementation's exported signatures match the declaration
exactly. The Phase-2 tests now pass. The §06 evidence rows for the
phase's `must_have` reference the three commit hashes and the
test-runner output transitions.

## Conformance

A host implementation claiming conformance with spec version 0.4.0
that targets TypeScript projects:

- **SHOULD** ship a `ts-declare-first` skill (or host-named
  equivalent) that satisfies the trigger, Phase 1, Phase 2, Phase 3,
  and verification-gate requirements above.
- **SHOULD** document the skill name and its binding in the host's
  hook-bindings table or workflow-config (see §02 conformance).
- **MAY** decline to ship the skill when the host's primary target is
  not a TypeScript runtime. A host targeting only non-TS environments
  is not non-conformant for this section's omission, but SHOULD record
  the omission as a spec delta per §09.

A host that ships a TypeScript-targeted scaffolder without this skill
at 0.4.0 adoption is non-conformant against this section's SHOULD,
but is not non-conformant against the overall spec — SHOULD-level
requirements move the host above the minimum bar but do not break
conformance.

## References

- §02 Hook Taxonomy — the `tdd` gate that the declare-first
  discipline strengthens for TypeScript modules.
- §06 Evidence Rules — the verification-before-completion contract
  this section piggy-backs on.
- TypeScript handbook, *Ambient declarations* — the language-level
  semantics of `declare`.
