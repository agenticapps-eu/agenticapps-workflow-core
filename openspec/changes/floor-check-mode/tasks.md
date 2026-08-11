# Tasks — the floor can be inspected

Carried out of `one-enforcement-floor`, which archived on 2026-08-11 with the
floor shipped and `--check` specified-but-unbuilt. Nothing here is new work
invented after the fact; it is the work that change did not do, given an honest
size.

**Sized to the diff.** One mode on one script, its tests, and one deletion. If
this list grows past what `--check` prints, something has been smuggled in.

## 1. Drop `--project` first, because it is subtraction

- [ ] 1.1 Remove `--project` from the deferred-scope notes that name it.
      Nothing implements it and nothing calls it; a documented flag that does
      not exist advertises a capability the tool cannot provide, which is the
      same defect `GSD_SKIP_REVIEWS` was removed for.
- [ ] 1.2 If per-project binding is meant to be durable behaviour rather than
      an unbuilt idea, say so in one requirement. Otherwise say nothing — a
      deferred-scope note is not a specification.

## 2. `--check`, tests first

- [ ] 2.1 RED: `bind-global-floor.sh --check` currently parses `--check` as a
      repository argument and refuses. Record that output; it is the baseline.
- [ ] 2.2 RED for each reported condition, one assertion apiece:
      `core.hooksPath` unset; set and resolving to the published directory; set
      and dangling; set to a foreign directory; the published dispatcher stale
      by content; the dispatcher not executable.
- [ ] 2.3 RED: a repository carrying `openspec/` and no enrolment key is
      reported as ungated. This is the row the whole mode is for — the
      2026-08-08 measurement found five such repositories and nothing said so.
- [ ] 2.4 RED: a repository whose own hooks are displaced by the global binding
      is reported rather than silent.
- [ ] 2.5 RED: core's local binding, declared, is reported as declared and not
      as redundant; undeclared, it is reported as at risk of being swept.
- [ ] 2.6 Implement. GREEN, twice.

## 3. It reports and repairs nothing

- [ ] 3.1 Assert `--check` writes no file, sets no git config and exits 0
      whatever it finds. A mode that can change state is one an operator has to
      think before running, and the value here is that asking is free.
- [ ] 3.2 Assert the exit code does not encode the findings. A caller that
      branches on it turns a report into a gate, which is a different decision.

## 4. Close

- [ ] 4.1 `openspec validate --all` green.
- [ ] 4.2 Re-measure with the mode itself: how many repositories the floor
      reaches, how many carry `openspec/` without enrolment. Record the numbers
      — that pair is the reason this exists.
- [ ] 4.3 Bump `global-floor-version` and publish; the installer arbitrates on it.
