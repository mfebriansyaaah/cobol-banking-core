# Security Model (PR-071)

## Ownership

Every route resolves to an accountable area via `scripts/lib/route_owners.mjs`
(first path segment → area). `check_route_auth` fails routes without an
owner. Areas mirror `docs/DATA_MODEL.md`: `auth`, `identity`, `money`,
`ledger`, `lending`, `market`, `risk`, `corporate`, `data`, `comms`, `ops`,
`governance`, `growth`.

## Auth matrix

| Kind          | Rule                                                           | Examples                                    |
| ------------- | -------------------------------------------------------------- | ------------------------------------------- |
| Public entry  | `public: true` + auth limiter + captcha/breach gates where set | signup, login, forgot, verify               |
| Authenticated | token + active session                                         | everything else by default                  |
| Admin         | role check in COBOL                                            | `/admin/*` (dormancy, roles, audit)         |
| Admin step-up | fresh re-auth proof required                                   | reviews decide, reversals, recovery approve |

Mutating methods without `tokenIdentity` fail the gate unless listed in
`tests/known_public_routes.txt` (ratchet both directions).

## Threat model (STRIDE, ringkas)

- **Spoofing:** bearer theft → short TTL + token version + revocation list;
  step-up for privileged writes.
- **Tampering:** pipe framing validated (patterns, line length); COBOL binds
  parameters (no concatenation).
- **Repudiation:** audit trail + reviewer attribution on decisions.
- **Info disclosure:** PII redaction (`redact.js`), hashes at rest, metrics
  without labels carrying identity.
- **DoS:** per-route limiters, pool bounds, quota kill switches, outbox caps.
- **Elevation:** role checks live in COBOL (not the gateway); permission map
  in `role_permissions`.
