---
id: 0039
slug: zero-steps
title: An in-scope migration that declares no steps at all
from_version: 1.9.0
to_version: 1.10.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0039 — zero steps

A document with no `### Step ` heading at all trivially satisfies every
per-step rule the linter has (L1/L2/L3/L4/L5/L6 all iterate over the step
list, and an empty list means zero iterations, zero violations). Lint alone
therefore reports this as clean. A runner that lints first and then executes
whatever the extractor hands it would run zero steps, print nothing wrong,
and exit 0 — success, having done nothing. The runner's own "zero steps"
refusal is the only thing that catches this one; the linter cannot.

## Steps

There are no steps below this heading — this section intentionally has none.
