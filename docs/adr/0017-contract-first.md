# ADR 0017: Contract-first API (single spec, generated artifacts)

## Status

Accepted (arch9 WP-13).

## Context

`middleware/spec/routes.yaml` documents direct input fields, but four routes
silently depend on server-derived fields that never appear in the spec or in
`docs/openapi.yaml`: `/identity/nik/validate` needs `nik`,
`/identity/ktp/ocr` needs `imageRef`, `/screening/check` needs `name`,
`dob`, `consent`, and `/auth/phone/link/begin` needs `phone`. Clients
following OpenAPI get 400s, reviewers cannot see sensitive inputs in
contract review, and response shapes vary per endpoint (`{data:[...]}` vs
`{data:["ROW1;ROW2"]}`).

## Decision

`middleware/spec/routes.yaml` is the single source of truth and carries, per
route: direct fields, `derivedFields` (adapter-computed inputs with patterns
and required flags), response schema, auth/step-up/permission, and the
possible error codes. Generators produce from it: route files,
`contracts/actions.yaml`, `docs/openapi.yaml`, TypeScript types/SDK, and
per-route contract tests. Derived fields are real request inputs (validated
by the same whitelist) but never enter the 6-slot COBOL pipe.

Response envelope standardizes on `{ data, meta, error }` with pagination
(`limit`/`offset`/`total`) for list endpoints; `/v1` prefixes the versioned
surface while legacy paths keep working with `Deprecation`/`Sunset`.

## Consequences

- `node scripts/check_contract.mjs` fails on undocumented derived fields;
  every route has at least one contract test; OpenAPI/SDK regenerate
  byte-identically or CI fails.
- Adding a route means editing the spec and regenerating — never hand-editing
  generated files (enforced by existing manifest/doc gates plus the new
  derivation-field checker).
- Alternatives rejected: code-first with extracted types (drifts within
  weeks on a solo-maintained repo; spec-first keeps review in one place).
