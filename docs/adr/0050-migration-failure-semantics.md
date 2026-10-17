# Loud, attributed migration failures

Status: accepted
Date: 2026-10-17
Phase: Database schema & migrations audit (FASE B).

## Context

`migrate.sh` piped every migration's stderr to `/dev/null` and relied on
`set -e`: a broken migration aborted the whole run with no output naming the
file, leaving operators to bisect 29 files by hand. (No false success was
possible — the abort happens before the version is recorded — but diagnosis
was blind.)

## Decision

- Capture each migration's output; on a non-zero exit, print
  `migration FAILED: <version>` plus the database error and exit 1 without
  recording. A retry therefore resumes at the same file instead of skipping
  silently.
- Cover with two suite checks that inject a syntactically invalid migration
  (sorted last, removed afterwards by trap): the run aborts non-zero naming
  the file, and no `schema_migrations` row is written for it.

## Consequences

- Migration failures are attributable on sight; the runner stays fail-stop
  with resume-here semantics.
- Shell 617 -> 619, gateway 104 unchanged; full run 723 assertions.
