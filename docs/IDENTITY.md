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

## OCR (PR-084: deferred)

Local KTP OCR needs a native Tesseract not present in CI/dev images;
`tesseract.js` would pull WASM models at runtime (no offline story).
Deferred with rationale: the `mock` OCR provider stands, manual review
remains mandatory (`OCR_REVIEW_THRESHOLD`), revisit when infra provides
Tesseract. No fixture images committed (no PII in repo, real or synthetic).
