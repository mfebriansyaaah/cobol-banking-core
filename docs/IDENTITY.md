# Identity Verification (PR-083/084)

Structural validation only — never Dukcapil verification. For a paid
official provider, add a future adapter; do not activate by default.

## Local NIK validation (`local`)

Fully offline. Checks, in order:

1. 16 digits, numeric.
2. Province code exists (`identity/data/wilayah.json`, vendored 2022
   snapshot of `wilayah@1.3.0` MIT: 34 provinces, 514 regencies).
3. Regency code exists.
4. Birth date valid: DD 01–31 (female +40), real calendar date
   (29 Feb only on leap years).
5. Age ≥ 17 at the reference date (KYC minimum).
6. Serial segment not `0000`.

Response: `{ valid, level: 'STRUCTURAL', region, gender, age, reason? }`.
District-level data is not vendored (dataset would be ~3 MB); the
district segment is format-checked only. Caveat documented, not hidden.

## Optional remote (`nusakit`)

Env-gated (`NUSAKIT_ENDPOINT` + `NUSAKIT_ALLOWLIST`), explicit
`consent: true` per call, 3 s timeout, falls back to local on any
failure. Only sends the NIK to an allowlisted host.

## Storage

Raw NIKs are never persisted: `nikHandle(nik, secret)` stores
HMAC-SHA256 + last4 only.

## Gateway trust boundary

`POST /identity/nik/validate` accepts the raw NIK only. The gateway
(`middleware/src/derivations.js`) validates structure, derives the verdict
and the HMAC handle with `NIK_HMAC_SECRET`, and overwrites any
client-sent `nikHash`/`verdict` before COBOL runs. A missing secret fails
the request instead of storing unhashed identity.

## OCR (PR-084: deferred, fail-fast)

Local KTP OCR needs a native Tesseract not present in CI/dev images;
`tesseract.js` would pull WASM models at runtime (no offline story).
Configuring `KTP_OCR_PROVIDER=local` fails fast at boot instead of at the
first request; only `mock` boots. Manual review remains mandatory
(`OCR_REVIEW_THRESHOLD`); revisit when infra provides Tesseract. No fixture
images committed (no PII in repo, real or synthetic).
