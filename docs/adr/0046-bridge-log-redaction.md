# Bridge diagnostic log redaction

Status: accepted
Date: 2026-10-16
Phase: Core bridge & C-libraries audit (FASE B).

## Context

The two non-prepared execution paths log through `G_QUERY`, which holds
concatenated SQL literals — including escaped emails — so every login-class
call printed personally identifying data to the server logs (in file mode the
child inherits the gateway's stderr). The prepared paths were already safe
(they log nothing; only `?` templates reach the server).

## Decision

- Both stderr diagnostics now print the query length only
  (`[SQL_BRIDGE] Executing query (N bytes)`), never the text. The marker is
  kept so log-based "did it run" reasoning still works; nothing consumed the
  text (verified: no test, doc or script references it), and pool-mode
  workers ignore stderr anyway.
- Covered by two injection-suite checks: the marker is still emitted and no
  email address appears in the diagnostics.

## Consequences

- Server logs no longer carry query-embedded PII from the bridge.
- Shell 607 -> 609, gateway 104 unchanged; full run 713 assertions.
