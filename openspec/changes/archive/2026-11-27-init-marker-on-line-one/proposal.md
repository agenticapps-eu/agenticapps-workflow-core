# Update a section that starts the file without an error

Linear issue: none (GitHub issue agenticapps-eu/agenticapps-workflow-core#121).

When the begin marker is the first line of an instruction file, the update path
in `init-project.sh` runs `head -n 0`. BSD `head`, which is what macOS ships,
rejects a count of 0: it prints `head: illegal line count -- 0` and exits 1. It
writes nothing to stdout, so the file comes out right, but only by accident, and
every update run in such a repository prints the error. claude-mods hit it on
2026-11-27, because its instruction pair is the managed section and nothing else.

Core never sees it because its own marker is not on line 1. Nor does the test
suite: every fixture puts operator content above the marker, and
`digest_outside_markers` in `tools/init-project.test.sh` (line 139) has the same
`head -n "$((b - 1))"` pattern.

## What changes

- `init-project.sh` copies the bytes before the begin marker only when there
  are some. `init-project-version` 2.3.0 → 2.3.1. The rendered section does not
  change, so `section-version` stays 1.2.0.
- The test helper gets the same guard.
- A new fixture: a file whose first line is the begin marker. A re-run must exit
  zero, print no `head:` diagnostic, and leave the bytes outside the markers as
  they were.

## Not in scope

Any other BSD/GNU difference in the initializer. None is known; this change does
not go looking.
