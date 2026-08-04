---
id: 0005
slug: belowthreshold-skip
title: Below every host threshold and never opts in
from_version: 1.3.0
to_version: 1.4.0
applies_to:
  - fixture.txt
---

# Migration 0005 — pre-format history, skipped entirely

## Steps

### Step 1: Illustration only, no rollback — would fail every rule if judged

```bash
# illustration only — never tagged, never executed
echo "DO NOT RUN ME" > tripwire.txt
```
