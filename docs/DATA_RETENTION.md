# Data Retention — Documents (PR-096)

KTP/loan images live in the vault (MinIO), never in MySQL. Only the object
key + SHA-256 + `kms_key_id` are referenced by the application.

## Gate (every upload)

1. Size ≤ 5 MB, JPEG/PNG/PDF only (`storage.js`).
2. ClamAV INSTREAM scan (`scan.js`): CLEAN stores, INFECTED rejects,
   timeout/unreachable quarantines (never stores on doubt).
3. Randomized object key; SSE-KMS headers when `VAULT_KMS_KEY_ID` is set.

## Retention (`retention.js`)

- Delete after verification + `VAULT_RETENTION_DAYS` (default 30).
- Legal hold always wins; infected objects are eligible immediately.
- Deletions are audited (caller logs key + hash, never bytes).

## Scope note

Object-key persistence (registry table) and the identity upload route land
with the consuming slice; this PR ships the vault, the gate, the policy,
and the drills. MinIO single-node and the dev credentials in
`docker-compose.test.yml` are dev-only — production needs distributed
MinIO, a real KMS, and rotated secrets (provisioning/rotation/sweep
procedure: `docs/runbooks/vault-kms.md`).
