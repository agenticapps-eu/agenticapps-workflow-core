---
id: 05-pressure-test
section_type: canonical-prose
spec_version: 0.1.0
---

# 05 — Pressure-Test Scenarios

**Section type**: canonical prose. Host implementations MUST reproduce
the block below verbatim. The pressure test is the final check before
the agent skips any step: three questions calibrated to surface
rationalization that the table in section 03 might not have caught.

Adding scenarios is permitted; reordering, removing, or rewording the
three canonical questions is non-conformant.

## Canonical block

```
## Pressure-Test Scenarios — Self-Check

Before you skip any step, ask yourself:
- Would I skip this step if this code were running in production serving real users?
- Would a senior engineer reviewing this work accept the shortcut?
- Am I rationalizing? Check the rationalization table above.

If any answer gives you pause, follow the protocol.
```
