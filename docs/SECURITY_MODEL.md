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

## Adversarial pass (gap-closure #5, in-repo)

An external pen-test is still required (see `docs/PRODUCTION_READINESS.md`);
what the repo itself proves, locked in `middleware/test/security.test.js`:

- Algorithm confusion complete: `none` rejected alongside non-HS256 algs.
- Pipe/control characters in free-text fields rejected pre-COBOL.
- Mass assignment dead: `buildParams` allowlists spec fields only, and
  `role`/`status` extras on signup still yield a plain UNVERIFIED USER.
- Error-path logs carry no passwords (and no raw URLs with PII).
- Pre-existing: injection chars, body-actor spoofing, token
  issuer/audience/purpose pinning, rotation overlap, secure-config
  fail-fast, metrics authz.

Residuals for the external test: business-logic abuse (velocity/amount
games within valid limits), session theft outside the gateway (XSS lives
in clients, not this API), and infra-layer vectors (TLS, headers at the
edge proxy, DB host hardening).
