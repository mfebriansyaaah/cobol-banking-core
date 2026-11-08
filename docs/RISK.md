# Device/Geo Risk Signals (PR-092)

Login/new-device notations for step-up decisions. Signals only — nothing
here blocks, approves, or scores a user.

## Flow

- `POST /risk/note` takes the account email only. Middleware resolves the
  client IP from the request socket (`middleware/adapters/signals.js` →
  `geoip.js`, ipapi-compatible; private IPs short-circuit to `UNKNOWN`
  without network), hashes it (SHA-256), and computes flags
  (`COUNTRY_MISMATCH` vs last known, `GEO_UNKNOWN`).
  Client-sent country/hash values are overwritten before COBOL runs.
- `RISK_NOTE` stores country/city/ASN + `ip_hash` + flags. `RISK_STATUS`
  serves the latest notation for step-up logic (wired by the auth slice).
- Raw IPs never reach COBOL, the DB (no raw column exists), or logs
  (`geoip.test.js` scans captured lines for IPv4 runs).

## Failure posture

- Fail-open to `UNKNOWN`: missing endpoint, timeout, malformed body, down —
  a missing signal degrades step-up precision, it never locks a user out.
- MaxMind GeoLite2 (local DB, needs account) is a drop-in for the HTTP
  lookup; the interface (`resolve(ip) -> {country, city, asn}`) is unchanged.
