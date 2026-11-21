# ADR 0016: Result protocol (strict parser, fail-closed)

## Status

Accepted (arch9 WP-12).

## Context

`middleware/core-client/result.js` treated every non-`ERROR` line as success:
an empty COBOL output became `200 {data:[""]}` and an unknown line became
`200 {data:[...]}`. A crashed binary (non-zero exit) was also ignored — the
gateway read a stale or partial `output.txt` as success. Row/field assembly
used `:`/`;` splits inline in response mappers with no shape checks, so a
malformed row silently produced a wrong object.

## Decision

The pipe contract is explicit and enforced on both sides:

- Wire format: `SUCCESS|<tag>|<field1>|<field2>|...` or
  `ERROR|<CODE>|<detail1>|...`. `<tag>` and `<CODE>` come from registries.
- A field never contains `|`, `\n`, or `\r`. Row lists use `;` and field
  lists use `:` only for endpoints with a registered row schema, escaped by
  the COBOL side and validated by the gateway side.
- The gateway parser is strict: empty output → `EMPTY_RESPONSE`,
  unknown prefix or embedded newline → `INVALID_RESPONSE`, over-16KB →
  `RESULT_TRUNCATED`, `ERROR|` without a code → `INVALID_RESPONSE`. All map
  to HTTP 500, never 200.
- `fileInvoke` checks the child exit code: non-zero means the binary never
  produced a trustworthy result, so it rejects with `InvocationError`
  instead of reading `output.txt`.
- Response mappers use shared helpers (`splitRows`, `assertFieldCount`);
  no raw `split(':')` in gateway hot paths.

## Consequences

- Every action gains a result schema; contract tests cover empty/unknown/
  truncated/fuzz inputs per action.
- `INVALID_RESPONSE` is registered in `contracts/errors.yaml` (origin
  gateway) with an explicit 500 status — no silent `?? 500` drift.
- Alternatives rejected: full JSON-line rewrite of serve mode (larger blast
  radius for the same guarantee; strict parsing plus escaping closes the
  bug class with minimum churn).
